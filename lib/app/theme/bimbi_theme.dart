import 'package:flutter/material.dart';

import 'bimbi_colors.dart';
import 'bimbi_tokens.dart';

/// Builds the shared light and dark lavender themes.
abstract final class BimbiTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: BimbiPalette.lightAccent,
    onPrimary: BimbiPalette.white,
    primaryContainer: BimbiPalette.lightTint,
    onPrimaryContainer: BimbiPalette.ink,
    secondary: BimbiPalette.night,
    onSecondary: BimbiPalette.lightBackground,
    secondaryContainer: BimbiPalette.lavenderMist,
    onSecondaryContainer: BimbiPalette.night,
    tertiary: BimbiPalette.mint,
    onTertiary: BimbiPalette.white,
    tertiaryContainer: BimbiPalette.mintTint,
    onTertiaryContainer: BimbiPalette.ink,
    error: BimbiPalette.coral,
    onError: BimbiPalette.white,
    errorContainer: BimbiPalette.coralTint,
    onErrorContainer: BimbiPalette.ink,
    surface: BimbiPalette.lightBackground,
    onSurface: BimbiPalette.ink,
    onSurfaceVariant: BimbiPalette.inkSoft,
    surfaceContainerLowest: BimbiPalette.paper,
    surfaceContainerLow: BimbiPalette.paper,
    surfaceContainer: BimbiPalette.lightBackground,
    surfaceContainerHigh: BimbiPalette.lightLine,
    surfaceContainerHighest: BimbiPalette.inputLine,
    outline: BimbiPalette.inkSoft,
    outlineVariant: BimbiPalette.inputLine,
    inverseSurface: BimbiPalette.ink,
    onInverseSurface: BimbiPalette.lightBackground,
    inversePrimary: BimbiPalette.darkAccent,
    shadow: BimbiPalette.ink,
    scrim: BimbiPalette.ink,
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: BimbiPalette.darkAccent,
    onPrimary: BimbiPalette.darkOnAccent,
    primaryContainer: BimbiPalette.nightHigh,
    onPrimaryContainer: BimbiPalette.lavenderMist,
    secondary: BimbiPalette.lavender,
    onSecondary: BimbiPalette.night,
    secondaryContainer: BimbiPalette.nightHigh,
    onSecondaryContainer: BimbiPalette.lavenderMist,
    tertiary: BimbiPalette.mintBright,
    onTertiary: BimbiPalette.night,
    tertiaryContainer: Color(0xFF1F3B3A),
    onTertiaryContainer: BimbiPalette.lavenderMist,
    error: BimbiPalette.coralBright,
    onError: BimbiPalette.night,
    errorContainer: Color(0xFF4A2337),
    onErrorContainer: BimbiPalette.lavenderMist,
    surface: BimbiPalette.night,
    onSurface: BimbiPalette.lavenderMist,
    onSurfaceVariant: BimbiPalette.lavender,
    surfaceContainerLowest: BimbiPalette.night,
    surfaceContainerLow: BimbiPalette.nightRaised,
    surfaceContainer: BimbiPalette.nightRaised,
    surfaceContainerHigh: BimbiPalette.nightHigh,
    surfaceContainerHighest: BimbiPalette.nightHigh,
    outline: BimbiPalette.lavender,
    outlineVariant: BimbiPalette.nightLine,
    inverseSurface: BimbiPalette.lavenderMist,
    onInverseSurface: BimbiPalette.night,
    inversePrimary: BimbiPalette.lightAccent,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static TextTheme textTheme(Color color, Color muted) {
    TextStyle display(double size) => TextStyle(
      fontFamily: BimbiFonts.display,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.1,
      color: color,
      letterSpacing: 0,
    );
    TextStyle body(
      double size, {
      FontWeight weight = FontWeight.w500,
      double height = 1.4,
      Color? tint,
    }) => TextStyle(
      fontFamily: BimbiFonts.body,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: tint ?? color,
      letterSpacing: 0,
    );
    return TextTheme(
      // Clock · Instrument Serif 72.
      displayLarge: display(72).copyWith(height: 1),
      displayMedium: display(52).copyWith(height: 1),
      displaySmall: display(40),
      // Title · Instrument Serif 34.
      headlineLarge: display(34),
      headlineMedium: display(28),
      // Heading · Instrument Serif 22.
      headlineSmall: display(22),
      titleLarge: display(20),
      titleMedium: body(17, weight: FontWeight.w800, height: 1.3),
      titleSmall: body(15, weight: FontWeight.w800, height: 1.3),
      // Body · Nunito 16.
      bodyLarge: body(16),
      bodyMedium: body(15),
      bodySmall: body(13, weight: FontWeight.w600, tint: muted),
      labelLarge: body(16, weight: FontWeight.w800, height: 1.2),
      // Label · Nunito 13.
      labelMedium: body(13, weight: FontWeight.w800, height: 1.2),
      labelSmall: body(12, weight: FontWeight.w800, height: 1.2),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight ? _lightScheme : _darkScheme;
    final c = isLight ? BimbiColors.light : BimbiColors.dark;
    final text = textTheme(c.text, c.textMuted);
    const pill = StadiumBorder();
    final buttonText = text.labelLarge!;
    final disabledBg = c.accentTint;
    final disabledFg = isLight ? BimbiPalette.inkSoft : BimbiPalette.lavender;

    WidgetStateProperty<Color?> byState(
      Color normal, {
      Color? pressed,
      Color? disabled,
    }) => WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabled ?? normal;
      if (states.contains(WidgetState.pressed)) return pressed ?? normal;
      return normal;
    });

    final focusSide = BorderSide(color: c.focusRing, width: 3);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      fontFamily: BimbiFonts.body,
      textTheme: text,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      focusColor: c.focusRing.withValues(alpha: 0.16),
      iconTheme: IconThemeData(color: c.text, size: 24),
      dividerTheme: DividerThemeData(color: c.cardBorder, thickness: 1.5),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          ),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(buttonText),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: byState(
            scheme.primary,
            pressed: isLight
                ? BimbiPalette.lightPressed
                : BimbiPalette.darkPressed,
            disabled: disabledBg,
          ),
          foregroundColor: byState(scheme.onPrimary, disabled: disabledFg),
          overlayColor: const WidgetStatePropertyAll(Color(0x1431233F)),
          side: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.focused) ? focusSide : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(buttonText),
          backgroundColor: byState(c.card, disabled: c.card),
          foregroundColor: byState(c.text, disabled: disabledFg),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.focused)) return focusSide;
            return BorderSide(color: c.inputBorder, width: 2);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(buttonText),
          foregroundColor: byState(c.link, disabled: disabledFg),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          foregroundColor: byState(c.text, disabled: disabledFg),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
        elevation: 0,
        highlightElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BimbiRadius.cardBorder,
          side: BorderSide(color: c.cardBorder, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        labelStyle: text.bodyLarge?.copyWith(color: c.textMuted),
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.text),
        helperStyle: text.bodySmall,
        helperMaxLines: 3,
        errorMaxLines: 3,
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        border: OutlineInputBorder(
          borderRadius: BimbiRadius.inputBorder,
          borderSide: BorderSide(color: c.inputBorder, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BimbiRadius.inputBorder,
          borderSide: BorderSide(color: c.inputBorder, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BimbiRadius.inputBorder,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BimbiRadius.inputBorder,
          borderSide: BorderSide(color: c.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BimbiRadius.inputBorder,
          borderSide: BorderSide(color: c.danger, width: 2.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? scheme.primary : c.accentTint,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.chipBorder,
        ),
        side: BorderSide(color: c.inputBorder, width: 1.5),
        backgroundColor: c.card,
        selectedColor: c.accentTint,
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.accentTint : c.card,
          ),
          foregroundColor: WidgetStatePropertyAll(c.text),
          side: WidgetStatePropertyAll(
            BorderSide(color: c.inputBorder, width: 1.5),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentTint,
        indicatorShape: pill,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            color: s.contains(WidgetState.selected)
                ? c.navActive
                : c.navInactive,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? c.navActive
                : c.navInactive,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: c.accentTint,
        indicatorShape: pill,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: text.labelSmall?.copyWith(color: c.navActive),
        unselectedLabelTextStyle: text.labelSmall?.copyWith(
          color: c.navInactive,
        ),
        selectedIconTheme: IconThemeData(color: c.navActive),
        unselectedIconTheme: IconThemeData(color: c.navInactive),
        minWidth: 88,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.inputBorder,
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.cardBorder,
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.inputBorder,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BimbiRadius.card),
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.cardBorder,
        ),
        hourMinuteShape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.inputBorder,
        ),
        dayPeriodShape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.chipBorder,
        ),
        hourMinuteTextStyle: text.displayMedium,
        dialHandColor: scheme.primary,
        dialBackgroundColor: c.accentTint,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: c.accentTint,
        circularTrackColor: c.accentTint,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.text,
        textColor: c.text,
        minVerticalPadding: 12,
        shape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.inputBorder,
        ),
        selectedColor: c.navActive,
        selectedTileColor: c.accentTint,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.cardBorder,
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BimbiRadius.cardBorder,
        ),
        iconColor: c.text,
        collapsedIconColor: c.text,
        textColor: c.text,
        collapsedTextColor: c.text,
      ),
    );
  }
}
