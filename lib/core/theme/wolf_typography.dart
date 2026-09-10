import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'wolf_colors.dart';

abstract final class WolfTypography {
  static TextTheme textTheme() {
    final display = GoogleFonts.bebasNeue(
      color: WolfColors.bone,
      letterSpacing: 2.4,
      height: 1.0,
    );
    final body = GoogleFonts.spaceGrotesk(
      color: WolfColors.bone,
      height: 1.35,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 56, fontWeight: FontWeight.w400),
      displayMedium: display.copyWith(fontSize: 40, letterSpacing: 3),
      displaySmall: display.copyWith(fontSize: 28, letterSpacing: 2.2),
      headlineLarge: display.copyWith(fontSize: 24, letterSpacing: 2),
      headlineMedium: display.copyWith(fontSize: 20, letterSpacing: 1.8),
      titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      titleSmall: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: WolfColors.mist,
      ),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body.copyWith(fontSize: 14, color: WolfColors.mist),
      bodySmall: body.copyWith(fontSize: 12, color: WolfColors.mist),
      labelLarge: body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      labelMedium: body.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: WolfColors.lime,
      ),
    );
  }
}
