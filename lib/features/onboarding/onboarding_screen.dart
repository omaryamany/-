import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../shell.dart';

/// أول فتحة: ٣ شاشات تعريفية قصيرة
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  static const _slides = [
    (Icons.menu_book_rounded, 'مصحف المدينة كما تعرفه', '٦٠٤ صفحات بنفس رسم وتقسيم مصحف مجمع الملك فهد، تعمل كلها بدون إنترنت.'),
    (Icons.flag_rounded, 'ختمتك يومًا بيوم', 'اختر مدة الختمة، ونقسّم لك المصحف وِردًا يوميًا ونتابع تقدمك مع تذكير في الوقت الذي يناسبك.'),
    (Icons.mosque_rounded, 'الصلاة والأذكار', 'مواقيت الصلاة والأذان، واتجاه القبلة، وأذكار الصباح والمساء، والتفسير الميسّر لكل آية.'),
    (Icons.volunteer_activism_rounded, 'مجاني لوجه الله', 'بلا إعلانات ولا حسابات ولا جمع بيانات. كل شيء يبقى على جهازك.'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish({bool khatma = false}) async {
    // الشاشة الرئيسية بتفتح إعداد الختمة أول ما تتبني لو المستخدم اختارها
    Shell.openKhatmaSetup = khatma;
    await AppStore.instance.setOnboarded();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: PatternPainter(color: Colors.white.withValues(alpha: .05), cell: 54))),
          SafeArea(
            child: Column(children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: last ? null : () => _finish(),
                  child: Text(last ? '' : 'تخطي', style: const TextStyle(color: Colors.white70)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) {
                    final (icon, title, body) = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CustomPaint(
                            painter: StarPainter(AppColors.gold.withValues(alpha: .9), fill: true),
                            child: Center(child: Icon(icon, size: 62, color: Colors.white)),
                          ),
                        ).animate(key: ValueKey(i)).scale(begin: const Offset(.6, .6), duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
                        const SizedBox(height: 36),
                        Text(title, textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(color: Colors.white))
                            .animate(key: ValueKey('t$i'))
                            .fadeIn(delay: 150.ms)
                            .slideY(begin: .2),
                        const SizedBox(height: 12),
                        Text(body, textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: .82)))
                            .animate(key: ValueKey('b$i'))
                            .fadeIn(delay: 250.ms),
                      ]),
                    );
                  },
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var d = 0; d < _slides.length; d++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: d == _i ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: d == _i ? AppColors.gold : Colors.white38, borderRadius: BorderRadius.circular(9)),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: last
                    ? Column(children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink),
                            onPressed: () => _finish(khatma: true),
                            icon: const Icon(Icons.flag_rounded),
                            label: const Text('ابدأ ختمة'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _finish(),
                          child: const Text('تصفّح المصحف أولًا', style: TextStyle(color: Colors.white)),
                        ),
                      ])
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.pineDeep),
                          onPressed: () => _pc.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
                          child: const Text('التالي'),
                        ),
                      ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
