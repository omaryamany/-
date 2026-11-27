import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/khatma.dart';
import '../../core/prayer.dart';
import '../../core/quran.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../khatma/khatma_screen.dart';
import '../khatma/khatma_setup.dart';
import '../adhkar/adhkar_screen.dart';
import '../listen/listen_screen.dart';
import '../mushaf/sheets.dart';
import '../prayer/prayer_screen.dart';
import '../shell.dart';
import '../tasbih/tasbih_screen.dart';
import '../../core/hijri.dart';
import '../hifz/hifz_screen.dart';
import '../listen/radio_screen.dart';
import '../seasons/calendar_screen.dart';
import '../seasons/ramadan_screen.dart';
import '../tools/zakat_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onTab;
  const HomeScreen({super.key, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final khatma = KhatmaStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, khatma, PrayerStore.instance]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        final now = DateTime.now();
        var i = 0;
        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
            // ───── الترحيب ─────
            Row(children: [
              const SizedBox(width: 44, height: 44, child: CustomPaint(painter: StarPainter(AppColors.gold, fill: true), child: Center(child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 20)))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting(), style: t.titleLarge),
                  Text('${longDate(now)} · ${Hijri.today.label}', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              IconButton.filledTonal(onPressed: () => showSearchSheet(context, onPick: (g) => openMushaf(context, ayah: g)), icon: const Icon(Icons.search_rounded), tooltip: 'بحث في القرآن'),
            ]).enter(i++),
            const SizedBox(height: 18),

            // ───── ورد اليوم ─────
            const RamadanCard(),
            (khatma.active ? _WirdCard(onTab: onTab) : const _StartKhatmaCard()).enter(i++),

            // ───── الصلاة القادمة ─────
            const SizedBox(height: 14),
            (PrayerStore.instance.configured
                    ? NextPrayerCard(onTap: () => onTab(3))
                    : SoftCard(
                        onTap: () => onTab(3),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: cs.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
                            child: Icon(Icons.mosque_rounded, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('مواقيت الصلاة والأذان', style: t.titleMedium),
                              Text('حدد موقعك مرة واحدة لتفعيل المواقيت والقبلة', style: t.bodySmall),
                            ]),
                          ),
                          Icon(Icons.chevron_left_rounded, color: cs.primary),
                        ]),
                      ))
                .enter(i++),

            // ───── الأذكار ─────
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _Quick(
                  icon: Icons.wb_sunny_outlined,
                  label: 'أذكار الصباح',
                  highlight: now.hour >= 4 && now.hour < 12,
                  onTap: () => openAdhkar(context, AdhkarKind.morning),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Quick(
                  icon: Icons.nights_stay_outlined,
                  label: 'أذكار المساء',
                  highlight: now.hour >= 15 || now.hour < 4,
                  onTap: () => openAdhkar(context, AdhkarKind.evening),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _Quick(icon: Icons.auto_awesome_outlined, label: 'بعد الصلاة', onTap: () => openAdhkar(context, AdhkarKind.afterPrayer))),
            ]).enter(i++),

            // ───── متابعة القراءة ─────
            if (store.hasHistory) ...[
              const SizedBox(height: 14),
              const _ContinueCard().enter(i++),
            ],

            // ───── الجمعة: سورة الكهف ─────
            if (now.weekday == DateTime.friday) ...[
              const SizedBox(height: 14),
              SoftCard(
                onTap: () => openMushaf(context, ayah: Quran.surah(18).start),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.wb_sunny_rounded, color: AppColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('جمعة مباركة', style: t.titleMedium),
                      Text('اقرأ سورة الكهف — تبدأ من صفحة ${arDigits(Quran.surah(18).page)}', style: t.bodySmall),
                    ]),
                  ),
                  const Icon(Icons.chevron_left_rounded),
                ]),
              ).enter(i++),
            ],

            // ───── إحصائيات ─────
            const SectionTitle('قراءتك').enter(i++),
            Row(children: [
              Expanded(child: _Stat(icon: Icons.local_fire_department_rounded, color: AppColors.amber, value: arDigits(store.streak), label: 'أيام متتالية')),
              const SizedBox(width: 10),
              Expanded(child: _Stat(icon: Icons.auto_stories_rounded, color: AppColors.pine, value: arDigits(store.todayPages), label: 'صفحات اليوم')),
              const SizedBox(width: 10),
              Expanded(child: _Stat(icon: Icons.workspace_premium_rounded, color: AppColors.gold, value: arDigits(khatma.completedCount), label: 'ختمات')),
            ]).enter(i++),
            const SizedBox(height: 10),
            _WeekChart(values: store.lastWeek).enter(i++),

            // ───── وصول سريع ─────
            const SectionTitle('وصول سريع').enter(i++),
            Row(children: [
              Expanded(child: _Quick(icon: Icons.format_list_bulleted_rounded, label: 'السور', onTap: () => onTab(1))),
              const SizedBox(width: 8),
              Expanded(
                child: _Quick(
                  icon: Icons.bookmarks_rounded,
                  label: 'العلامات',
                  badge: store.bookmarks.isEmpty ? null : arDigits(store.bookmarks.length),
                  onTap: () => showIndexSheet(context, onPick: (g) => openMushaf(context, ayah: g)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _Quick(icon: Icons.headphones_rounded, label: 'الاستماع', onTap: () => openListen(context))),
              const SizedBox(width: 8),
              Expanded(child: _Quick(icon: Icons.blur_circular_rounded, label: 'المسبحة', onTap: () => openTasbih(context))),
            ]).enter(i++),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Quick(icon: Icons.psychology_rounded, label: 'الحفظ', onTap: () => openHifz(context))),
              const SizedBox(width: 8),
              Expanded(child: _Quick(icon: Icons.radio_rounded, label: 'الإذاعات', onTap: () => openRadio(context))),
              const SizedBox(width: 8),
              Expanded(child: _Quick(icon: Icons.calendar_month_rounded, label: 'التقويم', onTap: () => openCalendar(context))),
              const SizedBox(width: 8),
              Expanded(child: _Quick(icon: Icons.calculate_rounded, label: 'الزكاة', onTap: () => openZakat(context))),
            ]).enter(i++),
          ]),
        );
      },
    );
  }
}

/// بطاقة ورد اليوم (والختمة شغالة)
class _WirdCard extends StatelessWidget {
  final ValueChanged<int> onTab;
  const _WirdCard({required this.onTab});

  @override
  Widget build(BuildContext context) {
    final k = KhatmaStore.instance;
    final t = Theme.of(context).textTheme;
    final p = k.plan!;
    final white70 = Colors.white.withValues(alpha: .78);

    if (k.finished) {
      return HeroCard(
        onTap: () => openKhatma(context),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded, size: 46, color: AppColors.goldLight),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أتممت الختمة — مبارك!', style: t.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text('ابدأ ختمة جديدة من صفحة الختمة', style: t.bodyMedium?.copyWith(color: white70)),
            ]),
          ),
        ]),
      );
    }

    final done = k.todayDone;
    final portionStart = k.nextPage;
    final target = k.todayTarget;
    // ورد النهارده حسب الخطة (ولو فيه متأخر بيتحسب كله مطلوب)
    final todayTotal = math.max(math.max(1, target - k.yesterdayTarget), k.remainingToday);
    final todayProgress = done ? 1.0 : (1 - k.remainingToday / todayTotal).clamp(0.0, 1.0);

    return HeroCard(
      onTap: () => openWird(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('وِرد اليوم', style: t.titleMedium?.copyWith(color: AppColors.goldLight)),
          const Spacer(),
          _GlassPill(k.today > p.days ? 'بعد موعد الختمة' : 'اليوم ${arDigits(k.today)} من ${arDigits(p.days)}'),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          ProgressRing(
            value: todayProgress,
            size: 96,
            stroke: 9,
            center: Icon(done ? Icons.check_rounded : Icons.menu_book_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (done) ...[
                Text('أتممت ورد اليوم', style: t.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(k.ahead > 0 ? 'وسبقت الخطة بـ ${pagesLabel(k.ahead)} — بارك الله فيك' : 'تقبّل الله منك. يمكنك القراءة زيادة.', style: t.bodyMedium?.copyWith(color: white70)),
              ] else ...[
                Text(pagesLabel(k.remainingToday), style: t.headlineMedium?.copyWith(color: Colors.white)),
                Text('من صفحة ${arDigits(portionStart)} إلى ${arDigits(target)}', style: t.bodyMedium?.copyWith(color: white70)),
                Text('سورة ${Quran.surahOfPage(portionStart).name}', style: AppTheme.quran(size: 17, color: AppColors.goldLight, height: 1.6)),
              ],
            ]),
          ),
        ]),
        if (!done && k.behind > 0) ...[
          const SizedBox(height: 10),
          _GlassPill('منها ${pagesLabel(k.behind)} من أيام سابقة', icon: Icons.history_rounded),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.pineDeep),
              onPressed: () => openWird(context),
              icon: Icon(done ? Icons.add_rounded : Icons.play_arrow_rounded),
              label: Text(done ? 'اقرأ زيادة' : (k.remainingToday < todayTotal ? 'أكمل الورد' : 'ابدأ الورد')),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.outlined(
            style: IconButton.styleFrom(side: const BorderSide(color: Colors.white54), minimumSize: const Size(52, 52)),
            onPressed: () => openKhatma(context),
            icon: const Icon(Icons.insights_rounded, color: Colors.white),
            tooltip: 'تفاصيل الختمة',
          ),
        ]),
      ]),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _GlassPill(this.text, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 4)],
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// مفيش ختمة — دعوة لبدء واحدة
class _StartKhatmaCard extends StatelessWidget {
  const _StartKhatmaCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return HeroCard(
      onTap: () => showKhatmaSetup(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ابدأ ختمتك', style: t.headlineMedium?.copyWith(color: Colors.white)),
        const SizedBox(height: 6),
        Text('اختر المدة التي تناسبك، ونقسّم لك المصحف وِردًا يوميًا مع تذكير لطيف في الوقت الذي تحدده.',
            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .8))),
        const SizedBox(height: 16),
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

class _ContinueCard extends StatelessWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final page = store.lastPage;
    final s = Quran.surahOfPage(page);
    final where = store.lastAyah != null && Quran.pageOf(store.lastAyah!) == page ? Quran.formatAyah(store.lastAyah!) : 'سورة ${s.name}';
    return SoftCard(
      onTap: () => openMushaf(context, page: page),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
          child: Icon(Icons.bookmark_rounded, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('متابعة القراءة', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            Text(where, style: t.titleMedium),
            Text('صفحة ${arDigits(page)} · الجزء ${arDigits(Quran.juzOfPage(page))} · ${relativeTime(store.lastAt!)}', style: t.bodySmall),
          ]),
        ),
        Icon(Icons.chevron_left_rounded, color: cs.primary),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: t.headlineMedium?.copyWith(height: 1)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// أعمدة الصفحات في آخر ٧ أيام
class _WeekChart extends StatelessWidget {
  final List<int> values;
  const _WeekChart({required this.values});

  static const _days = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final maxV = math.max(1, values.reduce(math.max));
    final now = DateTime.now();
    final total = values.fold<int>(0, (a, b) => a + b);
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('آخر ٧ أيام', style: t.titleSmall),
          const Spacer(),
          Text('${pagesLabel(total)} إجمالًا', style: t.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var d = 0; d < 7; d++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (values[d] > 0) Text(arDigits(values[d]), style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: values[d] / maxV),
                    duration: Duration(milliseconds: 600 + d * 80),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Container(
                      width: 18,
                      height: 6 + 52 * v,
                      decoration: BoxDecoration(
                        gradient: values[d] > 0 ? AppColors.goldGradient : null,
                        color: values[d] > 0 ? null : cs.outlineVariant.withValues(alpha: .4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_days[now.subtract(Duration(days: 6 - d)).weekday - 1],
                      style: t.labelSmall?.copyWith(fontWeight: d == 6 ? FontWeight.w800 : FontWeight.w500, color: d == 6 ? cs.primary : null)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool highlight;
  final VoidCallback onTap;
  const _Quick({required this.icon, required this.label, required this.onTap, this.badge, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SoftCard(
      onTap: onTap,
      color: highlight ? AppColors.gold.withValues(alpha: .14) : null,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(children: [
        Badge(isLabelVisible: badge != null, label: Text(badge ?? ''), child: Icon(icon, color: highlight ? AppColors.gold : cs.primary, size: 26)),
        const SizedBox(height: 8),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }
}
