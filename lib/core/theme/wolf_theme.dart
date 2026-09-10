import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'wolf_colors.dart';
import 'wolf_typography.dart';

abstract final class WolfTheme {
  static ThemeData dark() {
    final text = WolfTypography.textTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: WolfColors.voidBlack,
      colorScheme: const ColorScheme.dark(
        surface: WolfColors.charcoal,
        primary: WolfColors.lime,
        secondary: WolfColors.ember,
        onPrimary: WolfColors.voidBlack,
        onSurface: WolfColors.bone,
        outline: WolfColors.steel,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: text.headlineMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: WolfColors.steel,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WolfColors.slate,
        hintStyle: text.bodyMedium,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: WolfColors.charcoal,
        selectedItemColor: WolfColors.lime,
        unselectedItemColor: WolfColors.mist,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
