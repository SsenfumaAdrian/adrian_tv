import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ADRIAN TV dark cinematic theme.
///
/// Palette: near-black surfaces with violet->cyan accent gradient, high
/// contrast text sized for both phone and 10-foot TV viewing.
abstract final class AppColors {
  static const background = Color(0xFF0A0A12);
  static const surface = Color(0xFF12121D);
  static const surfaceBright = Color(0xFF1B1B2A);
  static const violet = Color(0xFF7B5CFF);
  static const cyan = Color(0xFF22D3EE);
  static const textPrimary = Color(0xFFF2F3F7);
  static const textSecondary = Color(0xFF9BA0B5);
  static const danger = Color(0xFFFF5A6E);
  static const success = Color(0xFF3DDC97);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, cyan],
  );
}

abstract final class AppTheme {
  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.violet,
          brightness: Brightness.dark,
          surface: AppColors.surface,
        ).copyWith(
          primary: AppColors.violet,
          secondary: AppColors.cyan,
          error: AppColors.danger,
          onSurface: AppColors.textPrimary,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceBright,
        selectedColor: AppColors.violet,
        side: BorderSide.none,
        labelStyle: base.textTheme.bodyMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceBright,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.violet.withValues(alpha: 0.24),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.violet,
      ),
    );
  }

  /// Focus visual used by Android TV directional navigation.
  static Widget tvFocus({required bool focused, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
        border: focused
            ? Border.all(color: AppColors.cyan, width: 2)
            : Border.all(color: Colors.transparent),
      ),
      transform: focused
          ? Matrix4.diagonal3Values(1.03, 1.03, 1)
          : Matrix4.identity(),
      child: child,
    );
  }
}
