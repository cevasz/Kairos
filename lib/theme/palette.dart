import 'dart:math' as math;
import 'dart:ui';

import 'tokens.g.dart';

/// Tres colores bastan para un tema en un modo: el papel, la tinta y el
/// acento. Lo demás (tarjetas, bordes, textos secundarios) se deriva con
/// reglas que garantizan el contraste (§48).
class PaletteSeeds {
  const PaletteSeeds({
    required this.base,
    required this.ink,
    required this.accent,
    this.urgent,
    this.ok,
    this.attention,
  });

  final Color base;
  final Color ink;
  final Color accent;

  /// Semáforo propio del tema. Null: el del contrato, que ya está probado
  /// sobre fondos claros y oscuros.
  final Color? urgent;
  final Color? ok;
  final Color? attention;
}

/// Un tema completo, en claro y en oscuro. Todos los temas existen en los dos
/// modos: quien elige «Pizarra» y el modo oscuro ve la pizarra de noche, no
/// el Papiro oscuro.
class AppPalette implements PaletteResolver {
  AppPalette._(this.id, this.name, this._light, this._dark, this.subjects);

  factory AppPalette.fromSeeds({
    required String id,
    required String name,
    required PaletteSeeds light,
    required PaletteSeeds dark,
    List<Color>? subjects,
  }) =>
      AppPalette._(id, name, _derive(light, isDark: false), _derive(dark, isDark: true), subjects);

  final String id;
  final String name;
  final Map<String, Color> _light;
  final Map<String, Color> _dark;

  @override
  final List<Color>? subjects;

  @override
  Color? resolve(String role, Brightness b) => (b == Brightness.dark ? _dark : _light)[role];

  /// El color de [role] en [b], con el del contrato si el tema no lo trae.
  Color color(String role, Brightness b) => resolve(role, b)!;

  static Map<String, Color> _derive(PaletteSeeds s, {required bool isDark}) {
    Color contract(ThemedColor c) => isDark ? c.dark : c.light;
    final base = s.base;
    final ink = s.ink;
    final card = isDark ? PaletteMath.shiftLightness(base, 0.045) : Color.lerp(base, const Color(0xFFFFFFFF), 0.6)!;
    final raised = isDark ? PaletteMath.shiftLightness(base, 0.09) : PaletteMath.shiftLightness(base, -0.045);
    final accent = PaletteMath.withContrast(s.accent, against: base, min: 3);
    return {
      'surfaceBase': base,
      'surfaceCard': card,
      'surfaceRaised': raised,
      'surfaceBorder': Color.lerp(base, ink, isDark ? 0.2 : 0.15)!,
      'surfaceScrim': (isDark ? base : ink).withValues(alpha: isDark ? 0.55 : 0.35),
      'surfaceWidget': card.withValues(alpha: 0.96),
      'surfaceAmbientWarmNight': base,
      'surfaceAmbientNeutralNoon': base,
      'accentPrimary': accent,
      'accentUrgent': PaletteMath.withContrast(s.urgent ?? contract(ColorTokens.accentUrgent), against: base, min: 3),
      'accentOk': PaletteMath.withContrast(s.ok ?? contract(ColorTokens.accentOk), against: base, min: 3),
      'accentAttention':
          PaletteMath.withContrast(s.attention ?? contract(ColorTokens.accentAttention), against: base, min: 3),
      'textPrimary': ink,
      // Lo más cerca del fondo que siga leyéndose: 4,5 para el secundario y 3
      // para el terciario (etiquetas y pies).
      'textSecondary': PaletteMath.fadeToward(ink, base, max: 0.4, minContrast: 4.5),
      'textTertiary': PaletteMath.fadeToward(ink, base, max: 0.6, minContrast: 3),
      'textOnAccent': PaletteMath.bestOn(accent, [ink, base, const Color(0xFF15110E), const Color(0xFFFFFFFF)]),
      'textOnSubject': contract(ColorTokens.textOnSubject),
      'textOnUrgent': contract(ColorTokens.textOnUrgent),
    };
  }
}

/// Contraste y luminosidad, en Dart puro. Las reglas son las de WCAG 2.
abstract final class PaletteMath {
  static double _channel(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double luminance(Color c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

  static double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static bool isDark(Color c) => luminance(c) < 0.18;

  /// Mueve la luminosidad HSL en [delta] (−1..1), sin tocar tono ni saturación.
  static Color shiftLightness(Color c, double delta) {
    final hsl = Hsl.of(c);
    return hsl.copyWith(lightness: (hsl.lightness + delta).clamp(0.0, 1.0)).toColor(alpha: c.a);
  }

  /// [c] tal cual si ya contrasta [min] contra [against]; si no, se aclara u
  /// oscurece (lo que aleje del fondo) hasta que contraste.
  static Color withContrast(Color c, {required Color against, required double min}) {
    if (contrast(c, against) >= min) return c;
    final step = isDark(against) ? 0.02 : -0.02;
    var out = c;
    for (var i = 0; i < 50 && contrast(out, against) < min; i++) {
      out = shiftLightness(out, step);
    }
    return out;
  }

  /// La mezcla de [ink] hacia [base] más apagada (hasta [max]) que todavía
  /// contrasta [minContrast] contra el fondo.
  static Color fadeToward(Color ink, Color base, {required double max, required double minContrast}) {
    for (var t = max; t > 0; t -= 0.02) {
      final c = Color.lerp(ink, base, t)!;
      if (contrast(c, base) >= minContrast) return c;
    }
    return ink;
  }

  /// De [candidates], el que mejor se lee sobre [bg].
  static Color bestOn(Color bg, List<Color> candidates) =>
      candidates.reduce((a, b) => contrast(a, bg) >= contrast(b, bg) ? a : b);
}

/// Tono (0..360), saturación y luminosidad (0..1).
class Hsl {
  const Hsl(this.hue, this.saturation, this.lightness);

  factory Hsl.of(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final l = (maxC + minC) / 2;
    final d = maxC - minC;
    if (d == 0) return Hsl(0, 0, l);
    final s = d / (1 - (2 * l - 1).abs());
    double h;
    if (maxC == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (maxC == g) {
      h = 60 * (((b - r) / d) + 2);
    } else {
      h = 60 * (((r - g) / d) + 4);
    }
    return Hsl((h + 360) % 360, s.clamp(0.0, 1.0), l);
  }

  final double hue;
  final double saturation;
  final double lightness;

  Hsl copyWith({double? hue, double? saturation, double? lightness}) =>
      Hsl(hue ?? this.hue, saturation ?? this.saturation, lightness ?? this.lightness);

  Color toColor({double alpha = 1}) {
    final c = (1 - (2 * lightness - 1).abs()) * saturation;
    final hp = (hue % 360) / 60;
    final x = c * (1 - (hp % 2 - 1).abs());
    final (r1, g1, b1) = switch (hp.floor()) {
      0 => (c, x, 0.0),
      1 => (x, c, 0.0),
      2 => (0.0, c, x),
      3 => (0.0, x, c),
      4 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    final m = lightness - c / 2;
    return Color.from(alpha: alpha, red: r1 + m, green: g1 + m, blue: b1 + m);
  }
}

/// Los temas prediseñados. «Papiro» es el contrato tal cual: su resolver es
/// null y cada color sale de tokens.json, como siempre.
abstract final class Palettes {
  static const String papiro = 'papiro';
  static const String custom = 'propio';

  /// Con qué abre el tema propio la primera vez: la pizarra de Concepts.
  static const Color defaultPaper = Color(0xFF3F7A55);
  static const Color defaultAccent = Color(0xFFF0D264);

  static final List<AppPalette> presets = [
    AppPalette.fromSeeds(
      id: 'pizarra',
      name: 'Pizarra',
      light: const PaletteSeeds(base: Color(0xFFECF1EA), ink: Color(0xFF1D2B22), accent: Color(0xFF2F6B47)),
      // La pizarra verde de noche, con tiza crema y amarilla.
      dark: const PaletteSeeds(base: Color(0xFF2B4333), ink: Color(0xFFF2EBCB), accent: Color(0xFFF0D264)),
    ),
    AppPalette.fromSeeds(
      id: 'tinta',
      name: 'Tinta',
      light: const PaletteSeeds(base: Color(0xFFF3F5F9), ink: Color(0xFF151D2E), accent: Color(0xFF2D57A0)),
      dark: const PaletteSeeds(base: Color(0xFF0D121D), ink: Color(0xFFE3E8F4), accent: Color(0xFF8EAEEE)),
    ),
    AppPalette.fromSeeds(
      id: 'terracota',
      name: 'Terracota',
      light: const PaletteSeeds(base: Color(0xFFFAF0E8), ink: Color(0xFF36190F), accent: Color(0xFFA84A28)),
      dark: const PaletteSeeds(base: Color(0xFF1B100C), ink: Color(0xFFF3E1D4), accent: Color(0xFFE48D66)),
    ),
    AppPalette.fromSeeds(
      id: 'lavanda',
      name: 'Lavanda',
      light: const PaletteSeeds(base: Color(0xFFF4F1F9), ink: Color(0xFF261F35), accent: Color(0xFF6A4BA3)),
      dark: const PaletteSeeds(base: Color(0xFF14101C), ink: Color(0xFFEBE5F5), accent: Color(0xFFB7A0EA)),
    ),
    AppPalette.fromSeeds(
      id: 'musgo',
      name: 'Musgo',
      light: const PaletteSeeds(base: Color(0xFFF1F3EC), ink: Color(0xFF1F261C), accent: Color(0xFF4F6B3A)),
      dark: const PaletteSeeds(base: Color(0xFF121610), ink: Color(0xFFE5EADD), accent: Color(0xFFA9C28A)),
    ),
    AppPalette.fromSeeds(
      id: 'contraste',
      name: 'Alto contraste',
      light: const PaletteSeeds(base: Color(0xFFFFFFFF), ink: Color(0xFF000000), accent: Color(0xFF003D99)),
      dark: const PaletteSeeds(base: Color(0xFF000000), ink: Color(0xFFFFFFFF), accent: Color(0xFFFFD60A)),
    ),
  ];

  /// Un tema propio desde dos colores de la rueda: el del papel y el del
  /// acento. Del papel se toma el tono; claro y oscuro salen de ahí para que
  /// el tema funcione en los dos modos.
  static AppPalette fromWheel({required Color paper, required Color accent}) {
    final p = Hsl.of(paper);
    final a = Hsl.of(accent);
    final paperSat = math.min(p.saturation, 0.45);
    return AppPalette.fromSeeds(
      id: custom,
      name: 'Propio',
      light: PaletteSeeds(
        base: p.copyWith(saturation: paperSat * 0.8, lightness: 0.94).toColor(),
        ink: p.copyWith(saturation: paperSat * 0.6, lightness: 0.13).toColor(),
        accent: a.copyWith(lightness: math.min(a.lightness, 0.42)).toColor(),
      ),
      dark: PaletteSeeds(
        base: p.copyWith(saturation: paperSat * 0.6, lightness: 0.09).toColor(),
        ink: p.copyWith(saturation: paperSat * 0.4, lightness: 0.9).toColor(),
        accent: a.copyWith(lightness: math.max(a.lightness, 0.62)).toColor(),
      ),
    );
  }

  /// El tema para lo guardado en ajustes. Null: Papiro (el contrato).
  static AppPalette? resolve(String id, {int? paper, int? accent}) {
    if (id == custom && paper != null && accent != null) {
      return fromWheel(paper: Color(paper), accent: Color(accent));
    }
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}
