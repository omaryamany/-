import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/khatma.dart';
import '../../core/quran.dart';
import '../../core/reminders.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// إعداد ختمة جديدة: المدة (أو الورد اليومي)، نقطة البداية، والتذكير
Future<void> showKhatmaSetup(BuildContext context) async {
  final k = KhatmaStore.instance;
  if (k.active && !k.finished) {
    final ok = await confirm(context, 'بدء ختمة جديدة؟', body: 'سيتم استبدال ختمتك الحالية (أتممت منها ${pagesLabel(k.pagesDone)}).', ok: 'ختمة جديدة');
    if (!ok || !context.mounted) return;
  }
  await showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _SetupSheet());
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet();
  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  static const _dayPresets = [7, 10, 15, 30, 60, 90];
  static const _pagePresets = [1, 2, 4, 5, 10, 20];

  bool _byDays = true;
  int _days = 30;
  int _perDay = 5;
  bool _resume = false;
  int _reached = 1;
  late bool _remind = Reminders.instance.wirdOn || !KhatmaStore.instance.active;
  late TimeOfDay _time = TimeOfDay(hour: Reminders.instance.hour, minute: Reminders.instance.minute);
  bool _busy = false;

  int get _startAfter => _resume ? _reached : 0;
  int get _remaining => Quran.totalPages - _startAfter;
  int get _planDays => _byDays ? _days : (_remaining / _perDay).ceil();
  double get _avg => _remaining / _planDays;

  Future<void> _start() async {
    setState(() => _busy = true);
    final k = KhatmaStore.instance;
    // لو بدأ قبل كده: الخطة بتغطي الصفحات الباقية بس، والورد يتوزّع عليها
    await k.start(days: _planDays, fromPage: _resume ? _reached + 1 : 1);
    final r = Reminders.instance;
    var reminderOk = true;
    if (_remind) {
      reminderOk = await r.setWird(true, h: _time.hour, m: _time.minute);
    } else if (r.wirdOn) {
      await r.setWird(false);
    }
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, reminderOk ? 'بدأت ختمتك — أعانك الله' : 'بدأت الختمة، لكن التذكير يحتاج السماح بالإشعارات من إعدادات الهاتف', error: !reminderOk);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final end = DateTime.now().add(Duration(days: _planDays - 1));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      maxChildSize: .95,
      builder: (context, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Text('ختمة جديدة', style: t.headlineMedium),
        const SizedBox(height: 4),
        Text('اختر ما يناسب وقتك — القليل الدائم خير من الكثير المنقطع.', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 18),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('أختم في مدة'), icon: Icon(Icons.event_rounded)),
            ButtonSegment(value: false, label: Text('وِرد يومي ثابت'), icon: Icon(Icons.auto_stories_rounded)),
          ],
          selected: {_byDays},
          onSelectionChanged: (s) => setState(() => _byDays = s.first),
        ),
        const SizedBox(height: 16),
        if (_byDays) ...[
          Text('أختم خلال', style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in _dayPresets) ChoiceChip(selected: _days == d, label: Text(d == 30 ? 'شهر' : (d == 60 ? 'شهرين' : daysLabel(d))), onSelected: (_) => setState(() => _days = d)),
          ]),
          const SizedBox(height: 6),
          _Stepper(
            label: 'أو حدد عدد الأيام',
            value: _days,
            min: 1,
            max: 365,
            format: daysLabel,
            onChanged: (v) => setState(() => _days = v),
          ),
        ] else ...[
          Text('أقرأ كل يوم', style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in _pagePresets)
              ChoiceChip(selected: _perDay == p, label: Text(p == 20 ? 'جزء كامل' : (p == 10 ? 'نصف جزء' : pagesLabel(p))), onSelected: (_) => setState(() => _perDay = p)),
          ]),
          const SizedBox(height: 6),
          _Stepper(
            label: 'أو حدد عدد الصفحات',
            value: _perDay,
            min: 1,
            max: 100,
            format: pagesLabel,
            onChanged: (v) => setState(() => _perDay = v),
          ),
        ],
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('بدأت القراءة من قبل'),
          subtitle: Text(_resume ? 'أكمل بعد صفحة ${arDigits(_reached)} (${Quran.surahOfPage(_reached).name})' : 'ابدأ من سورة الفاتحة'),
          value: _resume,
          onChanged: (v) async {
            if (!v) return setState(() => _resume = false);
            final p = await pickPage(context,
                title: 'آخر صفحة أتممتها', initial: _reached, max: Quran.totalPages - 1, describe: (x) => 'سورة ${Quran.surahOfPage(x).name}');
            if (p != null) {
              setState(() {
                _resume = true;
                _reached = p;
              });
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ذكّرني بالورد يوميًا'),
          subtitle: Text(_remind ? 'الساعة ${timeLabel(_time.hour, _time.minute)}' : 'بدون تذكير'),
          value: _remind,
          onChanged: (v) => setState(() => _remind = v),
        ),
        if (_remind)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () async {
                final x = await showTimePicker(context: context, initialTime: _time, helpText: 'وقت التذكير');
                if (x != null) setState(() => _time = x);
              },
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('تغيير الوقت'),
            ),
          ),
        const SizedBox(height: 12),
        // ملخص الخطة
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
          ),
          child: Row(children: [
            const Icon(Icons.event_available_rounded, color: AppColors.gold, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'وِردك حوالي '),
                  TextSpan(text: _avg >= 1 ? pagesLabel(_avg.round()) : 'أقل من صفحة', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: ' يوميًا، وتختم بإذن الله يوم '),
                  TextSpan(text: longDate(end), style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: ' (${daysLabel(_planDays)}).'),
                ]),
                style: t.bodyMedium,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.flag_rounded),
          label: const Text('ابدأ الختمة'),
        ),
      ]),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value, min, max;
  final String Function(int) format;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.format, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Expanded(child: Text(label, style: t.bodyMedium)),
      IconButton.outlined(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_rounded)),
      SizedBox(width: 92, child: Text(format(value), textAlign: TextAlign.center, style: t.titleMedium)),
      IconButton.outlined(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_rounded)),
    ]);
  }
}
