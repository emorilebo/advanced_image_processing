import 'package:flutter/material.dart';

abstract final class StudioTheme {
  static const amber = Color(0xFFFF9F43);
  static const blue = Color(0xFF5AC8FA);
  static const background = Color(0xFF0B0C0F);
  static const surface = Color(0xFF15171C);
  static const raised = Color(0xFF1E2128);
  static const outline = Color(0xFF2A2E36);

  static ThemeData get dark => _build(true);
  static ThemeData get light => _build(false);

  static ThemeData _build(bool dark) {
    final colors = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? amber : const Color(0xFF914400),
      onPrimary: dark ? background : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF3A291B) : const Color(0xFFFFE6CC),
      onPrimaryContainer: dark ? amber : const Color(0xFF683000),
      secondary: dark ? blue : const Color(0xFF00658B),
      onSecondary: dark ? background : Colors.white,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
      onError: dark ? const Color(0xFF690005) : Colors.white,
      surface: dark ? surface : const Color(0xFFFFFFFF),
      onSurface: dark ? const Color(0xFFF2F3F5) : const Color(0xFF20232A),
      onSurfaceVariant:
          dark ? const Color(0xFF9AA0AA) : const Color(0xFF626975),
      surfaceContainerHighest: dark ? raised : const Color(0xFFEBEDF1),
      outline: const Color(0xFF747B87),
      outlineVariant: dark ? outline : const Color(0xFFDADDE3),
    );
    final base =
        ThemeData(useMaterial3: true, colorScheme: colors, fontFamily: 'Inter');
    final rounded =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return base.copyWith(
      scaffoldBackgroundColor: dark ? background : const Color(0xFFF5F4F1),
      textTheme: base.textTheme
          .copyWith(
            headlineLarge: TextStyle(
                fontFamily: 'Inter',
                fontSize: 34,
                height: 1.12,
                letterSpacing: -1.3,
                fontWeight: FontWeight.w600,
                color: colors.onSurface),
            headlineMedium: TextStyle(
                fontFamily: 'Inter',
                fontSize: 28,
                height: 1.2,
                letterSpacing: -0.8,
                fontWeight: FontWeight.w600,
                color: colors.onSurface),
            titleLarge: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                letterSpacing: -0.5,
                fontWeight: FontWeight.w600,
                color: colors.onSurface),
            titleMedium: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.onSurface),
            bodyMedium: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.5,
                color: colors.onSurface),
            bodySmall: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.5,
                color: colors.onSurfaceVariant),
            labelSmall: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: colors.onSurfaceVariant),
          )
          .apply(fontFamily: 'Inter'),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded,
        elevation: 0,
        textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: rounded,
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.outlineVariant),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 44))),
      iconButtonTheme: IconButtonThemeData(
          style:
              IconButton.styleFrom(foregroundColor: colors.onSurfaceVariant)),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.outlineVariant,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceContainerHighest,
        selectedColor: colors.primaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
            fontFamily: 'Inter', color: colors.onSurface, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
            fontFamily: 'Inter', fontSize: 11, color: colors.onSurface)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        selectedIconTheme: IconThemeData(color: colors.primary),
        unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        selectedLabelTextStyle:
            TextStyle(fontFamily: 'Inter', fontSize: 11, color: colors.primary),
        unselectedLabelTextStyle: TextStyle(
            fontFamily: 'Inter', fontSize: 11, color: colors.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.onSurface,
        contentTextStyle: TextStyle(fontFamily: 'Inter', color: colors.surface),
        shape: rounded,
      ),
    );
  }
}
