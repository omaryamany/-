import 'dart:async';

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/hijri.dart';
import '../../core/khatma.dart';
import '../../core/prayer.dart';
import '../../core/prayer_calc.dart';
import '../../core/reminders.dart';
import '../../core/seasonal.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../khatma/khatma_screen.dart';
import '../mushaf/share_ayah.dart';

void openRamadan(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RamadanScreen()));

/// معلومات رمضان الحالي أو الجاي
class RamadanInfo {
  final int year;
  final DateTime first; // أول يوم صيام
  final int length;
  const RamadanInfo(this.year, this.first, this.length);

  DateTime get last => first.add(Duration(days: length - 1));

  static RamadanInfo get current {
    final h = Hijri.today;
    final y = h.month <= 9 ? h.year : h.year + 1;
    final first = Hijri.toGregorian(y, 9, 1);
    return RamadanInfo(y, first, Hijri.monthLength(y, 9));
  }

  /// رقم اليوم من رمضان (١..) أو null لو مش رمضان
  int? dayOf(DateTime d) {
    final k = daysBetween(first, dateOnly(d)) + 1;
    return k >= 1 && k <= length ? k : null;
  }

  int get daysLeft => daysBetween(dateOnly(DateTime.now()), first);
}

/// كارت رمضان في الرئيسية: بيظهر في رمضان، وفي آخر ٣٠ يوم قبله
class RamadanCard extends StatefulWidget {
  const RamadanCard({super.key});
  @override
  State<RamadanCard> createState() => _RamadanCardState();
}

class _RamadanCardState extends State<RamadanCard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = RamadanInfo.current;
    final now = DateTime.now();
    final day = r.dayOf(now);
    if (day == null && (r.daysLeft > 30 || r.daysLeft < 0)) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    String title, line;
    if (day == null) {
      title = 'رمضان بعد ${daysLabel(r.daysLeft)}';
      line = 'أول أيام الصيام ${longDate(r.first)} تقريبًا — جهّز ختمتك';
    } else {
      title = 'رمضان كريم · اليوم ${arDigits(day)}';
      line = _countdown(now) ?? 'تقبّل الله صيامكم';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: HeroCard(
        onTap: () => openRamadan(context),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
            child: const Icon(Icons.nightlight_round, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(line, style: t.bodyMedium?.copyWith(color: AppColors.goldLight)),
            ]),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white70),
        ]),
      ),
    );
  }
}

/// «الإفطار بعد …» أو «الإمساك بعد …»
String? _countdown(DateTime now) {
  final ps = PrayerStore.instance;
  if (!ps.configured) return null;
  final today = ps.day(now);
  final maghrib = today[Prayer.maghrib];
  final imsakMin = Reminders.instance.imsakMinutes;
  final fajrToday = today[Prayer.fajr];
  String left(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h == 0) return minutesLabel(m == 0 ? 1 : m);
    return '${arDigits(h)} س و${arDigits(m)} د';
  }

  if (now.isBefore(fajrToday)) {
    final imsak = fajrToday.subtract(Duration(minutes: imsakMin));
    return now.isBefore(imsak) ? 'الإمساك بعد ${left(imsak.difference(now))}' : 'الفجر بعد ${left(fajrToday.difference(now))}';
  }
  if (now.isBefore(maghrib)) return 'الإفطار بعد ${left(maghrib.difference(now))} (${timeLabel(maghrib.hour, maghrib.minute)})';
  final fajr = ps.day(now.add(const Duration(days: 1)))[Prayer.fajr];
  final imsak = fajr.subtract(Duration(minutes: imsakMin));
  return 'الإمساك بعد ${left(imsak.difference(now))} (${timeLabel(imsak.hour, imsak.minute)})';
}

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});
  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  final _r = Reminders.instance;

  Future<void> _set({int? suhoor, bool? taraweeh, int? imsak}) async {
    final ok = await _r.setSeasonal(suhoor: suhoor, taraweeh: taraweeh, imsak: imsak);
    if (!ok && mounted) toast(context, 'اسمح بالإشعارات من إعدادات الموبايل');
    await Seasonal.reschedule();
    if (mounted) setState(() {});
  }

  Future<void> _khatma(int times) async {
    final info = RamadanInfo.current;
    final left = daysBetween(dateOnly(DateTime.now()), info.last) + 1;
    final k = KhatmaStore.instance;
    if (k.active && !k.finished) {
      final yes = await confirm(context, 'عندك ختمة شغالة', body: 'تبدأ ختمة رمضان مكانها؟ التقدّم الحالي هيتمسح.', ok: 'ابدأ');
      if (!yes) return;
    }
    await k.start(days: (left / times).floor().clamp(1, 30));
    if (!mounted) return;
    toast(context, 'بدأت ختمة رمضان: ${pagesLabel((k.plan!.perDay).ceil())} يوميًا');
    openKhatma(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final info = RamadanInfo.current;
    final now = DateTime.now();
    final day = info.dayOf(now);
    final ps = PrayerStore.instance;
    final imsakMin = _r.imsakMinutes;
    return Scaffold(
      appBar: AppBar(title: Text('رمضان ${arDigits(info.year)} هـ')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        HeroCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(day != null ? 'اليوم ${arDigits(day)} من رمضان' : 'رمضان بعد ${daysLabel(info.daysLeft)}',
                style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              day != null ? (_countdown(now) ?? 'حدّد مكانك من تبويب الصلاة عشان نحسب الإفطار والسحور') : 'من ${longDate(info.first)} إلى ${longDate(info.last)} تقريبًا',
              style: t.bodyLarge?.copyWith(color: AppColors.goldLight),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // ختمة رمضان
        SoftCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('ختمة رمضان', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(day != null ? 'نوزّع المصحف على الأيام الباقية من رمضان، مع تذكير يومي بالورد.' : 'زرار الختمة بيشتغل من أول يوم في رمضان.',
                style: t.bodySmall),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: day == null ? null : () => _khatma(1), icon: const Icon(Icons.menu_book_rounded), label: const Text('ختمة واحدة'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: day == null ? null : () => _khatma(2), child: const Text('ختمتين'))),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        // دعاء الإفطار
        SoftCard(
          onTap: () => openShareCard(
            context,
            const ShareContent(
              header: 'دعاء الإفطار',
              text: 'ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
              source: 'رواه أبو داود',
              caption: 'دعاء الإفطار: ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('دعاء الإفطار', style: t.titleSmall?.copyWith(color: AppColors.turquoise, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
                textAlign: TextAlign.center, style: AppTheme.quran(size: 21, height: 1.9, color: cs.onSurface)),
            Text('رواه أبو داود · اضغط للمشاركة كصورة', style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(height: 14),
        const SectionTitle('التذكيرات'),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.free_breakfast_rounded, color: AppColors.turquoise),
              title: const Text('تذكير السحور'),
              subtitle: Text(_r.suhoorBefore == 0 ? 'متوقف' : 'قبل الفجر بـ ${minutesLabel(_r.suhoorBefore)}'),
              trailing: DropdownButton<int>(
                value: _r.suhoorBefore,
                underline: const SizedBox.shrink(),
                items: [for (final m in [0, 30, 45, 60, 90]) DropdownMenuItem(value: m, child: Text(m == 0 ? 'متوقف' : minutesLabel(m)))],
                onChanged: (v) => _set(suhoor: v),
              ),
            ),
            SwitchListTile(
              value: _r.taraweehOn,
              onChanged: (v) => _set(taraweeh: v),
              secondary: const Icon(Icons.mosque_rounded, color: AppColors.turquoise),
              title: const Text('تذكير صلاة التراويح'),
              subtitle: const Text('بعد العشاء بربع ساعة، كل ليالي رمضان'),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined, color: AppColors.turquoise),
              title: const Text('الإمساك قبل الفجر'),
              subtitle: const Text('احتياط فقط — الأكل والشرب جائز حتى أذان الفجر'),
              trailing: DropdownButton<int>(
                value: imsakMin,
                underline: const SizedBox.shrink(),
                items: [for (final m in [0, 5, 10, 15, 20]) DropdownMenuItem(value: m, child: Text(m == 0 ? 'مع الفجر' : minutesLabel(m)))],
                onChanged: (v) => _set(imsak: v),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SectionTitle('إمساكية رمضان${ps.configured ? ' — ${ps.place}' : ''}'),
        const SizedBox(height: 6),
        if (!ps.configured)
          Text('حدّد مكانك من تبويب الصلاة عشان تظهر الإمساكية.', style: t.bodyMedium)
        else
          _Imsakiya(info: info, imsakMin: imsakMin),
      ]),
    );
  }
}

class _Imsakiya extends StatelessWidget {
  final RamadanInfo info;
  final int imsakMin;
  const _Imsakiya({required this.info, required this.imsakMin});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ps = PrayerStore.instance;
    final today = dateOnly(DateTime.now());
    String tm(DateTime d) => timeLabel(d.hour, d.minute).replaceAll(' ص', '').replaceAll(' م', '');
    final head = t.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant);
    final cell = t.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    Widget row(List<String> v, {TextStyle? style, Color? bg}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            SizedBox(width: 30, child: Text(v[0], textAlign: TextAlign.center, style: style)),
            Expanded(flex: 3, child: Text(v[1], textAlign: TextAlign.center, style: style)),
            for (final x in v.skip(2)) Expanded(flex: 2, child: Text(x, textAlign: TextAlign.center, style: style)),
          ]),
        );
    return SoftCard(
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        row(['', 'اليوم', 'الإمساك', 'الفجر', 'المغرب', 'العشاء'], style: head),
        for (var i = 0; i < info.length; i++)
          Builder(builder: (context) {
            final d = info.first.add(Duration(days: i));
            final p = ps.day(d);
            final fajr = p[Prayer.fajr];
            return row(
              [arDigits(i + 1), shortDate(d), tm(fajr.subtract(Duration(minutes: imsakMin))), tm(fajr), tm(p[Prayer.maghrib]), tm(p[Prayer.isha])],
              style: cell,
              bg: d == today ? AppColors.turquoise.withValues(alpha: .16) : (i.isEven ? cs.surfaceContainerHighest.withValues(alpha: .35) : null),
            );
          }),
      ]),
    );
  }
}
