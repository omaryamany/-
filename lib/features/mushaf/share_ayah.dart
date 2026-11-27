import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// محتوى بطاقة المشاركة: آية، ذكر، دعاء، حديث، اسم من الأسماء الحسنى…
class ShareContent {
  /// سطر صغير فوق النص (مثلًا: «قال الله تعالى»، «ذِكر»، «دعاء»)
  final String header;
  final String text;

  /// المصدر تحت النص (مثلًا: «سورة البقرة · الآية ٢٥٥»، «رواه مسلم»)
  final String source;

  /// آية من القرآن: بتتحط بين ﴿ ﴾
  final bool quran;

  /// عنوان كبير اختياري (اسم من الأسماء الحسنى مثلًا) — النص بيبقى شرحه
  final String? title;

  /// النص اللي بيتبعت مع الصورة
  final String caption;
  const ShareContent({required this.header, required this.text, required this.source, this.quran = false, this.title, String? caption})
      : caption = caption ?? '';
}

void openShareCard(BuildContext context, ShareContent c) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShareCardScreen(content: c)));
}

/// مشاركة آية من المصحف كصورة
Future<void> openShareAyah(BuildContext context, int ayah) async {
  final p = Quran.fromGlobal(ayah);
  var t = await Quran.ayahText(ayah);
  if (p.ayah == 1 && p.surah != 1 && p.surah != 9) {
    final parts = t.split(' ');
    if (parts.length > 4 && parts[0].endsWith('سْمِ')) t = parts.skip(4).join(' ');
  }
  final src = 'سورة ${Quran.surah(p.surah).name} · الآية ${arDigits(p.ayah)}';
  if (!context.mounted) return;
  openShareCard(
    context,
    ShareContent(header: 'قال الله تعالى', text: t, source: src, quran: true, caption: '﴿$t﴾ [$src]'),
  );
}

class _Style {
  final String name;
  final Gradient bg;
  final Color ink, accent, sub, pattern;
  const _Style(this.name, this.bg, this.ink, this.accent, this.sub, this.pattern);
}

LinearGradient _g(List<int> c) => LinearGradient(colors: [for (final x in c) Color(x)], begin: Alignment.topRight, end: Alignment.bottomLeft);

final _styles = <_Style>[
  _Style('كحلي', _g([0xFF132852, 0xFF1E3A6E, 0xFF235C86]), Colors.white, const Color(0xFFF5D394), const Color(0xB3FFFFFF), const Color(0x10FFFFFF)),
  _Style('مصحف', _g([0xFFFDF8EC, 0xFFF3EAD3]), const Color(0xFF1B1A17), const Color(0xFF2E7D57), const Color(0xFF6B5E45), const Color(0x142E7D57)),
  _Style('ليلي', _g([0xFF0E1628, 0xFF05080F]), const Color(0xFFEDE6D3), const Color(0xFFE2A13B), const Color(0x99EDE6D3), const Color(0x0FE2A13B)),
  _Style('فيروزي', _g([0xFF2A9D9A, 0xFF155E5C]), Colors.white, const Color(0xFFFFE9B8), const Color(0xCCFFFFFF), const Color(0x12FFFFFF)),
  _Style('غروب', _g([0xFFE08A1F, 0xFFB4532A, 0xFF6E2A2A]), Colors.white, const Color(0xFFFFF0C8), const Color(0xCCFFFFFF), const Color(0x12FFFFFF)),
  _Style('بنفسجي', _g([0xFF5B4FA8, 0xFF2B2563]), Colors.white, const Color(0xFFF5D394), const Color(0xB3FFFFFF), const Color(0x10FFFFFF)),
];

/// شاشة تصميم صورة المشاركة: ٦ ألوان، ومقاسين (منشور مربع، وحالة واتساب طولية)
class ShareCardScreen extends StatefulWidget {
  final ShareContent content;
  const ShareCardScreen({super.key, required this.content});
  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _key = GlobalKey();
  static int _lastStyle = 0;
  int _style = _lastStyle;
  late bool _story = widget.content.text.length > 420;
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // البطاقة بعرض ٣٦٠ → صورة بعرض ١٠٨٠ بكسل
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${(await getTemporaryDirectory()).path}/murattil_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      final c = widget.content;
      await Share.shareXFiles([XFile(file.path)], text: c.caption.isNotEmpty ? c.caption : '${c.text}\n— ${c.source}');
    } catch (e) {
      if (mounted) toast(context, 'تعذّرت المشاركة', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _styles[_style];
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('صورة للمشاركة')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _key,
                    child: _Card(content: widget.content, style: st, story: _story),
                  ),
                ),
              ),
            ),
          ),
          // الألوان
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: _styles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => Semantics(
                button: true,
                selected: i == _style,
                label: _styles[i].name,
                child: GestureDetector(
                  onTap: () => setState(() => _style = _lastStyle = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: _styles[i].bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: i == _style ? AppColors.turquoise : Colors.black12, width: i == _style ? 3 : 1),
                    ),
                    child: Center(child: Icon(Icons.format_quote_rounded, size: 20, color: _styles[i].accent)),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('منشور مربع'), icon: Icon(Icons.crop_square_rounded)),
                ButtonSegment(value: true, label: Text('حالة واتساب'), icon: Icon(Icons.crop_portrait_rounded)),
              ],
              selected: {_story},
              onSelectionChanged: (s) => setState(() => _story = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.share_rounded),
                label: Text('مشاركة الصورة', style: t.titleMedium?.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// البطاقة للعرض من برّه الشاشة (اختبارات التصميم)
class ShareCardView extends StatelessWidget {
  final ShareContent content;
  final int style;
  final bool story;
  const ShareCardView({super.key, required this.content, this.style = 0, this.story = false});
  static int get styleCount => _styles.length;
  @override
  Widget build(BuildContext context) => _Card(content: content, style: _styles[style], story: story);
}

/// البطاقة نفسها: عرض ثابت ٣٦٠ (مربع ٣٦٠×٣٦٠ أو حالة ٣٦٠×٦٤٠)، والنص بيصغر لوحده لحد ما يدخل
class _Card extends StatelessWidget {
  final ShareContent content;
  final _Style style;
  final bool story;
  const _Card({required this.content, required this.style, required this.story});

  @override
  Widget build(BuildContext context) {
    const w = 360.0;
    final h = story ? 640.0 : 360.0;
    final st = style;
    final body = content.quran ? '﴿ ${content.text} ﴾' : content.text;
    return MediaQuery.withNoTextScaling(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(gradient: st.bg),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: PatternPainter(color: st.pattern, cell: 38))),
            Positioned.fill(child: CustomPaint(painter: _FramePainter(st.accent))),
            Padding(
              padding: EdgeInsets.fromLTRB(30, story ? 54 : 26, 30, story ? 40 : 20),
              child: Column(children: [
                // رأس البطاقة: محراب صغير وفيه السطر التعريفي
                SizedBox(
                  width: 34,
                  height: 30,
                  child: CustomPaint(painter: _ArchPainter(st.accent)),
                ),
                const SizedBox(height: 4),
                Text(content.header, style: TextStyle(fontFamily: AppTheme.font, fontSize: story ? 14 : 12, fontWeight: FontWeight.w700, color: st.accent, height: 1.3)),
                _Ornament(color: st.accent),
                if (content.title != null) ...[
                  SizedBox(height: story ? 18 : 6),
                  Text(content.title!, textAlign: TextAlign.center, style: AppTheme.quran(size: story ? 56 : 40, height: 1.5, color: st.ink)),
                ],
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final size = _fit(body, c.maxWidth, c.maxHeight, max: content.title != null ? 22 : (story ? 34 : 30), min: 9);
                    return Center(
                      child: Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AppTheme.quran(size: size, height: _lh(size), color: st.ink),
                      ),
                    );
                  }),
                ),
                if (content.source.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(content.source, textAlign: TextAlign.center, style: TextStyle(fontFamily: AppTheme.font, fontSize: story ? 14 : 12, fontWeight: FontWeight.w700, color: st.accent)),
                ],
                SizedBox(height: story ? 22 : 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 18, height: 1, color: st.sub),
                  const SizedBox(width: 6),
                  Text('مُرتِّل', style: TextStyle(fontFamily: AppTheme.font, fontSize: 11, fontWeight: FontWeight.w800, color: st.sub)),
                  const SizedBox(width: 4),
                  Text('· مصحف وختمة وأذكار', style: TextStyle(fontFamily: AppTheme.font, fontSize: 9.5, color: st.sub)),
                  const SizedBox(width: 6),
                  Container(width: 18, height: 1, color: st.sub),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static double _lh(double size) => size >= 20 ? 2.0 : 1.85;

  /// أكبر حجم خط يخلّي النص يدخل في المساحة
  static double _fit(String text, double w, double h, {required double max, required double min}) {
    var size = max;
    while (size > min) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: AppTheme.quran(size: size, height: _lh(size))),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: w);
      if (tp.height <= h) return size;
      size -= size > 16 ? 1 : .5;
    }
    return min;
  }
}

/// إطار مزدوج بزوايا مزخرفة
class _FramePainter extends CustomPainter {
  final Color c;
  _FramePainter(this.c);

  @override
  void paint(Canvas canvas, Size s) {
    final outer = Rect.fromLTWH(12, 12, s.width - 24, s.height - 24);
    final inner = outer.deflate(5);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = c.withValues(alpha: .55)
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(outer, const Radius.circular(14)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(inner, const Radius.circular(10)), p..strokeWidth = .6..color = c.withValues(alpha: .35));
    // معيّنات في الزوايا ونصّ الأضلاع
    final fill = Paint()..color = c.withValues(alpha: .8);
    void diamond(Offset o, double r) {
      canvas.drawPath(
          Path()
            ..moveTo(o.dx, o.dy - r)
            ..lineTo(o.dx + r, o.dy)
            ..lineTo(o.dx, o.dy + r)
            ..lineTo(o.dx - r, o.dy)
            ..close(),
          fill);
    }

    for (final o in [outer.topLeft, outer.topRight, outer.bottomLeft, outer.bottomRight]) {
      diamond(o + Offset(o.dx < s.width / 2 ? 4 : -4, o.dy < s.height / 2 ? 4 : -4), 4.5);
    }
    diamond(Offset(s.width / 2, outer.bottom), 4);
    diamond(Offset(outer.left, s.height / 2), 3);
    diamond(Offset(outer.right, s.height / 2), 3);
  }

  @override
  bool shouldRepaint(covariant _FramePainter o) => o.c != c;
}

class _ArchPainter extends CustomPainter {
  final Color c;
  _ArchPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(StarPainter.archPath(s), Paint()..color = c.withValues(alpha: .9));
    canvas.drawCircle(Offset(s.width / 2, s.height * .62), s.width * .1, Paint()..color = Colors.white.withValues(alpha: .85));
  }

  @override
  bool shouldRepaint(covariant _ArchPainter o) => o.c != c;
}

/// فاصل زخرفي صغير تحت السطر التعريفي
class _Ornament extends StatelessWidget {
  final Color color;
  const _Ornament({required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: 120,
        height: 8,
        child: CustomPaint(painter: _OrnPainter(color)),
      ),
    );
  }
}

class _OrnPainter extends CustomPainter {
  final Color c;
  _OrnPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final y = s.height / 2;
    final line = Paint()
      ..color = c.withValues(alpha: .6)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(s.width / 2 - 10, y), line);
    canvas.drawLine(Offset(s.width / 2 + 10, y), Offset(s.width, y), line);
    final r = s.height / 2;
    final m = Offset(s.width / 2, y);
    canvas.save();
    canvas.translate(m.dx, m.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.3, height: r * 1.3), Paint()..color = c);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrnPainter o) => o.c != c;
}
