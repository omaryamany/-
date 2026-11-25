import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/audio.dart';
import '../../core/player.dart';
import '../../core/quran.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../shell.dart';
import 'listen_screen.dart';

void openNowPlaying(BuildContext context) {
  if (!QuranPlayer.instance.active) return;
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => const NowPlayingScreen(),
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ));
}

String _mmss(Duration d) => '${arDigits(d.inMinutes)}:${arDigits((d.inSeconds % 60).toString().padLeft(2, '0'))}';

/// «يُتلى الآن»: اسم السورة في محراب، القارئ، نص الآية اللي بتتقري، التقدّم، والتحكم (تكرار، سرعة، مؤقت نوم، تحميل)
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final _p = QuranPlayer.instance;
  int? _shownAyah;
  Future<String>? _text;
  int _dlDone = 0, _dlTotal = 0;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _p.addListener(_onPlayer);
  }

  @override
  void dispose() {
    _p.removeListener(_onPlayer);
    super.dispose();
  }

  void _onPlayer() {
    if (!mounted) return;
    if (!_p.active) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  Future<String> _ayahText(int g) async {
    final t = await Quran.ayahText(g);
    final p = Quran.fromGlobal(g);
    if (p.ayah != 1 || p.surah == 1 || p.surah == 9) return t;
    final parts = t.split(' ');
    return parts.length > 4 && parts[0].endsWith('سْمِ') ? parts.skip(4).join(' ') : t;
  }

  Future<void> _download(int surah) async {
    setState(() {
      _downloading = true;
      _dlDone = 0;
      _dlTotal = Quran.surah(surah).ayahCount;
    });
    final ok = await AudioStore.downloadSurah(AppStore.instance.reciter, surah, (d, t) {
      if (mounted) setState(() => _dlDone = d);
    });
    if (!mounted) return;
    setState(() => _downloading = false);
    toast(context, ok ? 'تم تحميل السورة — تعمل الآن بدون إنترنت' : 'تم تحميل جزء — أكمل عند توفر الإنترنت', error: !ok);
  }

  void _sleepSheet() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('إيقاف التلاوة بعد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
          for (final (m, l) in [(15, '١٥ دقيقة'), (30, '٣٠ دقيقة'), (45, '٤٥ دقيقة'), (60, 'ساعة'), (-1, 'نهاية السورة'), (0, 'إلغاء المؤقت')])
            ListTile(
              leading: Icon(m == 0 ? Icons.timer_off_outlined : Icons.timer_outlined),
              title: Text(l),
              onTap: () {
                _p.setSleep(m);
                Navigator.pop(c);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _p.current;
    if (g == null) return const Scaffold(backgroundColor: AppColors.pineDeep);
    if (g != _shownAyah) {
      _shownAyah = g;
      _text = _ayahText(g);
    }
    final pl = _p.place;
    final s = Quran.surah(pl.surah);
    final reciter = Quran.reciter(AppStore.instance.reciter);
    final t = Theme.of(context).textTheme;
    const white70 = Colors.white70;

    return Scaffold(
      backgroundColor: AppColors.pineDeep,
      body: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B3566), AppColors.pineDeep, Color(0xFF09142A)]),
            ),
            child: CustomPaint(painter: PatternPainter(color: Colors.white.withValues(alpha: .04), cell: 44)),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // الشريط العلوي
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32)),
                Expanded(child: Text('يُتلى الآن', textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: white70))),
                IconButton(
                  tooltip: 'فتح في المصحف',
                  onPressed: () {
                    Navigator.pop(context);
                    openMushaf(context, ayah: g);
                  },
                  icon: const Icon(Icons.auto_stories_rounded, color: Colors.white),
                ),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(22, 6, 22, 12), children: [
                // اسم السورة داخل محراب
                Center(
                  child: SizedBox(
                    width: 230,
                    height: 250,
                    child: CustomPaint(
                      painter: _ArchFrame(),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 70),
                        child: Column(children: [
                          Text(s.name, style: AppTheme.quran(size: 50, color: AppColors.goldLight, height: 1.5)),
                          Text('السورة ${arDigits(s.number)} · ${arDigits(s.ayahCount)} آية · ${s.meccan ? 'مكية' : 'مدنية'}',
                              style: t.bodySmall?.copyWith(color: white70)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // القارئ
                Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.turquoise,
                    child: Text(reciter.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(reciter.name, style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text('حفص عن عاصم', style: t.bodySmall?.copyWith(color: white70)),
                    ]),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.goldLight, side: const BorderSide(color: AppColors.goldLight), minimumSize: const Size(0, 40)),
                    onPressed: () async {
                      final before = AppStore.instance.reciter;
                      await showReciterSheet(context);
                      if (AppStore.instance.reciter != before) await _p.restartFromCurrent();
                    },
                    child: const Text('تغيير القارئ'),
                  ),
                ]),
                const SizedBox(height: 16),
                // نص الآية اللي بتتقري
                Container(
                  constraints: const BoxConstraints(minHeight: 120, maxHeight: 230),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.turquoise.withValues(alpha: .45)),
                  ),
                  child: Column(children: [
                    Expanded(
                      child: FutureBuilder<String>(
                        future: _text,
                        builder: (_, snap) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: SingleChildScrollView(
                            key: ValueKey(g),
                            child: Text(
                              snap.hasData ? '${snap.data!} ﴿${arDigits(pl.ayah)}﴾' : '…',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: AppTheme.quran(size: 24, height: 2.05, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('الآية ${arDigits(pl.ayah)} من ${arDigits(pl.count)}', style: t.labelMedium?.copyWith(color: AppColors.goldLight)),
                  ]),
                ),
                const SizedBox(height: 14),
                // تقدّم السورة
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: pl.ayah / pl.count,
                    minHeight: 4,
                    color: AppColors.turquoise,
                    backgroundColor: Colors.white.withValues(alpha: .12),
                  ),
                ),
                const SizedBox(height: 6),
                // تقدّم الآية الحالية
                StreamBuilder<Duration?>(
                  stream: _p.duration,
                  builder: (_, dSnap) => StreamBuilder<Duration>(
                    stream: _p.position,
                    builder: (_, pSnap) {
                      final dur = dSnap.data ?? Duration.zero;
                      final pos = pSnap.data ?? Duration.zero;
                      final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
                      return Column(children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
                          child: Slider(
                            value: pos.inMilliseconds.clamp(0, max).toDouble(),
                            max: max,
                            activeColor: AppColors.gold,
                            inactiveColor: Colors.white24,
                            onChanged: (v) => _p.seek(Duration(milliseconds: v.round())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(children: [
                            Text(_mmss(pos), style: t.labelSmall?.copyWith(color: white70)),
                            const Spacer(),
                            Text(_mmss(dur), style: t.labelSmall?.copyWith(color: white70)),
                          ]),
                        ),
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 6),
                // أزرار التحكم
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(
                    tooltip: _p.surahLoop ? 'إلغاء تكرار السورة' : 'تكرار السورة',
                    onPressed: _p.toggleSurahLoop,
                    icon: Icon(Icons.repeat_rounded, color: _p.surahLoop ? AppColors.turquoise : white70, size: 28),
                  ),
                  IconButton(onPressed: _p.previous, tooltip: 'الآية السابقة', icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 38)),
                  GestureDetector(
                    onTap: _p.toggle,
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .4), blurRadius: 22)],
                      ),
                      child: _p.loading
                          ? const Padding(padding: EdgeInsets.all(26), child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.pineDeep))
                          : Icon(_p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.pineDeep, size: 46),
                    ),
                  ),
                  IconButton(onPressed: _p.next, tooltip: 'الآية التالية', icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 38)),
                  TextButton(
                    onPressed: () {
                      const speeds = [1.0, 1.25, 1.5, 0.75];
                      final i = speeds.indexOf(_p.speed);
                      _p.setSpeed(speeds[(i + 1) % speeds.length]);
                    },
                    child: Text('${arDigits(_p.speed.toString().replaceAll(RegExp(r'\.0$'), ''))}×',
                        style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 14),
                // أدوات إضافية
                Row(children: [
                  Expanded(
                    child: _Chip(
                      icon: Icons.replay_rounded,
                      label: _p.repeat == 1 ? 'تكرار الآية' : 'تكرار ×${arDigits(_p.repeat)}',
                      active: _p.repeat > 1,
                      onTap: () => _p.setRepeat(switch (_p.repeat) { 1 => 3, 3 => 5, 5 => 10, _ => 1 }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Chip(
                      icon: Icons.bedtime_outlined,
                      label: _p.sleepEndOfSurah
                          ? 'نهاية السورة'
                          : _p.sleepAt != null
                              ? 'بعد ${minutesLabel(_p.sleepAt!.difference(DateTime.now()).inMinutes + 1)}'
                              : 'مؤقّت النوم',
                      active: _p.sleepEndOfSurah || _p.sleepAt != null,
                      onTap: _sleepSheet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Chip(
                      icon: _downloading ? Icons.downloading_rounded : Icons.download_rounded,
                      label: _downloading ? '${arDigits(_dlDone)}/${arDigits(_dlTotal)}' : 'تحميل السورة',
                      active: _downloading,
                      onTap: _downloading ? null : () => _download(s.number),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _Chip({required this.icon, required this.label, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.turquoise.withValues(alpha: .25) : Colors.white.withValues(alpha: .06),
      shape: StadiumBorder(side: BorderSide(color: active ? AppColors.turquoise : Colors.white24)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

/// إطار محراب مزدوج حوالين اسم السورة
class _ArchFrame extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final outer = StarPainter.archPath(s);
    canvas.drawPath(outer, Paint()..color = Colors.white.withValues(alpha: .05));
    canvas.drawPath(
        outer,
        Paint()
          ..color = AppColors.turquoise.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.save();
    canvas.translate(s.width * .08, s.height * .07);
    canvas.drawPath(
        StarPainter.archPath(Size(s.width * .84, s.height * .9)),
        Paint()
          ..color = AppColors.gold.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
