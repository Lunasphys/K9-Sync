import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couleurs et formes des maquettes K9 Sync (HTML mockups).
class AppColors {
  AppColors._();

  static const Color orange = Color(0xFFE8692A);
  static const Color orangeLight = Color(0xFFFFF0E8);
  static const Color cream = Color(0xFFF5E6C8);
  static const Color creamDark = Color(0xFFEDD9A3);
  static const Color blue = Color(0xFF4A6CF7);
  static const Color blueLight = Color(0xFFEEF2FF);
  static const Color greenMint = Color(0xFFC8F0D8);
  static const Color pinkLight = Color(0xFFFFD6D6);
  static const Color yellowLight = Color(0xFFFFF3CC);
  static const Color bg = Color(0xFFEBEBEB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF666666);
  static const Color border = Color(0xFF1A1A1A);
  static const Color greenStatus = Color(0xFF2ECC71);
  static const Color redDanger = Color(0xFFDC2626);
  static const Color redLight = Color(0xFFFFE4E4);

  // Aliases pour compatibilité
  static const Color primary = orange;
  static const Color primaryDark = Color(0xFFD35400);
  static const Color cardSecurity = greenMint;
  static const Color cardHealth = pinkLight;
  static const Color cardActivity = yellowLight;
  static const Color cardBorderStrong = border;
  static const Color cardBorderWeak = Color(0xFF86EFAC);
  static const Color buttonSecondaryBg = cream;
  static const Color buttonSecondaryBorder = border;
  static const Color background = cardBg;
  static const Color surface = bg;
}

/// Constantes de style (maquettes).
class AppDimensions {
  AppDimensions._();
  static const double radius = 18;
  static const double radiusSm = 12;
  static const double shadowOffset = 3;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(radius));
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static BoxShadow get cardShadow => BoxShadow(
        color: AppColors.border,
        offset: const Offset(shadowOffset, shadowOffset),
        blurRadius: 0,
      );
  static BoxShadow get cardShadowSm => BoxShadow(
        color: AppColors.border,
        offset: const Offset(2, 2),
        blurRadius: 0,
      );
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        primary: AppColors.orange,
        surface: AppColors.bg,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        titleTextStyle: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        bodyLarge: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900),
        titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        labelLarge: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: const BorderSide(color: AppColors.border, width: 2),
          ),
          elevation: 0,
          shadowColor: AppColors.border,
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          backgroundColor: AppColors.cream,
          elevation: 0,
          shadowColor: AppColors.border,
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          side: const BorderSide(color: AppColors.border, width: 2),
        ),
        color: AppColors.cardBg,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.textMuted,
        elevation: 0,
        backgroundColor: AppColors.cardBg,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        border: OutlineInputBorder(borderRadius: AppDimensions.borderRadiusSm),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}
