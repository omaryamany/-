import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/hijri.dart';
import '../../core/reminders.dart';
import '../../core/seasonal.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'ramadan_screen.dart';

void openCalendar(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));

/// التقويم الهجري: الشهر الحالي بالأيام (هجري وميلادي) + المناسبات الجاية + تذكير الصيام المستحب
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _y = Hijri.today.year, _m = Hijri.today.month;

  void _shift(int d) {
    setState(() {
      _m += d;
      if (_m > 12) {
        _m = 1;
        _y++;
      } else if (_m < 1) {
        _m = 12;
        _y--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = Hijri.today;
    final now = DateTime.now();
    final occ = Hijri.upcoming(days: 370);
    // أول مرة لكل مناسبة (الأيام البيض بتتكرر كل شهر: نعرض أقربها بس)
    final seen = <String>{};
    final list = [for (final o in occ) if (seen.add(o.title)) o];
    final r = Reminders.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('التقويم الهجري')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        HeroCard(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اليوم', style: t.labelLarge?.copyWith(color: Colors.white70)),
                Text(h.label, style: t.headlineSmall?.copyWith(color: AppColors.goldLight, fontWeight: FontWeight.w800)),
                Text('${longDate(now)} ${arDigits(now.year)}', style: t.bodyMedium?.copyWith(color: Colors.white)),
              ]),
            ),
            const Icon(Icons.nightlight_round, color: AppColors.goldLight, size: 40),
          ]),
        ),
        const SizedBox(height: 14),
        _MonthGrid(year: _y, month: _m, onShift: _shift),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Column(children: [
            SwitchListTile(
              value: r.occasionsOn,
              onChanged: (v) async {
                final ok = await r.setSeasonal(occasions: v);
                if (!ok && context.mounted) toast(context, 'اسمح بالإشعارات من إعدادات الموبايل');
                await Seasonal.reschedule();
                setState(() {});
              },
              secondary: const Icon(Icons.notifications_active_rounded, color: AppColors.turquoise),
              title: const Text('ذكّرني بأيام الصيام والمناسبات'),
              subtitle: const Text('الأيام البيض، عرفة، تاسوعاء وعاشوراء، ستة شوال… الليلة اللي قبلها'),
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded, color: AppColors.turquoise),
              title: const Text('تعديل التاريخ الهجري'),
              subtitle: Text(Hijri.offset == 0 ? 'حسب تقويم أم القرى' : '${Hijri.offset > 0 ? '+' : '−'}${arDigits(Hijri.offset.abs())} يوم حسب رؤية الهلال'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'يوم أقل',
                  onPressed: Hijri.offset > -2 ? () => _offset(-1) : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                IconButton(
                  tooltip: 'يوم أكتر',
                  onPressed: Hijri.offset < 2 ? () => _offset(1) : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionTitle('المناسبات الجاية'),
        const SizedBox(height: 8),
        for (final o in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              onTap: o.title == 'أول رمضان' ? () => openRamadan(context) : null,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: (o.fast ? AppColors.turquoise : AppColors.amber).withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Text(arDigits(daysBetween(dateOnly(now), o.date)), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: o.fast ? AppColors.turquoise : AppColors.amber)),
                    Text('يوم', style: t.labelSmall),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('${longDate(o.date)} · ${Hijri.of(o.date).label}', style: t.bodySmall),
                    Text(o.hint, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ]),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Text('التواريخ محسوبة بتقويم أم القرى، وبداية الشهور في مصر بتتحدد برؤية الهلال (دار الإفتاء) فممكن تفرق يوم.',
            textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Future<void> _offset(int d) async {
    await Hijri.setOffset(Hijri.offset + d);
    await Seasonal.reschedule();
    setState(() {
      _y = Hijri.today.year;
      _m = Hijri.today.month;
    });
  }
}

class _MonthGrid extends StatelessWidget {
  final int year, month;
  final ValueChanged<int> onShift;
  const _MonthGrid({required this.year, required this.month, required this.onShift});

  static const _week = ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final first = Hijri.toGregorian(year, month, 1);
    final len = Hijri.monthLength(year, month);
    final lead = (first.weekday + 1) % 7; // السبت = ٠
    final today = dateOnly(DateTime.now());
    final cells = lead + len;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(children: [
        Row(children: [
          IconButton(tooltip: 'الشهر السابق', onPressed: () => onShift(-1), icon: const Icon(Icons.chevron_right_rounded)),
          Expanded(
            child: Column(children: [
              Text('${Hijri.months[month - 1]} ${arDigits(year)} هـ', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text('${shortDate(first)} – ${shortDate(first.add(Duration(days: len - 1)))}', style: t.bodySmall),
            ]),
          ),
          IconButton(tooltip: 'الشهر التالي', onPressed: () => onShift(1), icon: const Icon(Icons.chevron_left_rounded)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (final w in _week) Expanded(child: Text(w, textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
        ]),
        const SizedBox(height: 4),
        for (var row = 0; row * 7 < cells; row++)
          Row(children: [
            for (var c = 0; c < 7; c++)
              Expanded(
                child: Builder(builder: (context) {
                  final i = row * 7 + c - lead;
                  if (i < 0 || i >= len) return const SizedBox(height: 46);
                  final d = i + 1;
                  final g = first.add(Duration(days: i));
                  final isToday = g == today;
                  final mark = Hijri.markOf(month, d);
                  final color = mark == null
                      ? null
                      : (mark == 'البيض' || mark == 'عرفة' || mark == 'عاشوراء' || mark == 'تاسوعاء' || mark == 'رمضان')
                          ? AppColors.turquoise
                          : AppColors.amber;
                  return Container(
                    height: 46,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.pine : color?.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(arDigits(d),
                          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: isToday ? Colors.white : (color ?? cs.onSurface))),
                      Text(arDigits(g.day), style: t.labelSmall?.copyWith(fontSize: 10, color: isToday ? Colors.white70 : cs.onSurfaceVariant)),
                    ]),
                  );
                }),
              ),
          ]),
        const SizedBox(height: 6),
        Wrap(spacing: 12, children: [
          _legend(AppColors.turquoise, 'صيام مستحب / رمضان', t),
          _legend(AppColors.amber, 'عيد ومناسبة', t),
        ]),
      ]),
    );
  }

  Widget _legend(Color c, String s, TextTheme t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(s, style: t.labelSmall),
      ]);
}
