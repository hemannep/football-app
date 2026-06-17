import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color brand = Color(0xFF00C853);
  static const Color brandDark = Color(0xFF00A042);
  static const Color accent = Color(0xFFFFB300);
  static const Color live = Color(0xFFFF1744);

  static const Color bg = Color(0xFF0A0E14);
  static const Color surface = Color(0xFF11161F);
  static const Color surfaceHi = Color(0xFF1A2230);
  static const Color stroke = Color(0xFF1F2937);
  static const Color textHi = Color(0xFFF7FAFC);
  static const Color textMid = Color(0xFFB8C2CC);
  static const Color textLow = Color(0xFF8794A1);

  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceHiLight = Color(0xFFEEF1F5);
  static const Color strokeLight = Color(0xFFE2E8F0);
  static const Color textHiLight = Color(0xFF0F172A);
  static const Color textMidLight = Color(0xFF475569);
  static const Color textLowLight = Color(0xFF94A3B8);

  static const Color good = Color(0xFF00C853);
  static const Color warn = Color(0xFFFFB300);
  static const Color bad = Color(0xFFE53935);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C853), Color(0xFF00B0FF)],
  );
  static const LinearGradient liveGradient = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFFF6E40)],
  );
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2A1F), Color(0xFF0A1F2E)],
  );
  static const LinearGradient heroGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6F7EF), Color(0xFFE3F2FD)],
  );

  static const double r = 16;
  static const double rSm = 10;
  static const double rXs = 6;

  static Palette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Palette.dark()
        : Palette.light();
  }

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        cs: const ColorScheme.dark(
          primary: brand,
          onPrimary: Colors.black,
          secondary: accent,
          onSecondary: Colors.black,
          surface: surface,
          onSurface: textHi,
          error: bad,
        ),
        p: Palette.dark(),
        statusBarBrightness: Brightness.light,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        cs: const ColorScheme.light(
          primary: brand,
          onPrimary: Colors.white,
          secondary: accent,
          onSecondary: Colors.black,
          surface: surfaceLight,
          onSurface: textHiLight,
          error: bad,
        ),
        p: Palette.light(),
        statusBarBrightness: Brightness.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme cs,
    required Palette p,
    required Brightness statusBarBrightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      colorScheme: cs,
      fontFamily: 'Roboto',
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: p.textHi,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3),
        iconTheme: IconThemeData(color: p.textHi),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarBrightness,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: BorderSide(color: p.stroke, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: brand,
        unselectedItemColor: p.textLow,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceHi,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: p.textLow, fontSize: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rSm),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rSm),
          borderSide: const BorderSide(color: brand, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor:
              brightness == Brightness.dark ? Colors.black : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSm)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textHi,
          side: BorderSide(color: p.stroke),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSm)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHi,
        selectedColor: brand,
        labelStyle: TextStyle(color: p.textMid, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(
            color: brightness == Brightness.dark ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.stroke)),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(color: p.stroke, thickness: 1, space: 1),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: brand, linearTrackColor: p.stroke),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHi,
        contentTextStyle: TextStyle(color: p.textHi),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSm)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: brand,
        unselectedLabelColor: p.textMid,
        indicatorColor: brand,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}

class Palette {
  final Color bg, surface, surfaceHi, stroke;
  final Color textHi, textMid, textLow;
  final LinearGradient heroGradient;
  final bool isDark;

  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.stroke,
    required this.textHi,
    required this.textMid,
    required this.textLow,
    required this.heroGradient,
    required this.isDark,
  });

  factory Palette.dark() => const Palette(
        bg: AppTheme.bg,
        surface: AppTheme.surface,
        surfaceHi: AppTheme.surfaceHi,
        stroke: AppTheme.stroke,
        textHi: AppTheme.textHi,
        textMid: AppTheme.textMid,
        textLow: AppTheme.textLow,
        heroGradient: AppTheme.heroGradient,
        isDark: true,
      );

  factory Palette.light() => const Palette(
        bg: AppTheme.bgLight,
        surface: AppTheme.surfaceLight,
        surfaceHi: AppTheme.surfaceHiLight,
        stroke: AppTheme.strokeLight,
        textHi: AppTheme.textHiLight,
        textMid: AppTheme.textMidLight,
        textLow: AppTheme.textLowLight,
        heroGradient: AppTheme.heroGradientLight,
        isDark: false,
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text,
      {super.key, this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 8)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.brand,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
