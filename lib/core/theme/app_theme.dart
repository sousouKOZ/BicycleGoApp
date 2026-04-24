import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfacePrimaryDark,
      primary: AppColors.accent,
      secondary: AppColors.accentAlt,
      tertiary: AppColors.success,
      error: AppColors.danger,
    );

    final baseText = GoogleFonts.notoSansJpTextTheme(ThemeData.dark().textTheme);
    final headingText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    final textTheme = baseText.copyWith(
      displayLarge: headingText.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.onSurfacePrimaryDark,
      ),
      displayMedium: headingText.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.onSurfacePrimaryDark,
      ),
      headlineLarge: headingText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.onSurfacePrimaryDark,
      ),
      headlineMedium: headingText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimaryDark,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.onSurfacePrimaryDark,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimaryDark,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimaryDark,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        color: AppColors.onSurfacePrimaryDark,
        height: 1.55,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        color: AppColors.onSurfacePrimaryDark,
        height: 1.55,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        color: AppColors.onSurfaceSecondaryDark,
        height: 1.5,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimaryDark,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceSecondaryDark,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceSecondaryDark,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.onSurfacePrimaryDark),
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.92),
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppColors.accent
                : AppColors.onSurfaceSecondaryDark,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundDark,
        side: BorderSide(
            color: AppColors.onSurfaceSecondaryDark.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark.withValues(alpha: 0.92),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide:
              BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(14),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceSecondaryDark,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.onSurfaceSecondaryDark.withValues(alpha: 0.15),
        thickness: 1,
        space: 24,
      ),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.surface,
      onSurface: AppColors.onSurfacePrimary,
      primary: AppColors.accent,
      secondary: AppColors.accentAlt,
      tertiary: AppColors.success,
      error: AppColors.danger,
    );

    final baseText = GoogleFonts.notoSansJpTextTheme();
    final headingText = GoogleFonts.interTextTheme();

    final textTheme = baseText.copyWith(
      displayLarge: headingText.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.onSurfacePrimary,
      ),
      displayMedium: headingText.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.onSurfacePrimary,
      ),
      headlineLarge: headingText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.onSurfacePrimary,
      ),
      headlineMedium: headingText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimary,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.onSurfacePrimary,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimary,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimary,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        color: AppColors.onSurfacePrimary,
        height: 1.55,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        color: AppColors.onSurfacePrimary,
        height: 1.55,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        color: AppColors.onSurfaceSecondary,
        height: 1.5,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfacePrimary,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceSecondary,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceSecondary,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.onSurfacePrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accent : AppColors.onSurfaceSecondary,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        side: BorderSide(
            color: AppColors.onSurfaceSecondary.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.92),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide:
              BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceSecondary,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.accent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.onSurfaceSecondary.withValues(alpha: 0.12),
        thickness: 1,
        space: 24,
      ),
    );
  }
}
