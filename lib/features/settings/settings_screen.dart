import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/audio.dart';
import '../../core/prayer.dart';
import '../../core/reminders.dart';
import '../../core/quran.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../khatma/khatma_screen.dart';
import '../mushaf/mushaf_settings.dart';
import '../prayer/prayer_screen.dart';
import '../adhkar/adhkar_screen.dart';
import '../../core/adhkar_data.dart';
import '../hifz/hifz_screen.dart';
import '../library/library_screens.dart';
import '../listen/radio_screen.dart';
import '../prayer/qibla_screen.dart';
import '../seasons/calendar_screen.dart';
import '../seasons/ramadan_screen.dart';
import '../tasbih/tasbih_screen.dart';
import '../tools/zakat_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([store, PrayerStore.instance]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
            Text('المزيد', style: t.headlineMedium),
            const SizedBox(height: 8),
            const _Features(),
            const SectionTitle('المظهر'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (s) => store.setThemeMode(s.first),
            ),
            const SectionTitle('المصحف'),
            Text('لون الصفحة', style: t.titleSmall),
            const SizedBox(height: 8),
            const MushafThemePicker(),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إبقاء الشاشة مضاءة أثناء القراءة'),
              value: store.keepAwake,
              onChanged: store.setKeepAwake,
            ),
            const SectionTitle('التلاوة'),
            const ReciterPicker(),
            const SizedBox(height: 12),
            const _AudioDownloads(),
            const SectionTitle('التذكيرات'),
            const ReminderTiles(),
            const SectionTitle('تذكيرات الأذكار'),
            const _AdhkarReminders(),
            const SectionTitle('الصلاة'),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('الموقع'),
                  subtitle: Text(PrayerStore.instance.configured ? PrayerStore.instance.place : 'لم يُحدد بعد'),
                  onTap: () => showLocationPicker(context),
                ),
                if (PrayerStore.instance.configured)
                  ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('إعدادات المواقيت والأذان'),
                    subtitle: Text(PrayerStore.instance.method.name),
                    onTap: () => showPrayerSettings(context),
                  ),
              ]),
            ),
            const SectionTitle('عن التطبيق'),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('عن مُرتِّل'),
                  subtitle: const Text('مجاني لوجه الله — بلا إعلانات ولا حسابات'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

/// تذكيرات أذكار الصباح والمساء، والذكر خلال اليوم، وصيام الاثنين والخميس
class _AdhkarReminders extends StatelessWidget {
  const _AdhkarReminders();

  @override
  Widget build(BuildContext context) {
    final r = Reminders.instance;
    Future<void> guard(Future<bool> f) async {
      if (!await f && context.mounted) toast(context, 'اسمح لمُرتِّل بالإشعارات من إعدادات الهاتف', error: true);
    }

    Future<TimeOfDay?> pick(int h, int m) => showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m), helpText: 'وقت التذكير');

    return ListenableBuilder(
      listenable: r,
      builder: (context, _) => SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('أذكار الصباح'),
            subtitle: Text(r.morningOn ? 'كل يوم ${timeLabel(r.morningH, r.morningM)} — اضغط لتغيير الوقت' : 'متوقف'),
            value: r.morningOn,
            onChanged: (v) => guard(r.setAdhkar(morning: v)),
          ),
          if (r.morningOn)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () async {
                  final x = await pick(r.morningH, r.morningM);
                  if (x != null) await r.setAdhkar(mh: x.hour, mm: x.minute);
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text('وقت أذكار الصباح: ${timeLabel(r.morningH, r.morningM)}'),
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.nights_stay_outlined),
            title: const Text('أذكار المساء'),
            subtitle: Text(r.eveningOn ? 'كل يوم ${timeLabel(r.eveningH, r.eveningM)}' : 'متوقف'),
            value: r.eveningOn,
            onChanged: (v) => guard(r.setAdhkar(evening: v)),
          ),
          if (r.eveningOn)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () async {
                  final x = await pick(r.eveningH, r.eveningM);
                  if (x != null) await r.setAdhkar(eh: x.hour, em: x.minute);
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text('وقت أذكار المساء: ${timeLabel(r.eveningH, r.eveningM)}'),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.favorite_outline_rounded),
            title: const Text('ذكّرني بالذكر خلال اليوم'),
            subtitle: const Text('الصلاة على النبي ﷺ، التسبيح، الاستغفار… من ٨ صباحًا حتى ١٠ مساءً'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final h in [0, 2, 3, 4])
                ChoiceChip(
                  selected: r.dhikrEvery == h,
                  label: Text(h == 0 ? 'متوقف' : 'كل ${countLabel(h, 'ساعة', 'ساعتين', 'ساعات')}'),
                  onSelected: (_) => guard(r.setAdhkar(every: h)),
                ),
            ]),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.restaurant_outlined),
            title: const Text('صيام الاثنين والخميس'),
            subtitle: const Text('تذكير الليلة السابقة الساعة ٩ مساءً'),
            value: r.fastingOn,
            onChanged: (v) => guard(r.setAdhkar(fasting: v)),
          ),
        ]),
      ),
    );
  }
}

/// تنزيل تلاوة سورة كاملة للاستماع بدون إنترنت
class _AudioDownloads extends StatefulWidget {
  const _AudioDownloads();
  @override
  State<_AudioDownloads> createState() => _AudioDownloadsState();
}

class _AudioDownloadsState extends State<_AudioDownloads> {
  final store = AppStore.instance;
  int _surah = 1;
  int _have = 0, _done = 0;
  bool _downloading = false;
  double _size = 0;
  String? _reciter;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _refresh();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (_reciter != store.reciter) _refresh();
  }

  Future<void> _refresh() async {
    _reciter = store.reciter;
    final have = await AudioStore.downloadedCount(store.reciter, _surah);
    final size = await AudioStore.sizeMb();
    if (mounted) {
      setState(() {
        _have = have;
        _size = size;
      });
    }
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _done = 0;
    });
    final ok = await AudioStore.downloadSurah(store.reciter, _surah, (d, _) {
      if (mounted) setState(() => _done = d);
    });
    if (!mounted) return;
    setState(() => _downloading = false);
    await _refresh();
    if (mounted) toast(context, ok ? 'تم التنزيل — تعمل الآن بدون إنترنت' : 'تم تنزيل جزء منها — أكمل عند توفر الإنترنت', error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Quran.surah(_surah);
    final complete = _have == s.ayahCount;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('الاستماع بدون إنترنت', style: t.titleSmall),
        const SizedBox(height: 4),
        Text('كل آية تسمعها تُحفظ على جهازك تلقائيًا، ويمكنك تنزيل سورة كاملة مسبقًا.', style: t.bodySmall),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _surah,
              decoration: const InputDecoration(labelText: 'السورة', isDense: true),
              items: [for (final x in Quran.surahs) DropdownMenuItem(value: x.number, child: Text('${arDigits(x.number)}. ${x.name}'))],
              onChanged: _downloading
                  ? null
                  : (v) {
                      setState(() => _surah = v!);
                      _refresh();
                    },
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _downloading || complete ? null : _download,
            icon: Icon(complete ? Icons.download_done_rounded : Icons.download_rounded),
            label: Text(complete ? 'محمّلة' : 'تنزيل'),
          ),
        ]),
        const SizedBox(height: 10),
        if (_downloading)
          LinearProgressIndicator(value: _done / s.ayahCount, borderRadius: BorderRadius.circular(9))
        else
          Text('المحفوظ من السورة: ${arDigits(_have)} من ${arDigits(s.ayahCount)} آية · إجمالي التلاوات: ${arDigits(_size.toStringAsFixed(1))} ميجا', style: t.bodySmall),
        if (_size > 0 && !_downloading)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () async {
                if (!await confirm(context, 'حذف كل التلاوات المحفوظة؟', ok: 'حذف', danger: true)) return;
                await AudioStore.clear();
                _refresh();
              },
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('حذف التلاوات المحفوظة'),
            ),
          ),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget source(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall),
            Text(body, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('عن مُرتِّل')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 32), children: [
        HeroCard(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(width: 72, height: 72, child: CustomPaint(painter: StarPainter(AppColors.gold, fill: true), child: Center(child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 32)))),
            const SizedBox(height: 12),
            Text('مُرتِّل', style: AppTheme.quran(size: 34, color: Colors.white, height: 1.4)),
            Text('﴿وَرَتِّلِ ٱلْقُرْءَانَ تَرْتِيلًا﴾', style: AppTheme.quran(size: 20, color: AppColors.goldLight, height: 1.8)),
            const SizedBox(height: 10),
            Text('تطبيق مجاني لوجه الله تعالى: بلا إعلانات، وبلا حسابات، وبلا جمع لأي بيانات. كل ما تسجله يبقى على جهازك فقط.',
                textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .85))),
          ]),
        ),
        const SectionTitle('المصادر'),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            source('رسم المصحف', 'خطوط صفحات مصحف المدينة النبوية (الإصدار الأول) من مجمع الملك فهد لطباعة المصحف الشريف، وتخطيط الأسطر من بيانات Quran.com.'),
            source('نص المصحف والبحث', 'النص العثماني من مشروع تنزيل (Tanzil.net)، منقول دون أي تعديل.'),
            source('التفسير', 'التفسير الميسّر — مجمع الملك فهد (نسخة Tanzil.net)، وتفسيرا السعدي وابن كثير من بيانات Quran.com (مشروع tafsir_api).'),
            source('الأربعون النووية', 'نص الأحاديث من مشروع hadith-api (fawazahmed0).'),
            source('الإذاعات', 'إذاعة القرآن الكريم من القاهرة والسعودية، وإذاعات القراء من موقع mp3quran.net.'),
            source('التقويم الهجري', 'تقويم أم القرى، مع إمكانية تعديل يوم أو يومين حسب رؤية الهلال.'),
            source('الأذكار', 'من كتاب «حصن المسلم»، والآيات من نص المصحف نفسه.'),
            source('مواقيت الصلاة', 'تُحسب فلكيًا على الهاتف (طريقة الهيئة المصرية العامة للمساحة افتراضيًا)، والأحزاب من بيانات Tanzil.'),
            source('التلاوات', 'من موقع EveryAyah.com، آية بآية.'),
            source('الخطوط', 'خط أميري قرآن، وخط Noto Sans Arabic (رخصة OFL).'),
          ]),
        ),
        const SizedBox(height: 18),
        Text('إن وجدت خطأ في عرض أي صفحة فأخبرنا ليُصحَّح — وجزاك الله خيرًا.', textAlign: TextAlign.center, style: t.bodySmall),
        const SizedBox(height: 6),
        Text('الإصدار ١٫٥', textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// كل أدوات التطبيق في شبكة واحدة
class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color, VoidCallback)>[
      (Icons.psychology_rounded, 'الحفظ', const Color(0xFF2A9D9A), () => openHifz(context)),
      (Icons.radio_rounded, 'الإذاعات', const Color(0xFF1E3A6E), () => openRadio(context)),
      (Icons.nightlight_round, 'رمضان', const Color(0xFFE2A13B), () => openRamadan(context)),
      (Icons.calendar_month_rounded, 'التقويم الهجري', const Color(0xFF6B4A8F), () => openCalendar(context)),
      (Icons.calculate_rounded, 'حاسبة الزكاة', const Color(0xFF3E9471), () => openZakat(context)),
      (Icons.blur_circular_rounded, 'المسبحة', const Color(0xFF2A7FA0), () => openTasbih(context)),
      (Icons.auto_awesome_rounded, 'الأسماء الحسنى', const Color(0xFFC9733F), () => openAsma(context)),
      (Icons.format_quote_rounded, 'الأربعون النووية', const Color(0xFF4A4FA3), () => openNawawi(context)),
      (Icons.healing_rounded, 'الرقية الشرعية', const Color(0xFF14405A), () => openAdhkar(context, AdhkarKind.ruqyah)),
      (Icons.explore_rounded, 'القبلة', const Color(0xFF85391A), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QiblaScreen()))),
    ];
    final t = Theme.of(context).textTheme;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final (icon, label, color, onTap) in items)
          SoftCard(
            onTap: onTap,
            padding: const EdgeInsets.all(8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, maxLines: 2, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
            ]),
          ),
      ],
    );
  }
}
