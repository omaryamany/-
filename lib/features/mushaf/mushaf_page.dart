import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/mushaf_pack.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';

/// حالة العرض المشتركة بين كل الصفحات (التحديد، التلاوة، وضع الحفظ…)
class PageState {
  final MushafPalette pal;
  final double scale;
  final int? selected;
  final int? playing;
  final bool hifz;
  final Set<int> revealed;
  final bool Function(int) bookmarked;
  final ValueChanged<int> onAyah;
  final VoidCallback onBlank;
  const PageState({
    required this.pal,
    required this.scale,
    required this.selected,
    required this.playing,
    required this.hifz,
    required this.revealed,
    required this.bookmarked,
    required this.onAyah,
    required this.onBlank,
  });

  Color? highlight(int g) {
    if (playing == g) return AppColors.pineLight.withValues(alpha: .28);
    if (selected == g) return pal.accent.withValues(alpha: .16);
    return null;
  }

  bool hidden(int g) => hifz && !revealed.contains(g) && playing != g;
}

/// صفحة مصحف كاملة: إطار مزخرف + ترويسة (السورة والجزء) + ١٥ سطر + رقم الصفحة
class MushafPage extends StatelessWidget {
  final int page;
  final PageState s;
  const MushafPage({super.key, required this.page, required this.s});

  @override
  Widget build(BuildContext context) {
    final pal = s.pal;
    final head = TextStyle(fontFamily: 'AmiriQuran', fontSize: 14, color: pal.number, height: 1.4);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: s.onBlank,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: CustomPaint(
          painter: _FramePainter(pal),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: [
                  Expanded(child: Text('سورة ${Quran.surahOfPage(page).name}', style: head)),
                  _hizbLabel(page, head),
                  Expanded(child: Text('الجزء ${arDigits(Quran.juzOfPage(page))}', textAlign: TextAlign.end, style: head)),
                ]),
              ),
              Divider(height: 6, color: pal.frame.withValues(alpha: .35)),
              Expanded(child: _MadinahBody(page: page, s: s)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                decoration: BoxDecoration(border: Border.all(color: pal.frame.withValues(alpha: .7)), borderRadius: BorderRadius.circular(99)),
                child: Text(arDigits(page), style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// وسط الترويسة: ربع الحزب لو بيبدأ في الصفحة (بالذهبي)، وإلا رقم الحزب — وعلامة السجدة لو فيه
Widget _hizbLabel(int page, TextStyle head) {
  final q = Hizb.quarterStartingOn(page);
  final label = q != null ? Hizb.label(q) : 'الحزب ${arDigits(Hizb.quarterOf(Quran.pageRange(page).start) ~/ 4 + 1)}';
  final sajda = Hizb.pageHasSajda(page);
  return Row(mainAxisSize: MainAxisSize.min, children: [
    if (q != null) Text('۞ ', style: head.copyWith(color: AppColors.gold)),
    Text(label, style: q != null ? head.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700) : head),
    if (sajda) Text('  ۩ سجدة', style: head.copyWith(color: AppColors.rose)),
  ]);
}

class _MadinahBody extends StatefulWidget {
  final int page;
  final PageState s;
  const _MadinahBody({required this.page, required this.s});
  @override
  State<_MadinahBody> createState() => _MadinahBodyState();
}

class _MadinahBodyState extends State<_MadinahBody> {
  late final Future<(List<MadinahLine>, bool)> _f = MushafPack.prepare(widget.page);

  /// العرض الطبيعي لكل سطر عند حجم خط ١٠٠ (بيتحسب مرة واحدة للصفحة)
  Map<int, double>? _ref;

  Map<int, double> _measure(List<MadinahLine> lines) {
    return _ref ??= () {
      final style = TextStyle(fontFamily: MushafPack.family(widget.page), fontSize: 100, height: 1);
      final out = <int, double>{};
      for (final l in lines) {
        if (!l.isText) continue;
        final tp = TextPainter(text: TextSpan(text: l.words.join(), style: style), textDirection: TextDirection.rtl)..layout();
        out[l.n] = tp.width;
        tp.dispose();
      }
      return out;
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<MadinahLine>, bool)>(
      future: _f,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final (lines, ok) = snap.data!;
        final s = widget.s;
        // التكبير = عرض النص متصلًا بخط أكبر (رسم الصفحة الأصلي مقاسه ثابت)
        if (!ok || lines.isEmpty || s.scale > 1) return _PlainBody(page: widget.page, s: s);
        final pal = s.pal;
        final opening = widget.page <= 2;
        final ref = _measure(lines);

        // الأسطر القصيرة (آخر السور القصيرة) بتتوسّط بدل ما تتمطّ — زي المطبوع
        final short = <int>{};
        if (!opening && ref.length >= 3) {
          final sorted = ref.values.toList()..sort();
          final median = sorted[sorted.length ~/ 2];
          for (final e in ref.entries) {
            if (e.value < median * .72) short.add(e.key);
          }
        }
        const gap = .24; // مسافة بين كلمات السطر المتوسّط (نسبة من حجم الخط)

        return LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          // حجم الخط على قد ارتفاع الصفحة، ومن غير ما أي سطر يخرج برّه العرض
          var fs = (c.maxHeight - 6) / (15 * 1.72) * (opening ? 1.35 : 1);
          for (final l in lines) {
            final r = ref[l.n];
            if (r == null || r <= 0) continue;
            final centered = opening || short.contains(l.n);
            final perUnit = r / 100 + (centered ? gap * l.words.length : 0);
            fs = math.min(fs, w * .985 / perUnit);
          }

          Widget lineOf(MadinahLine l) {
            if (l.k == 'h') return _SurahBanner(surah: l.surah, pal: pal, fs: fs);
            if (l.k == 'b') {
              return Center(
                child: Text(String.fromCharCodes(MushafPack.basmala),
                    textDirection: TextDirection.rtl, style: TextStyle(fontFamily: MushafPack.family(1), fontSize: fs * 1.1, color: pal.ink, height: 1.55)),
              );
            }
            final centered = opening || short.contains(l.n);
            return Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < l.words.length; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: centered ? fs * gap / 2 : 0),
                    child: _word(l.words[i], l.ayat[i], l.ends[i] == 1, fs),
                  ),
              ],
            );
          }

          final col = Column(
            mainAxisAlignment: opening ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final l in lines) lineOf(l)],
          );
          final needed = 15 * fs * 1.72;
          return needed > c.maxHeight + 1 ? SingleChildScrollView(child: SizedBox(height: needed, child: col)) : col;
        });
      },
    );
  }

  Widget _word(String glyphs, int g, bool end, double fs) {
    final s = widget.s;
    final pal = s.pal;
    var bg = s.highlight(g);
    if (end && s.bookmarked(g)) bg = AppColors.rose.withValues(alpha: .22);
    final hidden = !end && s.hidden(g);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => s.onAyah(g),
      onLongPress: () => s.onAyah(g),
      child: Container(
        decoration: BoxDecoration(color: hidden ? pal.frame.withValues(alpha: .18) : bg, borderRadius: BorderRadius.circular(fs * .22)),
        child: Text(
          glyphs,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: MushafPack.family(widget.page),
            fontSize: fs,
            height: 1.6,
            color: hidden ? Colors.transparent : (end ? pal.number : pal.ink),
          ),
        ),
      ),
    );
  }
}

/// عنوان السورة داخل إطار مزخرف
class _SurahBanner extends StatelessWidget {
  final int surah;
  final MushafPalette pal;
  final double fs;
  const _SurahBanner({required this.surah, required this.pal, required this.fs});

  @override
  Widget build(BuildContext context) {
    final s = Quran.surah(surah);
    return Container(
      height: fs * 1.6,
      margin: EdgeInsets.symmetric(vertical: fs * .04),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [pal.frame.withValues(alpha: .10), pal.frame.withValues(alpha: .30), pal.frame.withValues(alpha: .10)]),
        borderRadius: BorderRadius.circular(fs * .5),
        border: Border.all(color: pal.frame.withValues(alpha: .85), width: 1.2),
      ),
      padding: EdgeInsets.symmetric(horizontal: fs * .5),
      child: Row(children: [
        Text(s.meccan ? 'مكية' : 'مدنية', style: TextStyle(fontSize: fs * .42, color: pal.number)),
        Expanded(
          child: Text('سورة ${s.name}', textAlign: TextAlign.center, style: AppTheme.quran(size: fs * .95, color: pal.accent, height: 1.2)),
        ),
        Text('آياتها ${arDigits(s.ayahCount)}', style: TextStyle(fontSize: fs * .42, color: pal.number)),
      ]),
    );
  }
}

/// عرض احتياطي بخط أميري (لو خطوط الصفحات مش موجودة في البناء)
class _PlainBody extends StatefulWidget {
  final int page;
  final PageState s;
  const _PlainBody({required this.page, required this.s});
  @override
  State<_PlainBody> createState() => _PlainBodyState();
}

class _PlainBodyState extends State<_PlainBody> {
  late final Future<List<PageAyah>> _f = Quran.loadPage(widget.page);
  final _taps = <int, TapGestureRecognizer>{};

  @override
  void dispose() {
    for (final t in _taps.values) {
      t.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(int g) => _taps.putIfAbsent(g, () => TapGestureRecognizer()..onTap = () => widget.s.onAyah(g));

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final pal = s.pal;
    final size = 20.0 * s.scale;
    return FutureBuilder<List<PageAyah>>(
      future: _f,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final blocks = <Widget>[];
        final spans = <InlineSpan>[];
        void flush() {
          if (spans.isEmpty) return;
          blocks.add(Text.rich(TextSpan(children: List.of(spans)), textAlign: TextAlign.justify, textDirection: TextDirection.rtl));
          spans.clear();
        }

        for (final a in snap.data!) {
          if (a.ayah == 1) {
            flush();
            blocks.add(Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _SurahBanner(surah: a.surah, pal: pal, fs: 22)));
            if (a.surah != 1 && a.surah != 9) {
              blocks.add(Text(Quran.basmala, textAlign: TextAlign.center, style: AppTheme.quran(size: size, color: pal.ink)));
            }
          }
          final g = a.global;
          final hidden = s.hidden(g);
          spans.add(TextSpan(
            text: '${a.text} ',
            recognizer: _tap(g),
            style: AppTheme.quran(size: size, color: hidden ? Colors.transparent : pal.ink).copyWith(
              backgroundColor: hidden ? pal.frame.withValues(alpha: .16) : s.highlight(g),
            ),
          ));
          spans.add(TextSpan(text: '﴿${arDigits(a.ayah)}﴾ ', style: AppTheme.quran(size: size * .8, color: pal.number)));
        }
        flush();
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks),
        );
      },
    );
  }
}

/// إطار الصفحة: خطين ذهبي + زخارف الأركان
class _FramePainter extends CustomPainter {
  final MushafPalette pal;
  _FramePainter(this.pal);

  @override
  void paint(Canvas canvas, Size s) {
    final outer = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(14));
    canvas.drawRRect(outer, Paint()..color = pal.paper);
    final gold = Paint()
      ..color = pal.frame
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(outer.deflate(1.5), gold..strokeWidth = 2);
    canvas.drawRRect(outer.deflate(5.5), gold..strokeWidth = .8);
    for (final c in [const Offset(13, 13), Offset(s.width - 13, 13), Offset(13, s.height - 13), Offset(s.width - 13, s.height - 13)]) {
      final path = Path();
      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final rr = i.isEven ? 8.0 : 3.5;
        final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = pal.frame.withValues(alpha: .85));
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter o) => o.pal != pal;
}
