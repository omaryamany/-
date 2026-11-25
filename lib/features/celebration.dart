import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/arabic.dart';
import '../core/khatma.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// احتفال صغير لما ورد اليوم يخلص، وأكبر لما الختمة كلها تخلص
void showCelebration(BuildContext context, KhatmaEvent e) {
  final k = KhatmaStore.instance;
  final khatma = e == KhatmaEvent.khatmaDone;
  showDialog(
    context: context,
    builder: (c) {
      final t = Theme.of(c).textTheme;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: PatternPainter(color: AppColors.gold.withValues(alpha: .10)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
                child: Icon(khatma ? Icons.auto_awesome_rounded : Icons.check_rounded, color: Colors.white, size: 50),
              )
                  .animate()
                  .scale(begin: const Offset(.4, .4), duration: 600.ms, curve: Curves.easeOutBack)
                  .then()
                  .shimmer(duration: 1200.ms, color: Colors.white54),
              const SizedBox(height: 18),
              Text(khatma ? 'مبارك! أتممت ختمة القرآن' : 'أتممت ورد اليوم', textAlign: TextAlign.center, style: t.headlineMedium),
              const SizedBox(height: 8),
              Text(
                khatma
                    ? 'تقبّل الله منك. هذه ختمتك رقم ${arDigits(k.completedCount)} في مُرتِّل.'
                    : k.finished
                        ? 'تقبّل الله منك.'
                        : 'تقبّل الله منك. ورد الغد ينتظرك — وتستطيع أن تقرأ زيادة إن شئت.',
                textAlign: TextAlign.center,
                style: t.bodyLarge,
              ),
              const SizedBox(height: 22),
              if (khatma) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final days = k.plan?.days ?? 30;
                    Navigator.pop(c);
                    await k.start(days: days);
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text('ابدأ ختمة جديدة (${daysLabel(k.plan?.days ?? 30)})'),
                ),
                const SizedBox(height: 6),
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('لاحقًا')),
              ] else
                FilledButton(onPressed: () => Navigator.pop(c), child: const Text('الحمد لله')),
            ]),
          ),
        ]),
      );
    },
  );
}
