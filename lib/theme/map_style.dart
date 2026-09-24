import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Los mosaicos de OpenStreetMap son de otro mundo visual: blanco frío,
/// verdes y azules saturados. Pegados al hueso y al café de Kairós parecen
/// una captura de otra app.
///
/// Aquí se tiñen con una matriz de color que sale del contrato: se quita casi
/// toda la saturación y el rango de luz se remapea entre dos colores del tema.
/// En oscuro, además, se invierte, así el fondo del mapa es `surface.base` y
/// las calles quedan claras como el texto secundario.
abstract final class MapTileStyle {
  /// Cuánta saturación sobrevive. En oscuro casi nada: al invertir, el verde de
  /// bosques y parques se vuelve violeta y rompe la paleta café.
  static const double _saturationDark = 0.08;
  static const double _saturationLight = 0.55;

  static ColorFilter filter(Brightness b) {
    if (b == Brightness.dark) {
      return ColorFilter.matrix(_compose(
        _remap(ColorTokens.surfaceBase.dark, ColorTokens.textSecondary.dark),
        _compose(_saturation(_saturationDark), _invert),
      ));
    }
    return ColorFilter.matrix(_compose(
      _remap(ColorTokens.textPrimary.light, ColorTokens.surfaceCard.light),
      _saturation(_saturationLight),
    ));
  }

  /// Para `TileLayer.tileBuilder`.
  static Widget tileBuilder(BuildContext context, Widget tile, Object _) =>
      ColorFiltered(colorFilter: filter(Theme.of(context).brightness), child: tile);

  // ── Álgebra de matrices 4×5 (la forma que pide ColorFilter.matrix) ──────

  static const List<double> _invert = [
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0,
  ];

  /// Luminancia Rec. 709, la misma que usa la fórmula de contraste.
  static List<double> _saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    return [
      lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0, //
      lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0, //
      lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

  /// 0 → `low`, 255 → `high`, canal por canal.
  static List<double> _remap(Color low, Color high) {
    double ch(double c) => c * 255;
    List<double> row(double lo, double hi, int i) => [
          for (var j = 0; j < 3; j++) j == i ? (hi - lo) / 255 : 0.0,
          0,
          lo,
        ];
    return [
      ...row(ch(low.r), ch(high.r), 0),
      ...row(ch(low.g), ch(high.g), 1),
      ...row(ch(low.b), ch(high.b), 2),
      0, 0, 0, 1, 0,
    ];
  }

  /// `a ∘ b`: primero `b`, después `a`.
  static List<double> _compose(List<double> a, List<double> b) {
    double at(List<double> m, int r, int c) => r == 4 ? (c == 4 ? 1 : 0) : m[r * 5 + c];
    return [
      for (var r = 0; r < 4; r++)
        for (var c = 0; c < 5; c++)
          (() {
            var sum = 0.0;
            for (var k = 0; k < 5; k++) {
              sum += at(a, r, k) * at(b, k, c);
            }
            return sum;
          })(),
    ];
  }
}
