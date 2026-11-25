import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'arabic.dart';
import 'theme.dart';

/// مكوّنات الواجهة المشتركة — هوية بصرية واحدة لكل الشاشات.

/// زخرفة مشربية: شبكة معيّنات متداخلة بدوائر صغيرة عند التقاطعات
class PatternPainter extends CustomPainter {
  final Color color;
  final double cell;
  const PatternPainter({required this.color, this.cell = 46});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final h = cell / 2;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        // معيّن كبير
        final d = Path()
          ..moveTo(x + h, y)
          ..lineTo(x + cell, y + h)
          ..lineTo(x + h, y + cell)
          ..lineTo(x, y + h)
          ..close();
        canvas.drawPath(d, p);
        // معيّن صغير جوّه
        final q = cell * .18;
        final d2 = Path()
          ..moveTo(x + h, y + h - q)
          ..lineTo(x + h + q, y + h)
          ..lineTo(x + h, y + h + q)
          ..lineTo(x + h - q, y + h)
          ..close();
        canvas.drawPath(d2, p);
        canvas.drawCircle(Offset(x, y), cell * .07, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter old) => old.color != color;
}

/// شعار «مُرتِّل»: محراب (قوس مدبّب فوق مستطيل) — مليان أو محدد
class StarPainter extends CustomPainter {
  final Color color;
  final bool fill;
  const StarPainter(this.color, {this.fill = false});

  static Path archPath(Size s) {
    final w = s.width, h = s.height;
    final left = w * .14, right = w * .86, bottom = h * .96, shoulder = h * .42, top = h * .04;
    return Path()
      ..moveTo(left, bottom)
      ..lineTo(left, shoulder)
      ..quadraticBezierTo(left, h * .16, w / 2, top)
      ..quadraticBezierTo(right, h * .16, right, shoulder)
      ..lineTo(right, bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
        archPath(s),
        Paint()
          ..color = color
          ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant StarPainter o) => o.color != color || o.fill != fill;
}

/// مسدّس بزوايا ناعمة (لأرقام السور والأجزاء)
class _HexPainter extends CustomPainter {
  final Color color;
  const _HexPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2 - 1.5;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .10));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _HexPainter o) => o.color != color;
}

/// رقم داخل نجمة (رقم السورة / الجزء)
class StarNumber extends StatelessWidget {
  final int number;
  final double size;
  final Color? color;
  const StarNumber(this.number, {super.key, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexPainter(c),
        child: Center(
          child: Text(arDigits(number), style: TextStyle(fontSize: size * .32, fontWeight: FontWeight.w700, color: c, height: 1)),
        ),
      ),
    );
  }
}

/// هيدر متدرّج بزخرفة
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 20), this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(10),
        ),
        boxShadow: [BoxShadow(color: AppColors.pine.withValues(alpha: .30), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: PatternPainter(color: Colors.white.withValues(alpha: .06)))),
            // قوس محراب فيروزي في الركن + توهّج كهرماني خفيف
            PositionedDirectional(
              end: 14,
              top: -24,
              child: SizedBox(
                width: 110,
                height: 150,
                child: CustomPaint(painter: StarPainter(AppColors.turquoise.withValues(alpha: .45))),
              ),
            ),
            PositionedDirectional(
              end: 34,
              top: 6,
              child: SizedBox(
                width: 70,
                height: 100,
                child: CustomPaint(painter: StarPainter(AppColors.gold.withValues(alpha: .35))),
              ),
            ),
            Padding(
              padding: padding,
              child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// كارت بظل ناعم
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: dark ? .25 : .4)),
        boxShadow: dark ? null : [BoxShadow(color: const Color(0xFF0F2A26).withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// حلقة تقدّم دائرية بتدرّج ذهبي
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Widget? center;
  final Color track;
  const ProgressRing({super.key, required this.value, this.size = 110, this.stroke = 10, this.center, this.track = const Color(0x33FFFFFF)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(v, stroke, track), child: Center(child: center)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color track;
  _RingPainter(this.v, this.stroke, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
        r,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (v <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * math.max(v, .015),
      false,
      Paint()
        ..shader = const SweepGradient(colors: [AppColors.turquoise, AppColors.goldLight, AppColors.gold, AppColors.turquoise], transform: GradientRotation(-math.pi / 2)).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.v != v || o.track != track;
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 11, height: 11, decoration: BoxDecoration(gradient: AppColors.tealGradient, borderRadius: BorderRadius.circular(2.5))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyView({super.key, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: .08), shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: cs.primary),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

/// دخول متتابع ناعم للعناصر
extension Entrance on Widget {
  Widget enter(int i) => animate().fadeIn(duration: 380.ms, delay: (50 * i).ms).slideY(begin: .1, end: 0, curve: Curves.easeOutCubic);
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.rose : AppColors.pineDeep));
}

Future<bool> confirm(BuildContext context, String title, {String? body, String ok = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.rose) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// منتقي رقم صفحة (١..٦٠٤) بسلايدر + معاينة اسم السورة
Future<int?> pickPage(BuildContext context, {required String title, required int initial, int min = 1, int max = 604, String Function(int)? describe}) {
  var v = initial.clamp(min, max);
  return showModalBottomSheet<int>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 18),
          Text('صفحة ${arDigits(v)}', textAlign: TextAlign.center, style: Theme.of(c).textTheme.headlineMedium),
          if (describe != null) Text(describe(v), textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodyMedium),
          Row(children: [
            IconButton(onPressed: v > min ? () => set(() => v--) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
            Expanded(
              child: Slider(
                value: v.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min > 0 ? max - min : 1,
                onChanged: (x) => set(() => v = x.round()),
              ),
            ),
            IconButton(onPressed: v < max ? () => set(() => v++) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
          ]),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => Navigator.pop(c, v), child: const Text('تم')),
        ]),
      ),
    ),
  );
}
