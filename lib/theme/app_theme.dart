import 'package:flutter/material.dart';

import 'tokens.g.dart';
import 'transitions.dart';

/// Construye el ThemeData de Material 3 desde el contrato. Ningún color, tamaño
/// o radio aparece aquí como literal: todo sale de tokens.g.dart.
abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: ColorTokens.accentPrimary.of(b),
      onPrimary: ColorTokens.textOnAccent.of(b),
      secondary: ColorTokens.accentOk.of(b),
      onSecondary: ColorTokens.textOnAccent.of(b),
      error: ColorTokens.accentUrgent.of(b),
      onError: ColorTokens.textOnUrgent.of(b),
      surface: ColorTokens.surfaceBase.of(b),
      onSurface: ColorTokens.textPrimary.of(b),
      surfaceContainerHighest: ColorTokens.surfaceRaised.of(b),
      onSurfaceVariant: ColorTokens.textSecondary.of(b),
      outline: ColorTokens.surfaceBorder.of(b),
      outlineVariant: ColorTokens.surfaceBorder.of(b),
      tertiary: ColorTokens.accentAttention.of(b),
      onTertiary: ColorTokens.textOnAccent.of(b),
      scrim: ColorTokens.surfaceScrim.of(b),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: ColorTokens.surfaceBase.of(b),
      fontFamily: FontFamilies.sans,
      textTheme: _textTheme(b),

      // Una sola transición de ruta para todas las plataformas: la del
      // contrato, no la de cada sistema.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeRiseTransitionsBuilder(),
          TargetPlatform.iOS: FadeRiseTransitionsBuilder(),
          TargetPlatform.linux: FadeRiseTransitionsBuilder(),
          TargetPlatform.macOS: FadeRiseTransitionsBuilder(),
          TargetPlatform.windows: FadeRiseTransitionsBuilder(),
        },
      ),

      cardTheme: CardThemeData(
        color: ColorTokens.surfaceCard.of(b),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          side: BorderSide(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: ColorTokens.surfaceBase.of(b),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: styleOf(TypeTokens.titleL, ColorTokens.textPrimary.of(b)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColorTokens.accentPrimary.of(b),
          foregroundColor: ColorTokens.textOnAccent.of(b),
          textStyle: styleOf(TypeTokens.bodyL, ColorTokens.textOnAccent.of(b)).copyWith(
            fontWeight: FontWeight.w600,
          ),
          padding: EdgeInsets.all(ComponentTokens.buttonPadding),
          minimumSize: Size.fromHeight(ComponentTokens.buttonMinTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.control),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorTokens.textPrimary.of(b),
          textStyle: styleOf(TypeTokens.bodyL, ColorTokens.textPrimary.of(b)),
          padding: EdgeInsets.all(ComponentTokens.buttonPadding),
          minimumSize: Size.fromHeight(ComponentTokens.buttonMinTouchTarget),
          side: BorderSide(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.control),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: EdgeInsets.symmetric(
          vertical: ComponentTokens.inputPaddingV,
          horizontal: ComponentTokens.inputPaddingH,
        ),
        hintStyle: styleOf(TypeTokens.bodyL, ColorTokens.textTertiary.of(b)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.control),
          borderSide: BorderSide(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.control),
          borderSide: BorderSide(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.control),
          borderSide: BorderSide(color: ColorTokens.accentPrimary.of(b), width: BorderTokens.hairline),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ColorTokens.surfaceCard.of(b),
        // En tablet un sheet a todo lo ancho es una cortina; se acota al
        // ancho de contenido y queda centrado.
        constraints: const BoxConstraints(maxWidth: LayoutTokens.contentMaxWidth),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(RadiusTokens.sheet)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ColorTokens.surfaceCard.of(b),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        // 12 + 26 de padding, más el icono, el hueco y la etiqueta: los cinco
        // números están en `layout.tabBar` del contrato.
        height: LayoutTokens.tabBarPaddingTop +
            LayoutTokens.tabBarPaddingBottom +
            LayoutTokens.tabBarIconSize +
            LayoutTokens.tabBarGapIconLabel +
            LayoutTokens.tabBarLabelSize,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return styleOf(
            TypeTokens.captionS,
            selected ? ColorTokens.accentPrimary.of(b) : ColorTokens.textTertiary.of(b),
          ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: LayoutTokens.tabBarIconSize,
            color: selected ? ColorTokens.accentPrimary.of(b) : ColorTokens.textTertiary.of(b),
          );
        }),
      ),

      // Los dos controles de Ajustes. Sin esto M3 pinta el segmento elegido
      // con `secondaryContainer`, que aquí cae en el verde del semáforo.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? ColorTokens.surfaceRaised.of(b)
                  : ColorTokens.surfaceCard.of(b)),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? ColorTokens.accentPrimary.of(b)
                  : ColorTokens.textSecondary.of(b)),
          side: WidgetStatePropertyAll(
            BorderSide(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusTokens.control)),
          ),
          textStyle: WidgetStatePropertyAll(
            styleOf(TypeTokens.bodyS, ColorTokens.textPrimary.of(b)),
          ),
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: ColorTokens.accentPrimary.of(b),
        inactiveTrackColor: ColorTokens.surfaceBorder.of(b),
        thumbColor: ColorTokens.accentPrimary.of(b),
        overlayColor: ColorTokens.accentPrimary.of(b).withValues(alpha: 0.12),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        valueIndicatorColor: ColorTokens.surfaceRaised.of(b),
        valueIndicatorTextStyle: styleOf(TypeTokens.captionS, ColorTokens.textPrimary.of(b)),
      ),

      // El riel de tablet habla el mismo idioma que la barra inferior: sin
      // píldora de color, el estado activo es el ámbar del icono y la etiqueta.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: ColorTokens.surfaceCard.of(b),
        indicatorColor: ColorTokens.surfaceRaised.of(b),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.card),
        ),
        minWidth: LayoutTokens.railWidth,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: styleOf(TypeTokens.captionS, ColorTokens.accentPrimary.of(b))
            .copyWith(fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: styleOf(TypeTokens.captionS, ColorTokens.textTertiary.of(b)),
        selectedIconTheme: IconThemeData(
          size: LayoutTokens.tabBarIconSize,
          color: ColorTokens.accentPrimary.of(b),
        ),
        unselectedIconTheme: IconThemeData(
          size: LayoutTokens.tabBarIconSize,
          color: ColorTokens.textTertiary.of(b),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: ColorTokens.surfaceBorder.of(b),
        thickness: BorderTokens.hairline,
        space: BorderTokens.hairline,
      ),
    );
  }

  /// Traduce un paso de la escala a TextStyle. `tabular-nums` va activado en
  /// todos: el contrato lo pide para horas, notas y contadores, y activarlo de
  /// más no cambia nada en texto sin dígitos.
  static TextStyle styleOf(TypeToken t, Color color) => TextStyle(
        fontFamily: t.family,
        fontSize: t.size,
        height: t.height,
        letterSpacing: t.letterSpacing,
        fontWeight: FontWeight.values[(t.weight ~/ 100) - 1],
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextTheme _textTheme(Brightness b) {
    final primary = ColorTokens.textPrimary.of(b);
    final secondary = ColorTokens.textSecondary.of(b);
    return TextTheme(
      displayLarge: styleOf(TypeTokens.displayL, primary),
      displayMedium: styleOf(TypeTokens.displayM, primary),
      titleLarge: styleOf(TypeTokens.titleL, primary),
      titleMedium: styleOf(TypeTokens.titleM, primary),
      titleSmall: styleOf(TypeTokens.titleS, primary),
      bodyLarge: styleOf(TypeTokens.bodyL, primary),
      bodyMedium: styleOf(TypeTokens.bodyM, secondary),
      bodySmall: styleOf(TypeTokens.bodyS, secondary),
      labelLarge: styleOf(TypeTokens.caption, secondary),
      labelMedium: styleOf(TypeTokens.captionS, secondary),
      labelSmall: styleOf(TypeTokens.label, secondary),
    );
  }
}

/// Azúcar para leer la escala desde un widget sin repetir `Theme.of(context)`.
extension TypeScaleX on BuildContext {
  TextStyle type(TypeToken t, {Color? color}) => AppTheme.styleOf(
        t,
        color ?? ColorTokens.textPrimary.of(Theme.of(this).brightness),
      );

  Color themed(ThemedColor c) => c.of(Theme.of(this).brightness);
}
