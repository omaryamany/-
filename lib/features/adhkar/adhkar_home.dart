import 'package:flutter/material.dart';

import '../../core/adhkar_data.dart';
import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'adhkar_screen.dart';

/// ألوان وأيقونة كل قسم أذكار
class _Look {
  final IconData icon;
  final List<Color> colors;
  final String hint;
  const _Look(this.icon, this.colors, this.hint);
}

const _looks = <AdhkarKind, _Look>{
  AdhkarKind.morning: _Look(Icons.wb_sunny_rounded, [Color(0xFFF2B544), Color(0xFFD9772B)], 'بعد الفجر حتى الضحى'),
  AdhkarKind.evening: _Look(Icons.nights_stay_rounded, [Color(0xFF4A4FA3), Color(0xFF22265E)], 'بعد العصر حتى المغرب'),
  AdhkarKind.afterPrayer: _Look(Icons.mosque_rounded, [Color(0xFF2A9D9A), Color(0xFF155E5C)], 'بعد السلام من الصلاة'),
  AdhkarKind.sleep: _Look(Icons.bedtime_rounded, [Color(0xFF6B4A8F), Color(0xFF30204A)], 'قبل النوم'),
  AdhkarKind.waking: _Look(Icons.wb_twilight_rounded, [Color(0xFF52A7DB), Color(0xFF235E9E)], 'عند الاستيقاظ'),
  AdhkarKind.mosque: _Look(Icons.account_balance_rounded, [Color(0xFF2B4C86), Color(0xFF0F1F3D)], 'الدخول والخروج وبعد الأذان'),
  AdhkarKind.quranDuas: _Look(Icons.menu_book_rounded, [Color(0xFFC9733F), Color(0xFF85391A)], 'ربنا آتنا…'),
  AdhkarKind.propheticDuas: _Look(Icons.volunteer_activism_rounded, [Color(0xFF3E9471), Color(0xFF1C5440)], 'من السنة النبوية'),
};

/// تبويب الأذكار: أقسام على شكل محاريب ملوّنة + تقدّم النهارده في كل قسم
class AdhkarHome extends StatefulWidget {
  const AdhkarHome({super.key});
  @override
  State<AdhkarHome> createState() => _AdhkarHomeState();
}

class _AdhkarHomeState extends State<AdhkarHome> {
  Future<void> _open(AdhkarKind k) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdhkarScreen(kind: k)));
    if (mounted) setState(() {}); // تحديث التقدّم بعد الرجوع
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = DateTime.now().hour;
    final suggested = h >= 4 && h < 12 ? AdhkarKind.morning : (h >= 15 && h < 21 ? AdhkarKind.evening : (h >= 21 || h < 4 ? AdhkarKind.sleep : AdhkarKind.afterPrayer));
    final kinds = AdhkarKind.values;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الأذكار', style: t.headlineMedium),
              const SizedBox(height: 4),
              Text('﴿أَلَا بِذِكْرِ ٱللَّهِ تَطْمَئِنُّ ٱلْقُلُوبُ﴾', style: AppTheme.quran(size: 18, height: 1.8, color: AppColors.turquoise)),
              const SizedBox(height: 12),
              _Suggested(kind: suggested, onTap: () => _open(suggested)),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .78),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ArchTile(kind: kinds[i], onTap: () => _open(kinds[i])).enter(i),
              childCount: kinds.length,
            ),
          ),
        ),
      ]),
    );
  }
}

class _Suggested extends StatelessWidget {
  final AdhkarKind kind;
  final VoidCallback onTap;
  const _Suggested({required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final look = _looks[kind]!;
    final (done, total) = adhkarProgress(kind);
    final t = Theme.of(context).textTheme;
    return HeroCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: look.colors)),
          child: Icon(look.icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مقترح الآن', style: t.bodySmall?.copyWith(color: AppColors.goldLight)),
            Text(adhkarTitle(kind), style: t.titleLarge?.copyWith(color: Colors.white)),
            Text(done == total ? 'أتممتها اليوم — تقبّل الله' : '${arDigits(done)} من ${arDigits(total)} اليوم',
                style: t.bodySmall?.copyWith(color: Colors.white70)),
          ]),
        ),
        const Icon(Icons.chevron_left_rounded, color: Colors.white),
      ]),
    );
  }
}

/// قسم على شكل محراب: قوس فوق، أيقونة في دائرة، الاسم، وشريط تقدّم النهارده
class _ArchTile extends StatelessWidget {
  final AdhkarKind kind;
  final VoidCallback onTap;
  const _ArchTile({required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final look = _looks[kind]!;
    final (done, total) = adhkarProgress(kind);
    return ClipPath(
      clipper: const _ArchClipper(),
      child: Material(
        child: Ink(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: look.colors)),
          child: InkWell(
            onTap: onTap,
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: PatternPainter(color: Colors.white.withValues(alpha: .08), cell: 34))),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 34, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .16),
                        border: Border.all(color: Colors.white.withValues(alpha: .35)),
                      ),
                      child: Icon(look.icon, color: Colors.white, size: 32),
                    ),
                  ),
                  const Spacer(),
                  Text(adhkarTitle(kind),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(look.hint, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 5,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: .2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${arDigits(done)} / ${arDigits(total)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// قصّ على شكل محراب (قوس مدبّب من فوق وزوايا ناعمة تحت)
class _ArchClipper extends CustomClipper<Path> {
  const _ArchClipper();

  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height, r = 18.0, shoulder = s.width * .42;
    return Path()
      ..moveTo(0, h - r)
      ..lineTo(0, shoulder)
      ..quadraticBezierTo(0, shoulder * .25, w / 2, 0)
      ..quadraticBezierTo(w, shoulder * .25, w, shoulder)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
