import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../core/arabic.dart';
import '../../core/prayer.dart';
import '../../core/prayer_calc.dart';
import '../../core/theme.dart';

/// بوصلة القبلة: القرص بيلف مع الموبايل، والكعبة على القرص في اتجاهها الصح
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  bool _noSensor = false;
  bool _aligned = false;

  @override
  void initState() {
    super.initState();
    final events = FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
    } else {
      _sub = events.listen((e) {
        if (!mounted) return;
        if (e.heading == null) {
          setState(() => _noSensor = true);
          return;
        }
        setState(() => _heading = e.heading);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ps = PrayerStore.instance;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final qibla = ps.qibla;
    final km = PrayerCalc.distanceToKaaba(ps.lat!, ps.lng!);
    final heading = _heading ?? 0;
    // الفرق بين اتجاه الموبايل واتجاه القبلة (-١٨٠..١٨٠)
    final diff = ((qibla - heading + 540) % 360) - 180;
    final aligned = _heading != null && diff.abs() < 4;
    if (aligned != _aligned) {
      _aligned = aligned;
      if (aligned) HapticFeedback.mediumImpact();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text(ps.place, style: t.titleMedium),
            Text('القبلة ${arDigits(qibla.round())}° من الشمال · ${arDigits(km.round())} كم إلى مكة', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (aligned ? AppColors.pine : cs.surfaceContainerHighest).withValues(alpha: aligned ? 1 : .7),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                _noSensor
                    ? 'لا توجد بوصلة في هذا الهاتف'
                    : _heading == null
                        ? 'جارٍ قراءة البوصلة…'
                        : aligned
                            ? 'أنت في اتجاه القبلة'
                            : (diff > 0 ? 'استدر يمينًا ${arDigits(diff.abs().round())}°' : 'استدر يسارًا ${arDigits(diff.abs().round())}°'),
                style: t.titleMedium?.copyWith(color: aligned ? Colors.white : cs.onSurface),
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(builder: (context, c) {
              final size = math.min(c.maxWidth, 320.0);
              return SizedBox(
                width: size,
                height: size,
                child: Stack(alignment: Alignment.center, children: [
                  // القرص بيلف عكس اتجاه الموبايل عشان الشمال يفضل شمال
                  Transform.rotate(
                    angle: -heading * math.pi / 180,
                    child: CustomPaint(size: Size(size, size), painter: _DialPainter(cs, qibla)),
                  ),
                  // مؤشر الموبايل الثابت (لفوق)
                  Positioned(
                    top: 0,
                    child: Icon(Icons.arrow_drop_up_rounded, size: 44, color: aligned ? AppColors.pine : AppColors.gold),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: aligned ? AppColors.pine : cs.surface,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12)],
                    ),
                    child: Icon(Icons.mosque_rounded, color: aligned ? Colors.white : AppColors.gold, size: 34),
                  ),
                ]),
              );
            }),
            const Spacer(),
            Text('امسك الهاتف أفقيًا بعيدًا عن المعادن والأجهزة. لو الاتجاه غير دقيق، حرّك الهاتف على شكل رقم ٨ لمعايرة البوصلة.',
                textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final ColorScheme cs;
  final double qibla;
  _DialPainter(this.cs, this.qibla);

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = cs.surface);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // علامات كل ١٠ درجات
    for (var a = 0; a < 360; a += 10) {
      final rad = (a - 90) * math.pi / 180;
      final major = a % 90 == 0;
      final p1 = c + Offset(math.cos(rad), math.sin(rad)) * (r - (major ? 18 : 10));
      final p2 = c + Offset(math.cos(rad), math.sin(rad)) * (r - 3);
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = major ? cs.onSurface : cs.outline
            ..strokeWidth = major ? 2.5 : 1.2);
    }
    // الاتجاهات الأربعة
    const labels = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};
    for (final e in labels.entries) {
      final rad = (e.key - 90) * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(text: e.value, style: TextStyle(fontFamily: 'Almarai', fontSize: 18, fontWeight: FontWeight.w700, color: e.key == 0 ? AppColors.rose : cs.onSurface)),
        textDirection: TextDirection.rtl,
      )..layout();
      final pos = c + Offset(math.cos(rad), math.sin(rad)) * (r - 36);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
    // خط واتجاه القبلة + الكعبة
    final qr = (qibla - 90) * math.pi / 180;
    final dir = Offset(math.cos(qr), math.sin(qr));
    canvas.drawLine(
        c + dir * 40,
        c + dir * (r - 46),
        Paint()
          ..color = AppColors.gold
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    final k = c + dir * (r - 30);
    final rect = Rect.fromCenter(center: k, width: 26, height: 26);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = const Color(0xFF1B1B1B));
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top + 6, rect.width, 4), Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant _DialPainter o) => o.qibla != qibla || o.cs != cs;
}
