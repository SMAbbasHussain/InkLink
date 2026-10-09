import 'package:flutter/material.dart';

import 'ink_colors.dart';
import 'ink_tokens.dart';
import 'ink_type.dart';

/// Builds the light and dark `ThemeData` for the Desk redesign and exposes
/// [InkTokens] via a `ThemeExtension`. Read tokens anywhere with `context.ink`.
class InkTheme {
  const InkTheme._();

  static ThemeData light() => _build(InkTokens.light());

  static ThemeData dark() => _build(InkTokens.dark());

  static ThemeData _build(InkTokens tokens) {
    final isDark = tokens.isDark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    final textTheme = _textTheme(tokens).apply(
      bodyColor: tokens.ink,
      displayColor: tokens.ink,
    );

    return base.copyWith(
      useMaterial3: true,
      brightness: tokens.brightness,
      scaffoldBackgroundColor: tokens.surfaceDesk,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light())
          .copyWith(
            primary: tokens.accent,
            secondary: tokens.accent,
            surface: tokens.paper,
            error: tokens.danger,
            onPrimary: Colors.white,
            onSurface: tokens.ink,
          ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: InkType.title(tokens.ink),
        iconTheme: IconThemeData(color: tokens.ink),
      ),
      iconTheme: IconThemeData(color: tokens.ink, size: 20),
      dividerColor: tokens.glassStroke,
      splashFactory: InkRipple.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.field,
        hintStyle: InkType.body(tokens.inkMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s16,
          vertical: InkSpacing.s16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide(color: tokens.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.input),
          borderSide: BorderSide(color: tokens.danger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InkRadii.button),
          ),
          textStyle: InkType.bodyStrong(Colors.white),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accentText,
          textStyle: InkType.bodyStrong(tokens.accentText),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.ink,
          side: BorderSide(color: tokens.glassStroke),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InkRadii.button),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : tokens.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.field,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.accent
              : Colors.transparent,
        ),
        side: BorderSide(color: tokens.inkMuted, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.inkMuted,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: tokens.accent,
        inactiveTrackColor: tokens.field,
        thumbColor: Colors.white,
        overlayColor: tokens.accent.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.field,
        selectedColor: tokens.accentSoft,
        labelStyle: InkType.label(tokens.ink),
        secondaryLabelStyle: InkType.label(tokens.accentText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkRadii.chip),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.ink,
        unselectedLabelColor: tokens.inkMuted,
        indicatorColor: tokens.accent,
        labelStyle: InkType.label(tokens.ink),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.ink,
        contentTextStyle: InkType.body(tokens.isDark ? InkColors.inkLight : InkColors.inkDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkRadii.dialog),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(InkRadii.bottomSheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InkRadii.menu),
          side: BorderSide(color: tokens.glassStroke),
        ),
        textStyle: InkType.body(tokens.ink),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
      ),
      dividerTheme: DividerThemeData(color: tokens.glassStroke, thickness: 1),
      extensions: [tokens],
    );
  }

  static TextTheme _textTheme(InkTokens tokens) {
    return TextTheme(
      displayLarge: InkType.display(tokens.ink),
      displayMedium: InkType.headline(tokens.ink),
      displaySmall: InkType.title(tokens.ink),
      headlineLarge: InkType.headline(tokens.ink),
      headlineMedium: InkType.title(tokens.ink),
      headlineSmall: InkType.cardTitle(tokens.ink),
      titleLarge: InkType.title(tokens.ink),
      titleMedium: InkType.cardTitle(tokens.ink),
      titleSmall: InkType.label(tokens.ink),
      bodyLarge: InkType.body(tokens.ink),
      bodyMedium: InkType.body(tokens.ink),
      bodySmall: InkType.caption(tokens.inkMuted),
      labelLarge: InkType.bodyStrong(tokens.ink),
      labelMedium: InkType.label(tokens.ink),
      labelSmall: InkType.caption(tokens.inkMuted),
    );
  }
}

extension InkContextX on BuildContext {
  InkTokens get ink => Theme.of(this).extension<InkTokens>()!;
}
