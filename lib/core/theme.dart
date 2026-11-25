import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// هوية «مُرتِّل» (الإصدار ١٫٣): أزرق كوبالتي عميق + فيروزي + كهرماني دافئ + رملي فاتح —
/// مستوحاة من بلاط إزنيق والمشربيات، ومختلفة عن الأخضر والذهبي المنتشر في تطبيقات المصحف.
/// (أسماء الثوابت القديمة متسابة زي ما هي عشان باقي الكود، بس قيمها اتغيرت)
class AppColors {
  /// اللون الأساسي — أزرق كوبالتي
  static const pine = Color(0xFF1E3A6E);

  /// أزرق ليلي عميق
  static const pineDeep = Color(0xFF0F1F3D);

  /// فيروزي (لمسات وتمييز)
  static const pineLight = Color(0xFF2A9D9A);
  static const turquoise = Color(0xFF2A9D9A);

  /// كهرماني دافئ (بدل الذهبي)
  static const gold = Color(0xFFE2A13B);
  static const goldLight = Color(0xFFF5D394);

  /// رملي فاتح (خلفية)
  static const cream = Color(0xFFF5F0E6);
  static const ink = Color(0xFF17202F);
  static const night = Color(0xFF0A1120);
  static const nightCard = Color(0xFF121C30);
  static const rose = Color(0xFFD9573F);
  static const amber = Color(0xFFE08A1F);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF132852), Color(0xFF1E3A6E), Color(0xFF235C86)],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFF7D798), gold, Color(0xFFC9822A)],
  );

  /// تدرّج فيروزي (للتقدّم والنجاح)
  static const tealGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF5CC6BF), turquoise, Color(0xFF1C7471)],
  );
}

class AppTheme {
  static const font = 'Plex';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.pine,
      primary: AppColors.pine,
      secondary: AppColors.gold,
      surface: Colors.white,
      brightness: Brightness.light,
    );
    return _base(scheme, Brightness.light).copyWith(scaffoldBackgroundColor: AppColors.cream);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.pine,
      primary: AppColors.pineLight,
      secondary: AppColors.gold,
      surface: AppColors.nightCard,
      brightness: Brightness.dark,
    );
    return _base(scheme, Brightness.dark).copyWith(scaffoldBackgroundColor: AppColors.night);
  }

  static ThemeData _base(ColorScheme scheme, Brightness b) {
    final base = ThemeData(useMaterial3: true, brightness: b, fontFamily: font);
    final text = base.textTheme.copyWith(
      headlineLarge: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.3),
      headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.6),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.6),
    ).apply(fontFamily: font, bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: font,
      colorScheme: scheme,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5))),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          textStyle: text.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          textStyle: text.titleMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: b == Brightness.light ? Colors.white : AppColors.nightCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: b == Brightness.light ? Colors.white : AppColors.nightCard,
        indicatorColor: scheme.primary.withValues(alpha: .14),
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: b == Brightness.light ? AppColors.cream : AppColors.nightCard,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// خط قرآني للعناوين وأسماء السور والنص الاحتياطي
  static TextStyle quran({double size = 24, Color? color, double height = 2.1}) =>
      TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: height, color: color);
}

/// ألوان صفحة المصحف
class MushafPalette {
  final Color bg, paper, ink, frame, accent, number;
  final bool dark;
  const MushafPalette(this.bg, this.paper, this.ink, this.frame, this.accent, this.number, {this.dark = false});

  static const light = MushafPalette(Color(0xFFEFE7D4), Color(0xFFFCF8EE), Color(0xFF221C12), AppColors.gold, AppColors.pineDeep, Color(0xFFA9842F));
  static const sepia = MushafPalette(Color(0xFFE6D8BA), Color(0xFFF5E9CF), Color(0xFF3A2B16), Color(0xFFB08A3E), Color(0xFF7A5A1E), Color(0xFF8C6A2A));
  static const night = MushafPalette(Color(0xFF070D0B), Color(0xFF101916), Color(0xFFE6DFCC), Color(0xFF8D7A45), AppColors.goldLight, AppColors.gold, dark: true);

  static MushafPalette of(String key, Brightness appBrightness) => switch (key) {
        'paper' => light,
        'sepia' => sepia,
        'night' => night,
        _ => appBrightness == Brightness.dark ? night : light,
      };
}
