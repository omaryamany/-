import 'package:flutter/material.dart';

import '../../core/adhan_sounds.dart';
import '../../core/arabic.dart';
import '../../core/cities.dart';
import '../../core/prayer.dart';
import '../../core/prayer_calc.dart';
import '../../core/reminders.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../adhkar/adhkar_screen.dart';
import 'qibla_screen.dart';

String _fmt(DateTime t) => timeLabel(t.hour, t.minute);

/// «بعد ساعتين و١٥ دقيقة»
String untilLabel(DateTime at) {
  final d = at.difference(DateTime.now());
  final h = d.inHours, m = d.inMinutes % 60 + (d.inSeconds % 60 > 0 ? 1 : 0);
  final mm = m == 60 ? 0 : m;
  final hh = m == 60 ? h + 1 : h;
  if (hh == 0) return 'بعد ${minutesLabel(mm == 0 ? 1 : mm)}';
  final hs = countLabel(hh, 'ساعة', 'ساعتين', 'ساعات');
  return mm == 0 ? 'بعد $hs' : 'بعد $hs و${minutesLabel(mm)}';
}

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ps = PrayerStore.instance;
    return ListenableBuilder(
      listenable: ps,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
            Row(children: [
              Expanded(child: Text('الصلاة', style: t.headlineMedium)),
              if (ps.configured)
                IconButton.filledTonal(tooltip: 'إعدادات المواقيت', onPressed: () => showPrayerSettings(context), icon: const Icon(Icons.tune_rounded)),
            ]),
            const SizedBox(height: 14),
            if (!ps.configured) const _SetLocation() else ...[
              const NextPrayerCard(),
              const SizedBox(height: 14),
              const _TimesList(),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _Tile(
                    icon: Icons.explore_rounded,
                    title: 'اتجاه القبلة',
                    subtitle: '${arDigits(ps.qibla.round())}° من الشمال',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QiblaScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    icon: Icons.auto_awesome_rounded,
                    title: 'أذكار الصلاة',
                    subtitle: 'بعد السلام',
                    onTap: () => openAdhkar(context, AdhkarKind.afterPrayer),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

/// بطاقة الصلاة الجاية مع العدّ التنازلي (مستخدمة في الرئيسية كمان)
class NextPrayerCard extends StatelessWidget {
  final VoidCallback? onTap;
  const NextPrayerCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ps = PrayerStore.instance;
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: ps,
      builder: (context, _) {
        final n = ps.next;
        if (n == null) return const SizedBox.shrink();
        return HeroCard(
          onTap: onTap,
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .12), border: Border.all(color: Colors.white24)),
              child: Icon(_icon(n.prayer), color: AppColors.goldLight, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الصلاة القادمة', style: t.bodySmall?.copyWith(color: Colors.white70)),
                Text('${n.prayer.arOn(n.at)} · ${_fmt(n.at)}', style: t.titleLarge?.copyWith(color: Colors.white)),
                Text(untilLabel(n.at), style: t.bodyMedium?.copyWith(color: AppColors.goldLight, fontWeight: FontWeight.w600)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Icon(Icons.place_rounded, size: 16, color: Colors.white70),
              Text(ps.place.isEmpty ? '—' : ps.place, style: t.labelSmall?.copyWith(color: Colors.white70)),
            ]),
          ]),
        );
      },
    );
  }
}

IconData _icon(Prayer p) => switch (p) {
      Prayer.fajr => Icons.nights_stay_rounded,
      Prayer.sunrise => Icons.wb_twilight_rounded,
      Prayer.dhuhr => Icons.wb_sunny_rounded,
      Prayer.asr => Icons.light_mode_rounded,
      Prayer.maghrib => Icons.wb_twilight_rounded,
      Prayer.isha => Icons.bedtime_rounded,
    };

class _TimesList extends StatelessWidget {
  const _TimesList();

  @override
  Widget build(BuildContext context) {
    final ps = PrayerStore.instance;
    final day = ps.today;
    final cur = ps.current;
    final next = ps.next;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            Text(longDate(DateTime.now()), style: t.titleSmall),
            const Spacer(),
            InkWell(
              onTap: () => showLocationPicker(context),
              child: Row(children: [
                Icon(Icons.place_outlined, size: 16, color: cs.primary),
                Text(ps.place, style: t.labelMedium?.copyWith(color: cs.primary)),
              ]),
            ),
          ]),
        ),
        for (final p in Prayer.values)
          Builder(builder: (context) {
            final isNext = next != null && next.prayer == p && next.at.day == day[p].day;
            final isCur = cur == p;
            final canAdhan = p != Prayer.sunrise;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isNext ? cs.primary.withValues(alpha: .10) : null,
                borderRadius: BorderRadius.circular(14),
                border: isNext ? Border.all(color: cs.primary.withValues(alpha: .35)) : null,
              ),
              child: ListTile(
                dense: true,
                leading: Icon(_icon(p), color: isNext || isCur ? cs.primary : cs.onSurfaceVariant),
                title: Text(p.arOn(day.date), style: t.titleMedium?.copyWith(fontWeight: isNext ? FontWeight.w800 : FontWeight.w600)),
                subtitle: isNext ? Text(untilLabel(day[p]), style: t.bodySmall?.copyWith(color: cs.primary)) : null,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_fmt(day[p]), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  if (canAdhan)
                    IconButton(
                      tooltip: ps.adhan.contains(p) ? 'إيقاف الأذان' : 'تشغيل الأذان',
                      onPressed: () async {
                        final ok = await ps.toggleAdhan(p, !ps.adhan.contains(p));
                        if (!ok && context.mounted) toast(context, 'اسمح لمُرتِّل بالإشعارات من إعدادات الهاتف', error: true);
                      },
                      icon: Icon(ps.adhan.contains(p) ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                          color: ps.adhan.contains(p) ? cs.primary : cs.outline),
                    )
                  else
                    const SizedBox(width: 48),
                ]),
              ),
            );
          }),
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.gold),
        ),
        const SizedBox(height: 10),
        Text(title, style: t.titleMedium),
        Text(subtitle, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _SetLocation extends StatefulWidget {
  const _SetLocation();
  @override
  State<_SetLocation> createState() => _SetLocationState();
}

class _SetLocationState extends State<_SetLocation> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HeroCard(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.mosque_rounded, size: 60, color: AppColors.goldLight),
        const SizedBox(height: 12),
        Text('مواقيت الصلاة والأذان', style: t.titleLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 6),
        Text('حدد موقعك مرة واحدة، وتُحسب المواقيت على هاتفك بدون إنترنت.',
            textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .8))),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final err = await PrayerStore.instance.locate();
                  if (!mounted) return;
                  setState(() => _busy = false);
                  if (err != null) toast(context, err, error: true);
                },
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded),
          label: const Text('حدد موقعي تلقائيًا'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => showLocationPicker(context), child: const Text('أو اختر مدينتك', style: TextStyle(color: Colors.white))),
      ]),
    );
  }
}

/// اختيار الموقع: GPS أو مدينة من القائمة
void showLocationPicker(BuildContext context) {
  showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _CitySheet());
}

class _CitySheet extends StatefulWidget {
  const _CitySheet();
  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  String _q = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final q = normalizeArabic(_q);
    final list = q.isEmpty ? cities : cities.where((c) => normalizeArabic(c.name).contains(q) || normalizeArabic(c.country).contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'ابحث عن مدينة', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          ListTile(
            leading: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded, color: AppColors.pine),
            title: const Text('استخدم موقعي الحالي (GPS)'),
            onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final err = await PrayerStore.instance.locate();
                    if (!context.mounted) return;
                    setState(() => _busy = false);
                    if (err != null) {
                      toast(context, err, error: true);
                    } else {
                      Navigator.pop(context);
                    }
                  },
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                return ListTile(
                  title: Text(c.name),
                  subtitle: Text('${c.country} · ${CalcMethod.byId(c.method).name}'),
                  onTap: () async {
                    await PrayerStore.instance.setCity(c);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// إعدادات المواقيت: طريقة الحساب، العصر، التنبيه قبل الأذان، الضبط اليدوي
void showPrayerSettings(BuildContext context) {
  showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _SettingsSheet());
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool? _exact;

  @override
  void initState() {
    super.initState();
    Reminders.instance.exactAllowed().then((v) {
      if (mounted) setState(() => _exact = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ps = PrayerStore.instance;
    return ListenableBuilder(
      listenable: ps,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .9,
          maxChildSize: .95,
          builder: (context, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
            Text('إعدادات المواقيت', style: t.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_rounded),
              title: const Text('الموقع'),
              subtitle: Text(ps.place),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => showLocationPicker(context),
            ),
            const Divider(),
            Text('صوت الأذان', style: t.titleSmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.campaign_rounded, color: AppColors.turquoise),
              title: const Text('الظهر والعصر والمغرب والعشاء'),
              subtitle: Text(AdhanSound.byId(ps.sound).name),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => showAdhanPicker(context, fajr: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.nights_stay_rounded, color: AppColors.turquoise),
              title: const Text('الفجر'),
              subtitle: Text(AdhanSound.byId(ps.fajrSound).name),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => showAdhanPicker(context, fajr: true),
            ),
            const Divider(),
            Text('طريقة الحساب', style: t.titleSmall),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: ps.methodId,
              onChanged: (v) => v == null ? null : ps.setMethod(v),
              child: Column(children: [
                for (final m in CalcMethod.all)
                  RadioListTile<String>(contentPadding: EdgeInsets.zero, dense: true, value: m.id, title: Text(m.name)),
              ]),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('العصر على المذهب الحنفي'),
              subtitle: const Text('يتأخر العصر قليلًا (ظل الشيء مثليه)'),
              value: ps.hanafi,
              onChanged: ps.setHanafi,
            ),
            const Divider(),
            Text('تنبيه قبل الأذان', style: t.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in [0, 5, 10, 15, 30])
                ChoiceChip(selected: ps.preMinutes == m, label: Text(m == 0 ? 'بدون' : minutesLabel(m)), onSelected: (_) => ps.setPre(m)),
            ]),
            if (_exact == false) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('ليظهر الأذان في وقته بالدقيقة، اسمح لمُرتِّل بضبط المنبّهات الدقيقة.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await Reminders.instance.requestExact();
                      final v = await Reminders.instance.exactAllowed();
                      if (mounted) setState(() => _exact = v);
                      await ps.reschedule();
                    },
                    child: const Text('السماح'),
                  ),
                ]),
              ),
            ],
            const Divider(height: 28),
            Text('ضبط يدوي (بالدقائق)', style: t.titleSmall),
            Text('لو المواقيت مختلفة قليلًا عن مسجدك، عدّلها هنا.', style: t.bodySmall),
            for (final p in Prayer.values)
              Row(children: [
                Expanded(child: Text(p.ar)),
                IconButton(onPressed: () => ps.setAdjust(p, (ps.adjust[p] ?? 0) - 1), icon: const Icon(Icons.remove_circle_outline_rounded)),
                SizedBox(
                  width: 44,
                  child: Text(
                    (ps.adjust[p] ?? 0) == 0 ? '٠' : '${(ps.adjust[p] ?? 0) > 0 ? '+' : '−'}${arDigits((ps.adjust[p] ?? 0).abs())}',
                    textAlign: TextAlign.center,
                    style: t.titleMedium,
                  ),
                ),
                IconButton(onPressed: () => ps.setAdjust(p, (ps.adjust[p] ?? 0) + 1), icon: const Icon(Icons.add_circle_outline_rounded)),
              ]),
          ]),
        );
      },
    );
  }
}

/// اختيار صوت الأذان مع زر تجربة لكل صوت
void showAdhanPicker(BuildContext context, {required bool fajr}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      maxChildSize: .95,
      builder: (c, sc) => ListenableBuilder(
        listenable: PrayerStore.instance,
        builder: (c, _) {
          final ps = PrayerStore.instance;
          final selected = fajr ? ps.fajrSound : ps.sound;
          final groups = <String, List<AdhanSound>>{};
          for (final a in AdhanSound.all) {
            groups.putIfAbsent(a.group, () => []).add(a);
          }
          return ListView(controller: sc, padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(fajr ? 'صوت أذان الفجر' : 'صوت الأذان', style: Theme.of(c).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('اضغط ▶ للتجربة، واضغط على الاسم للاختيار. الأذان بيشتغل كامل على صوت المنبّه.', style: Theme.of(c).textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(children: [
                const SizedBox(width: 8),
                const Icon(Icons.volume_up_rounded, color: AppColors.turquoise),
                const SizedBox(width: 6),
                Text('مستوى الصوت', style: Theme.of(c).textTheme.titleSmall),
                Expanded(child: _VolumeSlider(initial: ps.volume)),
              ]),
            ),
            for (final g in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(g.key, style: Theme.of(c).textTheme.titleSmall?.copyWith(color: AppColors.turquoise)),
              ),
              for (final a in g.value)
                ListTile(
                  leading: Icon(selected == a.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: selected == a.id ? AppColors.turquoise : null),
                  title: Text(a.name, style: TextStyle(fontWeight: selected == a.id ? FontWeight.w800 : FontWeight.w500)),
                  trailing: IconButton(
                    tooltip: 'تجربة',
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    onPressed: () => Reminders.instance.previewAdhan(a.id, volume: ps.volume),
                  ),
                  onTap: () => ps.setSound(a.id, fajr: fajr),
                ),
            ],
          ]);
        },
      ),
    ),
  ).whenComplete(Reminders.instance.stopPreview);
}

/// مستوى صوت الأذان: بيتحفظ لما تسيب الشريط (عشان الجدولة ماتتعادش مع كل حركة)
class _VolumeSlider extends StatefulWidget {
  final int initial;
  const _VolumeSlider({required this.initial});
  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _v = widget.initial.toDouble();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Slider(
          value: _v,
          min: 10,
          max: 100,
          divisions: 9,
          activeColor: AppColors.turquoise,
          label: '${arDigits(_v.round())}٪',
          onChanged: (v) => setState(() => _v = v),
          onChangeEnd: (v) => PrayerStore.instance.setVolume(v.round()),
        ),
      ),
      SizedBox(width: 44, child: Text('${arDigits(_v.round())}٪', textAlign: TextAlign.center)),
    ]);
  }
}
