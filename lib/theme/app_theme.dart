import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current appearance: system, light or dark.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  switch (prefs.getString('themeMode')) {
    case 'light':
      themeNotifier.value = ThemeMode.light;
      break;
    case 'dark':
      themeNotifier.value = ThemeMode.dark;
      break;
    default:
      themeNotifier.value = ThemeMode.system;
  }
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('themeMode', mode.name);
}

/// iOS-style colours, black & white like the design.
class Palette {
  final Color bg, card, chip, text, secondary, separator, fill, thumb, danger;
  final bool isDark;

  const Palette({
    required this.bg,
    required this.card,
    required this.chip,
    required this.text,
    required this.secondary,
    required this.separator,
    required this.fill,
    required this.thumb,
    required this.danger,
    required this.isDark,
  });

  static const light = Palette(
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFF4F4F6),
    chip: Color(0xFFFFFFFF),
    text: Color(0xFF000000),
    secondary: Color(0xFF8E8E93),
    separator: Color(0xFFE5E5EA),
    fill: Color(0xFFEFEFF1),
    thumb: Color(0xFFFFFFFF),
    danger: Color(0xFFFF3B30),
    isDark: false,
  );

  static const dark = Palette(
    bg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    chip: Color(0xFF2C2C2E),
    text: Color(0xFFFFFFFF),
    secondary: Color(0xFF8E8E93),
    separator: Color(0xFF38383A),
    fill: Color(0xFF1C1C1E),
    thumb: Color(0xFF636366),
    danger: Color(0xFFFF453A),
    isDark: true,
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;

  final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = base.textTheme.apply(
    fontFamily: GoogleFonts.inter().fontFamily,
    bodyColor: p.text,
    displayColor: p.text,
  );


  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.text,
      brightness: brightness,
    ).copyWith(
      primary: p.text,
      onPrimary: p.bg,
      surface: p.bg,
      onSurface: p.text,
      error: p.danger,
    ),
    textTheme: textTheme,
    // No Android ripple – iOS apps don't have it
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // iOS slide transitions + swipe-back on every platform
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.text,
      selectionColor: p.secondary.withValues(alpha: 0.35),
      selectionHandleColor: p.text,
    ),
    dividerColor: p.separator,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: GoogleFonts.inter(color: p.bg, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: p.text,
      scaffoldBackgroundColor: p.bg,
      barBackgroundColor: p.bg.withValues(alpha: 0.85),
      textTheme: CupertinoTextThemeData(
        textStyle: GoogleFonts.inter(color: p.text, fontSize: 16),
        actionTextStyle: GoogleFonts.inter(color: p.text, fontSize: 17),
        navActionTextStyle: GoogleFonts.inter(color: p.text, fontSize: 17),
        navTitleTextStyle: GoogleFonts.inter(
          color: p.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        navLargeTitleTextStyle: GoogleFonts.inter(
          color: p.text,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
      ),
    ),
  );
}
