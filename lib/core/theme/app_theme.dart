import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color ink = Color(0xFF18211F);
  static const Color pine = Color(0xFF17493D);
  static const Color jade = Color(0xFF1E6D5B);
  static const Color mint = Color(0xFFD8ECE3);
  static const Color cream = Color(0xFFF6F1E8);
  static const Color surface = Color(0xFFFFFBF5);
  static const Color surfaceSoft = Color(0xFFF1E9DC);
  static const Color copper = Color(0xFFC07A45);
  static const Color blush = Color(0xFFE8D6C4);
  static const Color border = Color(0xFFE0D4C5);

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: pine,
      onPrimary: Colors.white,
      secondary: copper,
      onSecondary: Colors.white,
      error: Color(0xFFB42318),
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: Color(0xFF5B625E),
      outline: border,
      outlineVariant: Color(0xFFE9E0D3),
      shadow: Color(0x1F18211F),
      scrim: Color(0x6618211F),
      inverseSurface: ink,
      onInverseSurface: surface,
      inversePrimary: mint,
    );

    final baseBody = GoogleFonts.manropeTextTheme();
    final textTheme = baseBody.copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        height: 1.02,
        color: ink,
      ),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: ink,
      ),
      displaySmall: GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 1.08,
        color: ink,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.55,
        color: ink,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.55,
        color: ink,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cream,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: 76,
      ),
      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.9),
        shadowColor: Colors.black.withValues(alpha: 0.05),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.82),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: pine, width: 1.4),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: ink.withValues(alpha: 0.55),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: ink.withValues(alpha: 0.72),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(pine),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(ink),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(pine),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        selectedColor: pine,
        secondarySelectedColor: pine,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dividerColor: border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
