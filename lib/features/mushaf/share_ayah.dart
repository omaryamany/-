import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

void openShareAyah(BuildContext context, int ayah) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShareAyahScreen(ayah: ayah)));
}

class _Style {
  final String name;
  final Gradient bg;
  final Color ink, accent, sub;
  final Color pattern;
  const _Style(this.name, this.bg, this.ink, this.accent, this.sub, this.pattern);
}

const _styles = [
  _Style('أخضر', AppColors.heroGradient, Colors.white, AppColors.goldLight, Color(0xCCFFFFFF), Color(0x12FFFFFF)),
  _Style('ورقي', LinearGradient(colors: [Color(0xFFFCF8EE), Color(0xFFF1E6CC)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      Color(0xFF221C12), AppColors.pineDeep, Color(0xFF7A6A4A), Color(0x14A9842F)),
  _Style('ليلي', LinearGradient(colors: [Color(0xFF101916), Color(0xFF070D0B)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      Color(0xFFE6DFCC), AppColors.gold, Color(0xAAE6DFCC), Color(0x10C9A54C)),
];

/// مشاركة الآية كصورة مزخرفة (للواتساب والفيسبوك والحالة)
class ShareAyahScreen extends StatefulWidget {
  final int ayah;
  const ShareAyahScreen({super.key, required this.ayah});
  @override
  State<ShareAyahScreen> createState() => _ShareAyahScreenState();
}

class _ShareAyahScreenState extends State<ShareAyahScreen> {
  final _key = GlobalKey();
  int _style = 0;
  bool _busy = false;
  late final Future<String> _text = Quran.ayahText(widget.ayah).then(_stripBasmala);

  String _stripBasmala(String t) {
    final p = Quran.fromGlobal(widget.ayah);
    if (p.ayah != 1 || p.surah == 1 || p.surah == 9) return t;
    final parts = t.split(' ');
    return parts.length > 4 && parts[0].endsWith('سْمِ') ? parts.skip(4).join(' ') : t;
  }

  Future<void> _share(String text) async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${(await getTemporaryDirectory()).path}/ayah_${widget.ayah}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      final p = Quran.fromGlobal(widget.ayah);
      await Share.shareXFiles([XFile(file.path)], text: '﴿$text﴾ [${Quran.surah(p.surah).name}: ${arDigits(p.ayah)}]');
    } catch (e) {
      if (mounted) toast(context, 'تعذّرت المشاركة', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Quran.fromGlobal(widget.ayah);
    final st = _styles[_style];
    return Scaffold(
      appBar: AppBar(title: const Text('مشاركة الآية')),
      body: FutureBuilder<String>(
        future: _text,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final text = snap.data!;
          final size = text.length < 80 ? 30.0 : text.length < 180 ? 25.0 : text.length < 350 ? 21.0 : text.length < 600 ? 18.0 : 15.0;
          return ListView(padding: const EdgeInsets.all(20), children: [
            Center(
              child: RepaintBoundary(
                key: _key,
                child: Container(
                  width: 340,
                  constraints: const BoxConstraints(minHeight: 340),
                  decoration: BoxDecoration(gradient: st.bg, borderRadius: BorderRadius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: PatternPainter(color: st.pattern, cell: 40))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(26, 26, 26, 18),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 30, height: 30, child: CustomPaint(painter: StarPainter(st.accent, fill: true))),
                        const SizedBox(height: 16),
                        Text('﴿ $text ﴾', textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: AppTheme.quran(size: size, height: 2.1, color: st.ink)),
                        const SizedBox(height: 14),
                        Text('سورة ${Quran.surah(p.surah).name} · الآية ${arDigits(p.ayah)}', style: AppTheme.quran(size: 16, height: 1.6, color: st.accent)),
                        const SizedBox(height: 18),
                        Container(height: 1, width: 60, color: st.accent.withValues(alpha: .5)),
                        const SizedBox(height: 8),
                        Text('مُرتِّل — مصحف وختمة', style: TextStyle(fontSize: 11, color: st.sub)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SegmentedButton<int>(
                segments: [for (var i = 0; i < _styles.length; i++) ButtonSegment(value: i, label: Text(_styles[i].name))],
                selected: {_style},
                onSelectionChanged: (s) => setState(() => _style = s.first),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _share(text),
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.share_rounded),
              label: const Text('مشاركة الصورة'),
            ),
          ]);
        },
      ),
    );
  }
}
