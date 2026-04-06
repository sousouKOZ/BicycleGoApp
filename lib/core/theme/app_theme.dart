import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: AppColors.accent),
      );
}
