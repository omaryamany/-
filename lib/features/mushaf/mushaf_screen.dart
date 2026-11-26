import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/arabic.dart';
import '../../core/player.dart';
import '../../core/khatma.dart';
import '../../core/mushaf_pack.dart';
import '../../core/quran.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'mushaf_page.dart';
import 'mushaf_settings.dart';
import 'share_ayah.dart';
import 'sheets.dart';
import 'tafsir_sheet.dart';

/// المصحف بالصفحات (٦٠٤ صفحة بنفس رسم مصحف المدينة) — شغال كله من غير نت.
/// ضغطة على آية = تحديدها وأوامرها، وضغطة على مكان فاضي = إخفاء/إظهار الأدوات.
class MushafScreen extends StatefulWidget {
  final int? page;
  final int? ayah;

  /// فتح من «ورد اليوم»: بيظهر شريط تقدّم الورد
  final bool wird;
  const MushafScreen({super.key, this.page, this.ayah, this.wird = false});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  final _store = AppStore.instance;
  final _khatma = KhatmaStore.instance;
  late final PageController _pc;
  late int _page;

  int? _selected;
  bool _chrome = true;
  bool _hifz = false;
  final Set<int> _revealed = {};

  final _audio = QuranPlayer.instance;
  int? _followed;
  int _repeat = 1;

  Timer? _readTimer;

  // حدود ورد اليوم وقت فتح المصحف (عشان شريط التقدّم)
  late final int _wirdFrom;
  late final int _wirdTo;

  @override
  void initState() {
    super.initState();
    _page = (widget.ayah != null ? Quran.pageOf(widget.ayah!) : (widget.page ?? _store.lastPage)).clamp(1, Quran.totalPages);
    _selected = widget.ayah;
    _wirdFrom = _khatma.nextPage;
    _wirdTo = _khatma.todayTarget;
    _pc = PageController(initialPage: _page - 1);
    _store.addListener(_refresh);
    _khatma.addListener(_refresh);
    _audio.addListener(_onAudio);
    _audio.error.addListener(_onAudioError);
    if (_store.keepAwake) WakelockPlus.enable();
    MushafPack.warmAround(_page);
    _store.savePosition(_page, ayah: widget.ayah);
    _armRead();
  }

  void _refresh() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _store.removeListener(_refresh);
    _khatma.removeListener(_refresh);
    _readTimer?.cancel();
    _audio.removeListener(_onAudio);
    _audio.error.removeListener(_onAudioError);
    _pc.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// الصفحة بتتحسب «اتقرت» لو القارئ فضل عليها ٨ ثواني (مش مجرد تقليب)
  void _armRead() {
    _readTimer?.cancel();
    final p = _page;
    _readTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _page != p) return;
      _store.logRead(p);
      _khatma.markPage(p);
    });
  }

  void _onPage(int i) {
    setState(() {
      _page = i + 1;
      _revealed.clear();
      if (_selected != null && Quran.pageOf(_selected!) != _page && _playing == null) _selected = null;
      // تقليب الصفحة بيخفي الأدوات عشان الصفحة تبان كاملة
      if (_selected == null) _chrome = false;
    });
    _store.savePosition(_page);
    MushafPack.warmAround(_page);
    _armRead();
  }

  void _toggleChrome() {
    setState(() {
      if (_selected != null) {
        _selected = null;
      } else {
        _chrome = !_chrome;
      }
    });
  }

  void _select(int g) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = _selected == g ? null : g;
      if (_hifz) _revealed.add(g);
    });
    if (_selected != null) _store.savePosition(_page, ayah: g);
  }

  void _jumpTo(int g) {
    final p = Quran.pageOf(g);
    setState(() => _selected = g);
    if (p != _page) _pc.jumpToPage(p - 1);
    _store.savePosition(p, ayah: g);
  }

  // ───── التلاوة ─────

  /// الآية اللي بتتقري (لو التلاوة شغالة)
  int? get _playing => _audio.active ? _audio.current : null;

  /// المصحف بيقلّب لوحده مع التلاوة
  void _onAudio() {
    if (!mounted) return;
    final c = _audio.current;
    if (c != null && c != _followed) {
      _followed = c;
      final p = Quran.pageOf(c);
      if (p != _page) _pc.animateToPage(p - 1, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    }
    setState(() {});
  }

  void _onAudioError() {
    final e = _audio.error.value;
    if (e == null || !mounted) return;
    _audio.error.value = null;
    toast(context, e, error: true);
  }

  /// تلاوة آية واحدة (مع التكرار)
  void _play(int g) {
    setState(() => _selected = g);
    _audio.play(g, to: g, repeat: _repeat);
  }

  void _stop() => _audio.stop();

  /// تلاوة متصلة من الآية المختارة (أو أول الصفحة) — بتكمّل للسور اللي بعدها
  void _playFrom([int? g]) {
    if (_playing != null) return _stop();
    _audio.play(g ?? _selected ?? Quran.pageRange(_page).start, repeat: _repeat);
  }

  Future<void> _copy(int g) async {
    final p = Quran.fromGlobal(g);
    final t = await Quran.ayahText(g);
    await Clipboard.setData(ClipboardData(text: '﴿$t﴾ [${Quran.surah(p.surah).name}: ${arDigits(p.ayah)}]'));
    if (mounted) toast(context, 'تم نسخ الآية');
  }

  // ───── الواجهة ─────

  @override
  Widget build(BuildContext context) {
    final pal = MushafPalette.of(_store.mushafTheme, Theme.of(context).brightness);
    final state = PageState(
      pal: pal,
      scale: _store.fontScale,
      selected: _selected,
      playing: _playing,
      hifz: _hifz,
      revealed: _revealed,
      bookmarked: _store.isBookmarked,
      onAyah: _select,
      onBlank: _toggleChrome,
    );

    // الصفحة ثابتة المقاس دايمًا، والأدوات بتظهر فوقها (مش بتزقّها) — عشان التنسيق مايتغيّرش مع كل ضغطة
    final bottomBar = _selected != null ? _ayahBar(pal, _selected!) : (_chrome ? _slider(pal) : null);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (pal.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: pal.paper,
      ),
      child: Scaffold(
        backgroundColor: pal.paper,
        body: Stack(children: [
          Positioned.fill(
            child: SafeArea(
              child: PageView.builder(
                controller: _pc,
                itemCount: Quran.totalPages,
                onPageChanged: _onPage,
                itemBuilder: (_, i) => MushafPage(page: i + 1, s: state),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_chrome,
              child: AnimatedSlide(
                offset: _chrome ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Container(
                  decoration: BoxDecoration(
                    color: pal.paper.withValues(alpha: .97),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: pal.dark ? .4 : .10), blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _topBar(pal),
                      if (widget.wird && _khatma.active) _wirdBar(pal),
                      if (_hifz)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Pill('وضع الحفظ: اضغط على الآية لتظهر', color: pal.accent, icon: Icons.visibility_off_rounded),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: bottomBar ?? const SizedBox(key: ValueKey('none'), width: double.infinity),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _topBar(MushafPalette pal) {
    final s = Quran.surahOfPage(_page);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.maybePop(context), icon: Icon(Icons.arrow_back_rounded, color: pal.accent), tooltip: 'رجوع'),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showIndexSheet(context, onPick: _jumpTo),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(children: [
                Flexible(child: Text('سورة ${s.name}', overflow: TextOverflow.ellipsis, style: AppTheme.quran(size: 20, color: pal.accent, height: 1.4))),
                Icon(Icons.expand_more_rounded, color: pal.accent),
              ]),
            ),
          ),
        ),
        IconButton(tooltip: 'بحث', color: pal.accent, onPressed: () => showSearchSheet(context, onPick: _jumpTo), icon: const Icon(Icons.search_rounded)),
        IconButton(
          tooltip: 'الإعدادات',
          color: pal.accent,
          onPressed: () => showMushafSettings(
            context,
            hifz: _hifz,
            onHifz: (v) => setState(() {
              _hifz = v;
              _revealed.clear();
            }),
            repeat: _repeat,
            onRepeat: (v) => setState(() => _repeat = v),
          ),
          icon: const Icon(Icons.text_format_rounded),
        ),
        IconButton.filled(
          tooltip: _playing != null ? 'إيقاف التلاوة' : 'استماع',
          style: IconButton.styleFrom(backgroundColor: pal.accent, foregroundColor: pal.paper),
          onPressed: () => _playFrom(),
          icon: Icon(_playing != null ? Icons.stop_rounded : Icons.headphones_rounded),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  /// شريط ورد اليوم: كم صفحة باقية، وزر «أتممت الورد» لما يوصل لآخره
  Widget _wirdBar(MushafPalette pal) {
    final k = _khatma;
    final t = Theme.of(context).textTheme;
    final total = (_wirdTo - _wirdFrom + 1).clamp(1, 604);
    final done = (k.cursor - _wirdFrom + 1).clamp(0, total);
    final finishedToday = k.todayDone || k.finished;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: pal.accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(finishedToday ? Icons.check_circle_rounded : Icons.flag_rounded, size: 20, color: pal.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              finishedToday ? 'أتممت ورد اليوم — تقبّل الله' : 'ورد اليوم: حتى صفحة ${arDigits(k.todayTarget)} · باقٍ ${pagesLabel(k.remainingToday)}',
              style: t.bodySmall?.copyWith(color: pal.ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: finishedToday ? 1 : done / total,
                minHeight: 5,
                color: pal.accent,
                backgroundColor: pal.frame.withValues(alpha: .2),
              ),
            ),
          ]),
        ),
        if (!finishedToday && _page >= k.todayTarget)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 38), backgroundColor: pal.accent, foregroundColor: pal.paper),
              onPressed: () {
                _store.logRead(_page);
                k.completeToday();
              },
              child: const Text('أتممت الورد'),
            ),
          ).animate().fadeIn().scale(begin: const Offset(.9, .9)),
      ]),
    );
  }

  Widget _slider(MushafPalette pal) {
    return Container(
      key: const ValueKey('slider'),
      decoration: BoxDecoration(
        color: pal.paper.withValues(alpha: .97),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: pal.dark ? .4 : .10), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      padding: EdgeInsets.fromLTRB(14, 0, 14, MediaQuery.paddingOf(context).bottom + 2),
      child: Row(children: [
        Text(arDigits(1), style: TextStyle(color: pal.ink, fontSize: 12)),
        Expanded(
          child: Slider(
            activeColor: pal.accent,
            inactiveColor: pal.frame.withValues(alpha: .3),
            value: _page.toDouble(),
            min: 1,
            max: Quran.totalPages.toDouble(),
            divisions: Quran.totalPages - 1,
            label: 'صفحة ${arDigits(_page)} · ${Quran.surahOfPage(_page).name}',
            onChanged: (v) => setState(() => _page = v.round()),
            onChangeEnd: (v) => _pc.jumpToPage(v.round() - 1),
          ),
        ),
        Text(arDigits(Quran.totalPages), style: TextStyle(color: pal.ink, fontSize: 12)),
      ]),
    );
  }

  Widget _ayahBar(MushafPalette pal, int g) {
    final playing = _playing == g;
    final bookmarked = _store.isBookmarked(g);
    Widget btn(IconData i, String l, VoidCallback f) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: f,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(i, color: pal.accent, size: 22),
                const SizedBox(height: 2),
                Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: pal.ink, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return Container(
      key: ValueKey('bar$g'),
      margin: EdgeInsets.fromLTRB(12, 4, 12, MediaQuery.paddingOf(context).bottom + 6),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      decoration: BoxDecoration(
        color: pal.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: pal.frame.withValues(alpha: .6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const SizedBox(width: 12),
          Expanded(child: Text(Quran.formatAyah(g), style: TextStyle(fontWeight: FontWeight.w800, color: pal.ink))),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _selected = null),
            icon: Icon(Icons.close_rounded, size: 20, color: pal.accent),
          ),
        ]),
        Row(children: [
          btn(playing ? Icons.stop_rounded : Icons.play_arrow_rounded, playing ? 'إيقاف' : 'استماع', () {
            if (playing) return _stop();
            _play(g);
          }),
          btn(Icons.menu_book_outlined, 'تفسير', () => showTafsir(context, g)),
          btn(Icons.repeat_rounded, _repeat == 1 ? 'تكرار' : 'تكرار ×${arDigits(_repeat)}', () {
            setState(() => _repeat = switch (_repeat) { 1 => 3, 3 => 5, 5 => 10, _ => 1 });
          }),
          btn(bookmarked ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, bookmarked ? 'إزالة' : 'علامة', () => _store.toggleBookmark(g)),
          btn(Icons.image_outlined, 'صورة', () => openShareAyah(context, g)),
          btn(Icons.copy_rounded, 'نسخ', () => _copy(g)),
        ]),
      ]),
    ).animate().fadeIn(duration: 180.ms).slideY(begin: .25);
  }
}
