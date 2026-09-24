import 'package:kairos/theme/map_style.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aplica una matriz 4×5 de ColorFilter a un color, como lo haría el motor.
List<int> _apply(ColorFilter f, List<int> rgb) {
  // ColorFilter.matrix no expone la matriz; se reconstruye por toString.
  final m = RegExp(r'-?\d+(\.\d+)?(e-?\d+)?')
      .allMatches(f.toString().split('matrix')[1])
      .map((e) => double.parse(e.group(0)!))
      .toList();
  final v = [...rgb.map((e) => e.toDouble()), 255.0];
  return [
    for (var r = 0; r < 3; r++)
      (m[r * 5] * v[0] + m[r * 5 + 1] * v[1] + m[r * 5 + 2] * v[2] + m[r * 5 + 3] * v[3] + m[r * 5 + 4])
          .round()
          .clamp(0, 255),
  ];
}

List<int> _rgb(Color c) => [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()];

void main() {
  test('en oscuro, el blanco del mapa se vuelve el fondo de la app', () {
    final out = _apply(MapTileStyle.filter(Brightness.dark), [255, 255, 255]);
    expect(out, _rgb(ColorTokens.surfaceBase.dark));
  });

  test('en claro, el blanco del mapa se vuelve el blanco cálido de las cards', () {
    final out = _apply(MapTileStyle.filter(Brightness.light), [255, 255, 255]);
    expect(out, _rgb(ColorTokens.surfaceCard.light));
  });
}
