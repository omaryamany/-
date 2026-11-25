import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/khatma.dart';
import '../../core/quran.dart';
import '../../core/reminders.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../shell.dart';
import 'khatma_setup.dart';

/// صفحة الختمة: التقدّم الكلي، ورد اليوم، الجدول، التذكير، والسجل
class KhatmaScreen extends StatelessWidget {
  const KhatmaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final k = KhatmaStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([k, Reminders.instance]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
            Text('الختمة', style: t.headlineMedium),
            const SizedBox(height: 14),
            if (!k.active) ...[
              _NoKhatma(),
            ] else ...[
              const _Overview(),
              const SizedBox(height: 14),
              if (!k.finished) const _TodayCard(),
              const SectionTitle('التذكير'),
              const ReminderTiles(),
              const SectionTitle('خطة الأيام'),
              const _Schedule(),
              const SectionTitle('إدارة الختمة'),
              _Actions(),
            ],
            if (k.history.isNotEmpty) ...[
              const SectionTitle('ختماتك السابقة'),
              for (final h in k.history.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.workspace_premium_rounded, color: AppColors.gold),
                      const SizedBox(width: 10),
                      Expanded(child: Text('من ${shortDate(h.start)} إلى ${shortDate(h.end)} ${h.end.year != DateTime.now().year ? arDigits(h.end.year) : ''}')),
                      Text(daysLabel(h.days), style: t.labelLarge),
                    ]),
                  ),
                ),
            ],
          ]),
        );
      },
    );
  }
}

class _NoKhatma extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HeroCard(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.flag_circle_rounded, size: 64, color: AppColors.goldLight),
        const SizedBox(height: 12),
        Text('لا توجد ختمة حالية', style: t.titleLarge?.copyWith(color: Colors.white)),
        const SizedBox(height: 6),
        Text('حدد مدة الختمة أو وردك اليومي، وسيتابع معك مُرتِّل تقدمك يومًا بيوم.',
            textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .8))),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
          onPressed: () => showKhatmaSetup(context),
          icon: const Icon(Icons.flag_rounded),
          label: const Text('ابدأ ختمة جديدة'),
        ),
      ]),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    final k = KhatmaStore.instance;
    final p = k.plan!;
    final t = Theme.of(context).textTheme;
    final white70 = Colors.white.withValues(alpha: .78);
    String status;
    if (k.finished) {
      status = 'أتممت الختمة — تقبّل الله';
    } else if (k.behind > 0) {
      status = 'متأخر ${pagesLabel(k.behind)} عن الخطة';
    } else if (k.ahead > 0) {
      status = 'متقدم ${pagesLabel(k.ahead)} على الخطة';
    } else {
      status = 'ملتزم بالخطة — أحسنت';
    }
    return HeroCard(
      child: Row(children: [
        ProgressRing(
          value: k.progress,
          size: 120,
          stroke: 11,
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${arDigits((k.progress * 100).floor())}٪', style: t.headlineMedium?.copyWith(color: Colors.white, height: 1)),
            Text('من الختمة', style: t.bodySmall?.copyWith(color: white70)),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status, style: t.titleMedium?.copyWith(color: AppColors.goldLight)),
            const SizedBox(height: 8),
            _line(Icons.menu_book_rounded, '${arDigits(k.pagesDone)} من ${arDigits(k.totalPages)} صفحة'),
            _line(Icons.calendar_today_rounded, k.finished ? 'بدأت ${shortDate(k.startedAt ?? p.start)}' : 'اليوم ${arDigits(k.today.clamp(1, 9999))} من ${arDigits(p.days)}'),
            _line(Icons.event_available_rounded, 'الموعد: ${shortDate(p.endDate)}'),
            _line(Icons.speed_rounded, 'الورد ≈ ${pagesLabel(p.perDay.round().clamp(1, 604))} يوميًا'),
          ]),
        ),
      ]),
    );
  }

  Widget _line(IconData i, String s) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(i, size: 15, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final k = KhatmaStore.instance;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final done = k.todayDone;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.today_rounded, color: done ? AppColors.pine : cs.primary),
          const SizedBox(width: 8),
          Text('ورد اليوم', style: t.titleMedium),
          const Spacer(),
          if (!done) Pill(pagesLabel(k.remainingToday), color: AppColors.amber),
        ]),
        const SizedBox(height: 8),
        if (done)
          Text(
              k.ahead > 0
                  ? 'أتممت ورد اليوم وسبقت الخطة بـ ${pagesLabel(k.ahead)}. وردك القادم يبدأ من صفحة ${arDigits(k.nextPage)}.'
                  : 'أتممت ورد اليوم. وردك القادم يبدأ من صفحة ${arDigits(k.nextPage)}.',
              style: t.bodyMedium)
        else ...[
          Text('من صفحة ${arDigits(k.nextPage)} إلى صفحة ${arDigits(k.todayTarget)}', style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(Quran.pagesSpan(k.nextPage, k.todayTarget), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          if (k.behind > 0) Text('يشمل ${pagesLabel(k.behind)} متأخرة من أيام سابقة', style: t.bodySmall?.copyWith(color: AppColors.amber)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => openWird(context),
              icon: Icon(done ? Icons.add_rounded : Icons.play_arrow_rounded),
              label: Text(done ? 'اقرأ زيادة' : 'اقرأ الورد'),
            ),
          ),
          if (!done) ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () async {
                if (await confirm(context, 'تسجيل ورد اليوم كمكتمل؟', body: 'سيتم احتساب الصفحات حتى صفحة ${arDigits(k.todayTarget)} كمقروءة.', ok: 'نعم، أتممته')) {
                  await k.completeToday();
                }
              },
              child: const Text('قرأته'),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// جدول الأيام: كل يوم ووِرده، والمكتمل عليه علامة
class _Schedule extends StatelessWidget {
  const _Schedule();

  @override
  Widget build(BuildContext context) {
    final k = KhatmaStore.instance;
    final p = k.plan!;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final today = k.today;
    // نعرض من قبل النهارده بيومين لحد ٧ أيام قدّام
    final from = (today - 2).clamp(1, p.days);
    final to = (today + 7).clamp(1, p.days);
    if (from > to) return const SizedBox.shrink();
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        for (var d = from; d <= to; d++)
          Builder(builder: (context) {
            final portion = p.portionOfDay(d);
            final date = DateTime(p.start.year, p.start.month, p.start.day + d - 1);
            final complete = k.cursor >= portion.to;
            final isToday = d == today;
            final empty = portion.to < portion.from;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: complete ? AppColors.pine : (isToday ? AppColors.gold : cs.surfaceContainerHighest),
                child: complete
                    ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                    : Text(arDigits(d), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isToday ? Colors.white : cs.onSurface)),
              ),
              title: Text(isToday ? 'اليوم' : longDate(date), style: t.bodyMedium?.copyWith(fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
              subtitle: Text(empty ? 'راحة' : 'صفحة ${arDigits(portion.from)}${portion.to > portion.from ? ' – ${arDigits(portion.to)}' : ''} · ${Quran.surahOfPage(portion.from).name}'),
              trailing: empty ? null : Text(pagesLabel(portion.to - portion.from + 1), style: t.labelMedium),
            );
          }),
      ]),
    );
  }
}

class _Actions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final k = KhatmaStore.instance;
    final p = k.plan!;
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        if (!k.finished) ...[
          ListTile(
            leading: const Icon(Icons.edit_location_alt_rounded),
            title: const Text('تعديل موضعي في الختمة'),
            subtitle: Text('أتممت حتى صفحة ${arDigits(k.cursor.clamp(p.fromPage - 1, p.toPage))}'),
            onTap: () async {
              final x = await pickPage(context,
                  title: 'آخر صفحة أتممتها',
                  initial: k.cursor.clamp(p.fromPage, p.toPage),
                  min: p.fromPage,
                  max: p.toPage,
                  describe: (v) => 'سورة ${Quran.surahOfPage(v).name}');
              if (x != null) await k.setReached(x);
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range_rounded),
            title: const Text('تغيير موعد الختم'),
            subtitle: Text('الباقي ${daysLabel(k.daysLeft.clamp(1, 9999))}'),
            onTap: () => _reschedule(context),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.restart_alt_rounded),
          title: const Text('ختمة جديدة'),
          onTap: () => showKhatmaSetup(context),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
          title: const Text('إلغاء الختمة الحالية', style: TextStyle(color: AppColors.rose)),
          onTap: () async {
            if (await confirm(context, 'إلغاء الختمة؟', body: 'سيُحذف تقدّم هذه الختمة. الختمات المكتملة تبقى في السجل.', ok: 'إلغاء الختمة', danger: true)) {
              await k.cancel();
            }
          },
        ),
      ]),
    );
  }

  Future<void> _reschedule(BuildContext context) async {
    final k = KhatmaStore.instance;
    var left = k.daysLeft.clamp(1, 365);
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final t = Theme.of(c).textTheme;
          final remaining = k.plan!.toPage - k.cursor;
          final end = DateTime.now().add(Duration(days: left - 1));
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('أختم خلال كم يومًا من اليوم؟', style: t.titleLarge),
              const SizedBox(height: 16),
              Row(children: [
                IconButton.outlined(onPressed: left > 1 ? () => set(() => left--) : null, icon: const Icon(Icons.remove_rounded)),
                Expanded(child: Text(daysLabel(left), textAlign: TextAlign.center, style: t.headlineMedium)),
                IconButton.outlined(onPressed: left < 365 ? () => set(() => left++) : null, icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 8),
              Text('الباقي ${pagesLabel(remaining)} — حوالي ${pagesLabel((remaining / left).ceil())} يوميًا، والختم يوم ${longDate(end)}.',
                  textAlign: TextAlign.center, style: t.bodyMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(c, left), child: const Text('حفظ')),
            ]),
          );
        },
      ),
    );
    if (v != null) await k.rescheduleFromToday(v);
  }
}

/// إعدادات التذكير (مستخدمة هنا وفي الإعدادات)
class ReminderTiles extends StatelessWidget {
  const ReminderTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Reminders.instance;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) => SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('تذكير الورد اليومي'),
            subtitle: Text(r.wirdOn ? 'كل يوم الساعة ${timeLabel(r.hour, r.minute)}' : 'متوقف'),
            value: r.wirdOn,
            onChanged: (v) async {
              final ok = await r.setWird(v);
              if (!ok && context.mounted) toast(context, 'اسمح لمُرتِّل بالإشعارات من إعدادات الهاتف', error: true);
            },
          ),
          if (r.wirdOn)
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('وقت التذكير'),
              trailing: Text(timeLabel(r.hour, r.minute), style: Theme.of(context).textTheme.titleMedium),
              onTap: () async {
                final x = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute), helpText: 'وقت التذكير');
                if (x != null) await r.setWird(true, h: x.hour, m: x.minute);
              },
            ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('تذكير سورة الكهف'),
            subtitle: const Text('كل جمعة الساعة ١٠ صباحًا'),
            value: r.kahfOn,
            onChanged: (v) async {
              final ok = await r.setKahf(v);
              if (!ok && context.mounted) toast(context, 'اسمح لمُرتِّل بالإشعارات من إعدادات الهاتف', error: true);
            },
          ),
        ]),
      ),
    );
  }
}
