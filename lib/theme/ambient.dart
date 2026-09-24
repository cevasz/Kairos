import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Temperatura del fondo según la hora. Mueve solo las superficies: el texto y
/// los acentos no se tocan. La transición corre en 20 minutos, así que nunca se
/// percibe como animación.
///
/// Solo corre en tema oscuro: sobre el hueso del tema claro un +4 % cálido vira
/// a amarillo sucio y el prototipo nunca lo dibujó.
abstract final class Ambient {
  /// 0.0 = mediodía neutro, 1.0 = noche cálida.
  static double warmthAt(DateTime now) {
    final h = now.hour + now.minute / 60.0;
    // Pico de calidez a medianoche, neutro a mediodía.
    final distanceFromNoon = (h - 12).abs() / 12.0;
    return distanceFromNoon.clamp(0.0, 1.0);
  }

  /// El contrato apaga la temperatura ambiental en claro. Se consulta el token
  /// en vez de codificar la decisión aquí, para que reactivarla sea un cambio
  /// de tokens.json y no de código.
  ///
  /// Con otro tema que Papiro no corre: la temperatura está afinada para el
  /// café del contrato y sobre otro fondo lo mancharía.
  static bool enabledFor(Brightness b) =>
      ThemedColor.palette == null && (b == Brightness.dark || ColorTokens.ambientEnabledInLightTheme);

  static Color base(Brightness b, DateTime now) {
    if (!enabledFor(b)) return ColorTokens.surfaceBase.of(b);
    return Color.lerp(
      ColorTokens.ambientNoonBase,
      ColorTokens.ambientNightBase,
      warmthAt(now),
    )!;
  }

  static Color card(Brightness b, DateTime now) {
    if (!enabledFor(b)) return ColorTokens.surfaceCard.of(b);
    return Color.lerp(
      ColorTokens.ambientNoonCard,
      ColorTokens.ambientNightCard,
      warmthAt(now),
    )!;
  }
}
