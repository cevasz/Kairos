import 'dart:ui';

import 'package:kairos/theme/palette.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wheelSamples = [
    Palettes.fromWheel(paper: const Color(0xFF3F7A55), accent: const Color(0xFFF2D46B)),
    Palettes.fromWheel(paper: const Color(0xFFE91E63), accent: const Color(0xFF00BCD4)),
    Palettes.fromWheel(paper: const Color(0xFF808080), accent: const Color(0xFF808080)),
    Palettes.fromWheel(paper: const Color(0xFFFFFF00), accent: const Color(0xFFFFFF00)),
  ];

  for (final palette in [...Palettes.presets, ...wheelSamples]) {
    for (final b in Brightness.values) {
      test('${palette.name} (${palette.id}) en ${b.name} se lee', () {
        final base = palette.color('surfaceBase', b);
        final card = palette.color('surfaceCard', b);
        double on(String role, Color bg) => PaletteMath.contrast(palette.color(role, b), bg);

        expect(on('textPrimary', base), greaterThanOrEqualTo(7), reason: 'texto principal');
        expect(on('textPrimary', card), greaterThanOrEqualTo(7), reason: 'texto sobre tarjeta');
        expect(on('textSecondary', base), greaterThanOrEqualTo(4.5), reason: 'texto secundario');
        expect(on('textTertiary', base), greaterThanOrEqualTo(3), reason: 'texto terciario');
        expect(on('accentPrimary', base), greaterThanOrEqualTo(3), reason: 'acento sobre el fondo');
        expect(on('accentUrgent', base), greaterThanOrEqualTo(3), reason: 'urgente sobre el fondo');
        expect(
          PaletteMath.contrast(palette.color('textOnAccent', b), palette.color('accentPrimary', b)),
          greaterThanOrEqualTo(4.5),
          reason: 'texto de los botones',
        );
        expect(PaletteMath.isDark(base), b == Brightness.dark, reason: 'el modo se nota en el fondo');
      });
    }
  }

  test('Papiro es el contrato: no tiene resolver', () {
    expect(Palettes.resolve(Palettes.papiro), isNull);
    expect(Palettes.resolve('pizarra')?.name, 'Pizarra');
    expect(Palettes.resolve(Palettes.custom), isNull, reason: 'propio sin colores cae a Papiro');
  });

  test('un tema instalado cambia los tokens y quitarlo los devuelve', () {
    addTearDown(() => ThemedColor.palette = null);
    final before = ColorTokens.surfaceBase.of(Brightness.dark);
    ThemedColor.palette = Palettes.resolve('pizarra');
    expect(ColorTokens.surfaceBase.of(Brightness.dark), const Color(0xFF2B4333));
    ThemedColor.palette = null;
    expect(ColorTokens.surfaceBase.of(Brightness.dark), before);
  });

  test('un color de la rueda en una materia se guarda tal cual', () {
    const argb = 0xFF3F7A55;
    expect(SubjectPalette.isCustom(argb), isTrue);
    expect(SubjectPalette.at(argb), const Color(argb));
    expect(SubjectPalette.at(3), SubjectPalette.values[3]);
  });

  test('HSL ida y vuelta', () {
    const c = Color(0xFF3F7A55);
    final back = Hsl.of(c).toColor();
    expect((back.r - c.r).abs(), lessThan(0.01));
    expect((back.g - c.g).abs(), lessThan(0.01));
    expect((back.b - c.b).abs(), lessThan(0.01));
  });
}
