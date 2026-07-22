import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF20302A);
  static const Color pine = Color(0xFF1E3D33);
  static const Color jade = Color(0xFF2F5A4B);
  static const Color mint = Color(0xFFDCE6E0);
  static const Color cream = Color(0xFFF4EEE3);
  static const Color surface = Color(0xFFFFFCF4);
  static const Color surfaceSoft = Color(0xFFFBF6EC);
  static const Color copper = Color(0xFFE28C74);
  static const Color blush = Color(0xFFFFEEE8);
  static const Color sun = Color(0xFFD9B44A);
  static const Color sky = Color(0xFF5B6B64);
  static const Color lilac = Color(0xFFE7E1D6);
  static const Color border = Color(0xFFE6DDCE);
  static const String appFontFamily = 'Arial';

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

    final baseBody = ThemeData.light().textTheme.apply(
      fontFamily: appFontFamily,
      bodyColor: ink,
      displayColor: ink,
    );
    final textTheme = baseBody.copyWith(
      displayLarge: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 52,
        fontWeight: FontWeight.w800,
        height: 1.05,
        color: ink,
      ),
      displayMedium: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 1.08,
        color: ink,
      ),
      displaySmall: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.12,
        color: ink,
      ),
      headlineLarge: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      headlineMedium: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 23,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      bodyLarge: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ink,
      ),
      bodyMedium: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: ink,
      ),
      labelLarge: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      labelMedium: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: appFontFamily,
      scaffoldBackgroundColor: cream,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: 64,
      ),
      cardTheme: CardThemeData(
        color: surface,
        shadowColor: ink.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0.5,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.86),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
