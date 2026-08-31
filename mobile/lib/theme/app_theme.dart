import 'package:flutter/material.dart';

/// Yıldızlı gece paleti: derin lacivert zemin, cam yüzeyler, yumuşak indigo vurgu.
class AppColors {
  static const Color background = Color(0xFF050816);
  static const Color surface = Color(0xE612182C);
  static const Color surfaceSolid = Color(0xFF12182C);
  static const Color surfaceAlt = Color(0xFF1A2238);
  static const Color border = Color(0x2BA8B8FF);
  static const Color accent = Color(0xFF8BA4F0);
  static const Color accentPurple = Color(0xFF7A72C8);
  static const Color accentBlue = Color(0xFF6B8FD4);
  static const Color text = Color(0xFFF2F4FF);
  static const Color muted = Color(0xFF9AA3C2);
  static const Color olumlu = Color(0xFF5DDBA5);
  static const Color olumsuz = Color(0xFFE07A8A);
  static const Color beklemede = Color(0xFFE0C56E);
  // "Karma" (mixed) görüşme durumu: hem olumlu hem olumsuz sinyal aynı anda
  // varken kullanılan, diğer durum renklerinden net şekilde ayrışan turuncu.
  static const Color karma = Color(0xFFE08A3C);
  static const Color record = Color(0xFFD96B7E);
}

class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentPurple,
      surface: AppColors.surfaceSolid,
      error: AppColors.olumsuz,
      onPrimary: Color(0xFF0B1020),
      onSecondary: AppColors.text,
      onSurface: AppColors.text,
      onError: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: const TextStyle(color: AppColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Color(0xFF0B1020),
        elevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF0B1020),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt.withValues(alpha: 0.85),
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceSolid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
    );
  }

  static Color statusColor(String? durum) {
    final d = (durum ?? '').toLowerCase();
    if (d.contains('karma')) return AppColors.karma;
    if (d.contains('olumlu')) return AppColors.olumlu;
    if (d.contains('olumsuz')) return AppColors.olumsuz;
    return AppColors.beklemede;
  }

  /// Görüşme durumu rozetlerinde (bkz. `MeetingCard`, `MeetingDetailSheet`)
  /// renkle birlikte gösterilen ikon; "Karma" durumunu diğerlerinden görsel
  /// olarak da net şekilde ayırt eder.
  static IconData statusIcon(String? durum) {
    final d = (durum ?? '').toLowerCase();
    if (d.contains('karma')) return Icons.call_split_rounded;
    if (d.contains('olumlu')) return Icons.check_circle_rounded;
    if (d.contains('olumsuz')) return Icons.cancel_rounded;
    return Icons.hourglass_top_rounded;
  }
}
