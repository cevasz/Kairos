// Generador del contrato diseño → código.
//
//   dart run tool/gen_tokens.dart
//
// Lee design/tokens.json y escribe:
//   lib/theme/tokens.g.dart   constantes tipadas (color, tipo, espacio, radio, motion, semáforo)
//   lib/l10n/strings.g.dart   microcopy en español desde el bloque `copy`
//
// Ninguno de los dos se edita a mano. Si el diseño cambia, se cambia tokens.json
// y se vuelve a correr esto. No depende de Flutter: es Dart puro sobre dart:io.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = Directory.current.path;
  final srcFile = File('$root/design/tokens.json');
  if (!srcFile.existsSync()) {
    stderr.writeln('No encuentro design/tokens.json. Corre esto desde la raíz del proyecto.');
    exit(1);
  }

  final tokens = jsonDecode(srcFile.readAsStringSync()) as Map<String, dynamic>;

  File('$root/lib/theme/tokens.g.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync(_buildTokens(tokens));

  File('$root/lib/domain/attendance/absence_state.g.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync(_buildAbsenceState(tokens['semaphore'] as Map<String, dynamic>));

  File('$root/lib/l10n/strings.g.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync(_buildStrings(tokens['copy'] as Map<String, dynamic>));

  // Los widgets de la pantalla de inicio son vistas nativas de Android: no
  // leen ColorTokens. Sus colores salen del mismo contrato, a recursos XML.
  final color = tokens['color'] as Map<String, dynamic>;
  File('$root/android/app/src/main/res/values/kairos_tokens.xml')
    ..createSync(recursive: true)
    ..writeAsStringSync(_buildAndroidColors(color, dark: false));
  File('$root/android/app/src/main/res/values-night/kairos_tokens.xml')
    ..createSync(recursive: true)
    ..writeAsStringSync(_buildAndroidColors(color, dark: true));

  // Los textos que el lanzador enseña al elegir un widget también son copy.
  File('$root/android/app/src/main/res/values/kairos_strings.xml')
    ..createSync(recursive: true)
    ..writeAsStringSync(_buildAndroidStrings(
      (tokens['copy'] as Map<String, dynamic>)['widgets'] as Map<String, dynamic>,
    ));

  stdout.writeln('Regenerados desde design/tokens.json:');
  stdout.writeln('  lib/theme/tokens.g.dart');
  stdout.writeln('  lib/domain/attendance/absence_state.g.dart  (Dart puro)');
  stdout.writeln('  lib/l10n/strings.g.dart');
  stdout.writeln('  android/app/src/main/res/values{,-night}/kairos_tokens.xml');
}

// ------------------------------------------------- colores de Android (widgets)

/// `#RRGGBB` o `rgba(...)` -> `#AARRGGBB`, que es lo que Android entiende.
String _androidColor(String raw) {
  final dart = _color(raw); // Color(0xAARRGGBB)
  return '#${dart.substring(8, 16)}';
}

String _buildAndroidColors(Map<String, dynamic> color, {required bool dark}) {
  final mode = dark ? 'dark' : 'light';
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- GENERADO por tool/gen_tokens.dart desde design/tokens.json. NO EDITAR A MANO. -->')
    ..writeln('<resources>');
  void add(String name, String raw) => b.writeln('    <color name="kairos_$name">${_androidColor(raw)}</color>');

  for (final group in ['surface', 'accent', 'text']) {
    final g = color[group] as Map<String, dynamic>;
    for (final e in g.entries) {
      if (_meta(e.key) || e.value is! Map) continue;
      final v = e.value as Map<String, dynamic>;
      final raw = v[mode];
      if (raw is! String) continue;
      add('${group}_${_snake(e.key)}', raw);
    }
  }
  final subjects = (color['subject'] as List).cast<Map<String, dynamic>>();
  for (var i = 0; i < subjects.length; i++) {
    add('subject_$i', subjects[i]['value'] as String);
  }
  b.writeln('</resources>');
  return b.toString();
}

/// Solo los textos del selector de widgets (`picker*`): lo demás lo pinta
/// Flutter o llega ya formateado en los datos del widget.
String _buildAndroidStrings(Map<String, dynamic> widgets) {
  String esc(String v) => v.replaceAll("'", r"\'").replaceAll('"', r'\"');
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- GENERADO por tool/gen_tokens.dart desde design/tokens.json. NO EDITAR A MANO. -->')
    ..writeln('<resources>');
  for (final e in widgets.entries) {
    if (!e.key.startsWith('picker') || e.value is! String) continue;
    b.writeln('    <string name="widget_${_snake(e.key)}">${esc(e.value as String)}</string>');
  }
  b.writeln('</resources>');
  return b.toString();
}

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');

// ---------------------------------------------------------------- utilidades

bool _meta(String key) => key.startsWith(r'$');

/// `surface.base` -> `surfaceBase`; `2xl` -> `xxl` (Dart no acepta identificadores
/// que empiecen por dígito).
String _camel(List<String> parts) {
  final cleaned = <String>[];
  for (final p in parts) {
    if (p.isEmpty) continue;
    cleaned.add(p);
  }
  var out = '';
  for (var i = 0; i < cleaned.length; i++) {
    var seg = cleaned[i];
    if (i == 0) {
      out = seg;
    } else {
      out += seg[0].toUpperCase() + seg.substring(1);
    }
  }
  // `2xl` y `3xl` no son identificadores válidos en Dart. Se deletrean:
  // 2xl -> xxl (dos equis), 3xl -> xxxl (tres equis).
  if (out.isNotEmpty && RegExp(r'^[0-9]').hasMatch(out)) {
    out = out.replaceFirst(RegExp(r'^2'), 'x').replaceFirst(RegExp(r'^3'), 'xx');
  }
  return out;
}

/// `#RRGGBB` o `rgba(r,g,b,a)` -> literal `Color(0xAARRGGBB)`.
String _color(String raw) {
  final v = raw.trim();
  if (v.startsWith('#')) {
    final hex = v.substring(1);
    if (hex.length == 6) return 'Color(0xFF${hex.toUpperCase()})';
    if (hex.length == 8) return 'Color(0x${hex.toUpperCase()})';
    throw FormatException('Color hex no soportado: $raw');
  }
  final m = RegExp(r'rgba?\(([^)]*)\)').firstMatch(v);
  if (m == null) throw FormatException('Color no reconocido: $raw');
  final parts = m.group(1)!.split(',').map((e) => e.trim()).toList();
  final r = int.parse(parts[0]);
  final g = int.parse(parts[1]);
  final b = int.parse(parts[2]);
  final a = parts.length > 3 ? double.parse(parts[3]) : 1.0;
  final ai = (a * 255).round().clamp(0, 255);
  String h2(int n) => n.toRadixString(16).padLeft(2, '0').toUpperCase();
  return 'Color(0x${h2(ai)}${h2(r)}${h2(g)}${h2(b)})';
}

/// `cubic-bezier(a, b, c, d)` -> `Cubic(a, b, c, d)`; `linear` -> `Curves.linear`.
String _curve(String raw) {
  if (raw.trim() == 'linear') return 'Curves.linear';
  final m = RegExp(r'cubic-bezier\(([^)]*)\)').firstMatch(raw);
  if (m == null) throw FormatException('Curva no reconocida: $raw');
  final n = m.group(1)!.split(',').map((e) => double.parse(e.trim())).toList();
  return 'Cubic(${n[0]}, ${n[1]}, ${n[2]}, ${n[3]})';
}

/// `-0.01em` -> tracking relativo. Flutter usa letterSpacing absoluto, así que
/// el multiplicador se resuelve contra el tamaño en el sitio de uso.
double _tracking(String raw) {
  final t = raw.trim();
  if (t == '0') return 0;
  return double.parse(t.replaceAll('em', ''));
}

/// `0 6px 18px rgba(0,0,0,0.40)` -> literal BoxShadow.
String _shadow(String raw) {
  final colorMatch = RegExp(r'rgba?\([^)]*\)').firstMatch(raw)!;
  final color = _color(colorMatch.group(0)!);
  final nums = RegExp(r'(-?\d+(?:\.\d+)?)px')
      .allMatches(raw.substring(0, colorMatch.start))
      .map((m) => double.parse(m.group(1)!))
      .toList();
  // `0 1px 2px` -> el primer 0 no lleva unidad, así que nums = [1, 2].
  final dx = nums.length >= 3 ? nums[0] : 0.0;
  final dy = nums.length >= 3 ? nums[1] : nums[0];
  final blur = nums.length >= 3 ? nums[2] : nums[1];
  return 'BoxShadow(offset: Offset($dx, $dy), blurRadius: $blur, color: $color)';
}

// ------------------------------------------------------------ tokens.g.dart

String _buildTokens(Map<String, dynamic> t) {
  final b = StringBuffer();
  final meta = t[r'$meta'] as Map<String, dynamic>;

  b.writeln('// GENERADO por tool/gen_tokens.dart desde design/tokens.json');
  b.writeln('// NO EDITAR A MANO. Corre: dart run tool/gen_tokens.dart');
  b.writeln('// Fuente: ${meta['name']} v${meta['version']}');
  b.writeln("//\n// ignore_for_file: unused_import\n");
  // painting.dart dejó de re-exportar Brightness de dart:ui, y ThemedColor.of
  // y las sombras lo piden. Se importa directo para no arrastrar material.dart.
  b.writeln("import 'dart:ui' show Brightness;\n");
  b.writeln("import 'package:flutter/animation.dart';");
  b.writeln("import 'package:flutter/painting.dart';");
  b.writeln("import '../domain/attendance/absence_state.g.dart';\n");
  b.writeln("export '../domain/attendance/absence_state.g.dart' show AbsenceState;\n");

  b.writeln(_themedColorClass());
  b.writeln(_typeTokenClass());

  _colors(b, t['color'] as Map<String, dynamic>);
  _typography(b, t['type'] as Map<String, dynamic>);
  _scalars(b, 'SpaceTokens', t['space'] as Map<String, dynamic>);
  _scalars(b, 'RadiusTokens', t['radius'] as Map<String, dynamic>);
  _scalars(b, 'BorderTokens', t['border'] as Map<String, dynamic>);
  _elevation(b, t['elevation'] as Map<String, dynamic>);
  _ring(b, t['ring'] as Map<String, dynamic>);
  _component(b, t['component'] as Map<String, dynamic>);
  _icon(b, t['icon'] as Map<String, dynamic>);
  _widgetSizes(b, t['widget'] as Map<String, dynamic>);
  _layout(b, t['layout'] as Map<String, dynamic>);
  _motion(b, t['motion'] as Map<String, dynamic>);
  _semaphore(b, t['semaphore'] as Map<String, dynamic>);
  _mascot(b, t['mascot'] as Map<String, dynamic>);
  _haptics(b, t['haptics'] as Map<String, dynamic>);

  return b.toString();
}

String _themedColorClass() => '''
/// Un color con su par oscuro/claro. El tema nunca escoge por su cuenta: pide
/// `of(brightness)` y el valor sale del contrato.
///
/// El par del contrato es el tema «Papiro». Otro tema (Personalizar, §48) se
/// instala en [palette] y responde por [role]; si no trae ese rol, manda el
/// contrato. Así los temas no tocan ni una pantalla.
class ThemedColor {
  const ThemedColor(this.dark, this.light, [this.role]);
  final Color dark;
  final Color light;

  /// Nombre del rol (`surfaceBase`, `accentPrimary`…). Null: no se tematiza.
  final String? role;

  /// El tema activo. Lo instala la app antes de construir el ThemeData.
  static PaletteResolver? palette;

  Color of(Brightness b) {
    final r = role;
    final themed = r == null ? null : palette?.resolve(r, b);
    return themed ?? (b == Brightness.dark ? dark : light);
  }
}

/// Un tema que sabe responder por rol. Null: que decida el contrato.
abstract interface class PaletteResolver {
  Color? resolve(String role, Brightness b);

  /// Colores de materia del tema, o null para los del contrato.
  List<Color>? get subjects;
}
''';

String _typeTokenClass() => '''
/// Un paso de la escala tipográfica. `tracking` viene en em desde el diseño;
/// `letterSpacing` lo resuelve contra el tamaño porque Flutter lo quiere absoluto.
class TypeToken {
  const TypeToken({
    required this.size,
    required this.weight,
    required this.height,
    required this.tracking,
    required this.family,
  });

  final double size;
  final int weight;
  final double height;
  final double tracking;
  final String family;

  double get letterSpacing => tracking * size;
}
''';

void _colors(StringBuffer b, Map<String, dynamic> color) {
  b.writeln('abstract final class ColorTokens {');

  for (final group in ['surface', 'accent', 'text']) {
    final map = color[group] as Map<String, dynamic>;
    for (final e in map.entries) {
      if (_meta(e.key)) continue;
      final v = e.value as Map<String, dynamic>;
      final name = _camel([group, e.key]);
      b.writeln("  static const $name = ThemedColor(${_color(v['dark'] as String)}, ${_color(v['light'] as String)}, '$name');");
    }
  }

  final mascot = color['mascot'] as Map<String, dynamic>;
  b.writeln();
  for (final e in mascot.entries) {
    if (_meta(e.key)) continue;
    b.writeln('  static const ${_camel(['mascot', e.key])} = ${_color(e.value as String)};');
  }

  final amb = color['ambient'] as Map<String, dynamic>;
  b.writeln();
  for (final phase in ['noon', 'night']) {
    final p = amb[phase] as Map<String, dynamic>;
    for (final k in ['base', 'card']) {
      b.writeln('  static const ${_camel(['ambient', phase, k])} = ${_color(p[k] as String)};');
    }
  }
  b.writeln('  static const ambientEnabledInLightTheme = ${amb['enabledInLightTheme']};');
  b.writeln('}\n');

  // Paleta de materias: lista const indexada. El índice vive en la BD.
  final subjects = (color['subject'] as List).cast<Map<String, dynamic>>();
  b.writeln('/// Los 8 colores de materia. El índice se guarda en la BD y es estable');
  b.writeln('/// entre sesiones y dispositivos: NUNCA se asigna al azar.');
  b.writeln('abstract final class SubjectPalette {');
  b.writeln('  static const List<Color> values = <Color>[');
  for (final s in subjects) {
    b.writeln('    ${_color(s['value'] as String)}, // ${s['name']}');
  }
  b.writeln('  ];\n');
  b.writeln('  static const List<String> names = <String>[');
  for (final s in subjects) {
    b.writeln("    '${s['name']}',");
  }
  b.writeln('  ];\n');
  b.writeln('  static int get length => values.length;\n');
  b.writeln('  /// Un color elegido en la rueda se guarda tal cual, como ARGB opaco');
  b.writeln('  /// (siempre ≥ 0xFF000000), en el mismo entero que el índice (§48).');
  b.writeln('  static const int customThreshold = 0xFF000000;\n');
  b.writeln('  static bool isCustom(int index) => index >= customThreshold;\n');
  b.writeln('  /// Normaliza cualquier entero a un índice válido, para no romper si');
  b.writeln('  /// la BD trae un valor viejo o fuera de rango. Un índice de la paleta');
  b.writeln('  /// toma el color del tema activo, si trae los suyos.');
  b.writeln('  static Color at(int index) {');
  b.writeln('    if (isCustom(index)) return Color(index);');
  b.writeln('    final themed = ThemedColor.palette?.subjects;');
  b.writeln('    final list = themed == null || themed.isEmpty ? values : themed;');
  b.writeln('    return list[index % list.length];');
  b.writeln('  }');
  b.writeln('}\n');
}

void _typography(StringBuffer b, Map<String, dynamic> type) {
  final fam = type[r'$family'] as Map<String, dynamic>;
  b.writeln('abstract final class FontFamilies {');
  b.writeln("  static const String sans = '${fam['sans']}';");
  b.writeln("  static const String mono = '${fam['mono']}';");
  b.writeln('}\n');

  b.writeln('abstract final class TypeTokens {');
  final names = <String>[];
  for (final e in type.entries) {
    if (_meta(e.key)) continue;
    final v = e.value as Map<String, dynamic>;
    final family = v['family'] == 'mono' ? 'FontFamilies.mono' : 'FontFamilies.sans';
    final size = (v['size'] as num).toDouble();
    final height = (v['lineHeight'] as num).toDouble();
    b.writeln('  static const ${e.key} = TypeToken(');
    b.writeln('    size: $size,');
    b.writeln('    weight: ${v['weight']},');
    b.writeln('    height: $height,');
    b.writeln('    tracking: ${_tracking(v['tracking'] as String)},');
    b.writeln('    family: $family,');
    b.writeln('  );');
    names.add(e.key);
  }
  b.writeln();
  b.writeln('  static const List<TypeToken> all = <TypeToken>[${names.join(', ')}];');
  b.writeln('}\n');
}

void _scalars(StringBuffer b, String className, Map<String, dynamic> map) {
  b.writeln('abstract final class $className {');
  for (final e in map.entries) {
    if (_meta(e.key)) continue;
    final name = _camel([e.key]);
    b.writeln('  static const double $name = ${(e.value as num).toDouble()};');
  }
  b.writeln('}\n');
}

void _elevation(StringBuffer b, Map<String, dynamic> elev) {
  b.writeln('abstract final class ElevationTokens {');
  for (final e in elev.entries) {
    if (_meta(e.key)) continue;
    final v = e.value as Map<String, dynamic>;
    b.writeln('  static const List<BoxShadow> ${e.key}Dark = <BoxShadow>[${_shadow(v['dark'] as String)}];');
    b.writeln('  static const List<BoxShadow> ${e.key}Light = <BoxShadow>[${_shadow(v['light'] as String)}];');
    b.writeln('  static List<BoxShadow> ${e.key}(Brightness b) =>');
    b.writeln('      b == Brightness.dark ? ${e.key}Dark : ${e.key}Light;');
  }
  b.writeln('}\n');
}

void _ring(StringBuffer b, Map<String, dynamic> ring) {
  b.writeln('abstract final class RingTokens {');
  for (final group in ['countdown', 'absences']) {
    final r = ring[group] as Map<String, dynamic>;
    for (final e in r.entries) {
      if (_meta(e.key) || e.value is! num) continue;
      b.writeln('  static const double ${_camel([group, e.key])} = ${(e.value as num).toDouble()};');
    }
  }
  final st = (ring['countdown'] as Map<String, dynamic>)['states'] as Map<String, dynamic>;
  for (final phase in ['normal', 'urgent']) {
    final s = st[phase] as Map<String, dynamic>;
    b.writeln('  static const double countdownRadius${phase[0].toUpperCase()}${phase.substring(1)} = ${(s['r'] as num).toDouble()};');
  }
  b.writeln('}\n');
}

void _component(StringBuffer b, Map<String, dynamic> c) {
  b.writeln('abstract final class ComponentTokens {');
  // Se recorren todos los grupos del bloque, no una lista fija: añadir un
  // componente al contrato no debe exigir tocar el generador.
  for (final group in c.keys.where((k) => !_meta(k))) {
    final g = c[group] as Map<String, dynamic>;
    for (final e in g.entries) {
      if (_meta(e.key) || e.value is! num) continue;
      b.writeln('  static const double ${_camel([group, e.key])} = ${(e.value as num).toDouble()};');
    }
  }
  b.writeln('}\n');
}

void _icon(StringBuffer b, Map<String, dynamic> icon) {
  b.writeln('abstract final class IconTokens {');
  b.writeln('  static const double strokeWidth = ${(icon['strokeWidth'] as num).toDouble()};');
  b.writeln('  static const double minTouchTarget = ${(icon['minTouchTarget'] as num).toDouble()};');
  final named = icon['named'] as Map<String, dynamic>;
  for (final e in named.entries) {
    if (_meta(e.key)) continue;
    b.writeln('  static const double ${_camel(['size', e.key])} = ${(e.value as num).toDouble()};');
  }
  b.writeln('}\n');
}

void _widgetSizes(StringBuffer b, Map<String, dynamic> w) {
  b.writeln('/// Medidas de los widgets de pantalla de inicio (Fase 5). Los widgets');
  b.writeln('/// no animan: el estado urgente se comunica con color y peso tipográfico.');
  b.writeln('abstract final class HomeWidgetTokens {');
  b.writeln('  static const double accentBorderLeft = ${(w['accentBorderLeft'] as num).toDouble()};');
  b.writeln('  static const bool animates = ${w['animates']};');
  final sizes = w['sizes'] as Map<String, dynamic>;
  for (final e in sizes.entries) {
    final s = e.value as Map<String, dynamic>;
    final key = e.key.replaceAll('x', 'by');
    for (final f in s.entries) {
      b.writeln('  static const double ${_camel(['size', key, f.key])} = ${(f.value as num).toDouble()};');
    }
  }
  b.writeln('}\n');
}

void _layout(StringBuffer b, Map<String, dynamic> layout) {
  b.writeln('abstract final class LayoutTokens {');
  final frame = layout['designFrame'] as Map<String, dynamic>;
  b.writeln('  /// Ancho al que se dibujó el diseño. Sirve para verificar densidad,');
  b.writeln('  /// no para escalar: la app es responsive.');
  b.writeln('  static const double designWidth = ${(frame['width'] as num).toDouble()};');
  b.writeln('  static const double designHeight = ${(frame['height'] as num).toDouble()};');
  for (final e in layout.entries) {
    if (_meta(e.key) || e.value is! num) continue;
    b.writeln('  static const double ${_camel([e.key])} = ${(e.value as num).toDouble()};');
  }
  final tab = layout['tabBar'] as Map<String, dynamic>;
  for (final e in tab.entries) {
    if (e.value is! num) continue;
    b.writeln('  static const double ${_camel(['tabBar', e.key])} = ${(e.value as num).toDouble()};');
  }
  final row = layout['timelineRow'] as Map<String, dynamic>;
  for (final e in row.entries) {
    if (e.value is! num) continue;
    b.writeln('  static const double ${_camel(['timelineRow', e.key])} = ${(e.value as num).toDouble()};');
  }
  b.writeln('}\n');
}

void _motion(StringBuffer b, Map<String, dynamic> motion) {
  final d = motion['durations'] as Map<String, dynamic>;
  b.writeln('abstract final class MotionDurations {');
  for (final e in d.entries) {
    if (_meta(e.key)) continue;
    b.writeln('  static const Duration ${e.key} = Duration(milliseconds: ${e.value});');
  }
  b.writeln('}\n');

  final c = motion['curves'] as Map<String, dynamic>;
  b.writeln('abstract final class MotionCurves {');
  for (final e in c.entries) {
    if (_meta(e.key)) continue;
    b.writeln('  static const Curve ${e.key} = ${_curve(e.value as String)};');
  }
  b.writeln('}\n');

  final s = motion['stagger'] as Map<String, dynamic>;
  b.writeln('abstract final class MotionStagger {');
  for (final e in s.entries) {
    if (_meta(e.key)) continue;
    b.writeln('  static const Duration ${e.key} = Duration(milliseconds: ${e.value});');
  }
  b.writeln('}\n');

  final o = motion['offsets'] as Map<String, dynamic>;
  b.writeln('abstract final class MotionOffsets {');
  for (final e in o.entries) {
    if (_meta(e.key)) continue;
    if (e.value is num) {
      b.writeln('  static const double ${e.key} = ${(e.value as num).toDouble()};');
    } else {
      final deg = double.parse((e.value as String).replaceAll('deg', ''));
      b.writeln('  static const double ${e.key}Degrees = $deg;');
      b.writeln('  static const double ${e.key}Radians = ${deg * 3.141592653589793 / 180};');
    }
  }
  b.writeln('}\n');

  final rm = motion['reducedMotion'] as Map<String, dynamic>;
  b.writeln('abstract final class ReducedMotion {');
  b.writeln('  static const Duration duration = Duration(milliseconds: ${rm['duration']});');
  b.writeln('  static const List<String> disabled = <String>[');
  for (final n in (rm['disable'] as List)) {
    b.writeln("    '$n',");
  }
  b.writeln('  ];');
  b.writeln('}\n');
}

/// El enum y los umbrales viven en el dominio (Dart puro). Aquí solo va lo que
/// necesita Flutter: el color y la insignia de cada estado.
void _semaphore(StringBuffer b, Map<String, dynamic> sem) {
  b.writeln('abstract final class SemaphoreTokens {');
  b.writeln('  static const Map<AbsenceState, ThemedColor> color = <AbsenceState, ThemedColor>{');
  for (final raw in (sem['thresholds'] as List)) {
    final s = raw as Map<String, dynamic>;
    final colorRef = _camel((s['color'] as String).split('.'));
    b.writeln('    AbsenceState.${s['state']}: ColorTokens.$colorRef,');
  }
  b.writeln('  };\n');
  b.writeln('  static const Map<AbsenceState, String?> badge = <AbsenceState, String?>{');
  for (final raw in (sem['thresholds'] as List)) {
    final s = raw as Map<String, dynamic>;
    final badge = s['badge'] == null ? 'null' : "'${s['badge']}'";
    b.writeln('    AbsenceState.${s['state']}: $badge,');
  }
  b.writeln('  };\n');
  b.writeln('  static const Map<AbsenceState, String> copyTemplate = <AbsenceState, String>{');
  for (final raw in (sem['thresholds'] as List)) {
    final s = raw as Map<String, dynamic>;
    b.writeln("    AbsenceState.${s['state']}: ${_dartString(s['copy'] as String)},");
  }
  b.writeln('  };\n');
  b.writeln('  /// El texto del estado, con el hueco `{n}` resuelto. La plantilla es');
  b.writeln('  /// literal del contrato: aquí no se inventa ni se pluraliza a mano.');
  b.writeln('  static String copy(AbsenceState state, Object n) =>');
  b.writeln("      copyTemplate[state]!.replaceAll('{n}', '\$n');\n");
  b.writeln("  static const AbsenceState shakeOnEnter = AbsenceState.${sem['shakeOnEnter']};");
  b.writeln('}\n');
}

/// Tercer archivo generado: Dart PURO, sin un solo import de Flutter. El dominio
/// depende de esto y de nada más, para que la lógica de faltas sea testeable
/// sin binding de Flutter.
String _buildAbsenceState(Map<String, dynamic> sem) {
  final b = StringBuffer();
  b.writeln('// GENERADO por tool/gen_tokens.dart desde design/tokens.json');
  b.writeln('// NO EDITAR A MANO. Dart puro: este archivo no importa Flutter.\n');
  b.writeln('enum AbsenceState { ok, attention, risk, lost }\n');
  b.writeln('/// Umbrales como fracción del límite, no como conteo: `limite_faltas`');
  b.writeln('/// varía por materia.');
  b.writeln('abstract final class AbsenceThresholds {');
  for (final raw in (sem['thresholds'] as List)) {
    final s = raw as Map<String, dynamic>;
    final to = s['toRatio'] == null ? 'null' : (s['toRatio'] as num).toDouble().toString();
    b.writeln('  static const double ${s['state']}From = ${(s['fromRatio'] as num).toDouble()};');
    b.writeln('  static const double? ${s['state']}To = $to;');
  }
  b.writeln('}\n');
  return b.toString();
}

void _mascot(StringBuffer b, Map<String, dynamic> m) {
  b.writeln('enum MascotPose {');
  for (final p in (m['poses'] as List)) {
    b.writeln('  $p,');
  }
  b.writeln('}\n');

  final blink = (m['blinkIntervalMs'] as List).cast<num>();
  b.writeln('abstract final class MascotTokens {');
  b.writeln('  static const MascotPose defaultPose = MascotPose.${m['defaultPose']};');
  b.writeln('  static const Duration blinkMin = Duration(milliseconds: ${blink[0]});');
  b.writeln('  static const Duration blinkMax = Duration(milliseconds: ${blink[1]});');
  b.writeln('  static const double smallThreshold = ${(m['smallThreshold'] as num).toDouble()};');
  b.writeln('  static const int spikesNormal = ${(m['spikes'] as Map)['normal']};');
  b.writeln('  static const int spikesSmall = ${(m['spikes'] as Map)['small']};');
  b.writeln('  /// Segunda capa de agujas, más cortas, entre las de fuera. Solo a tamaño normal.');
  b.writeln('  static const int spikesFront = ${(m['spikes'] as Map)['front']};');
  b.writeln('  /// Una de cada tantas sentencias o toques es una ocurrencia.');
  b.writeln('  static const int anticEveryTaps = ${m['anticEveryTaps']};');
  b.writeln('  /// Ventana en la que [dizzyTaps] toques seguidos lo marean.');
  b.writeln('  static const Duration pokeWindow = Duration(milliseconds: ${m['pokeWindowMs']});');
  b.writeln('  static const int dizzyTaps = ${m['dizzyTaps']};');
  b.writeln('  /// Cuánto se mueve cada reacción, en unidades del lienzo de 100×100 o en');
  b.writeln('  /// fracciones. La geometría del dibujo no está aquí; el movimiento, sí.');
  for (final e in (m['motion'] as Map<String, dynamic>).entries) {
    if (_meta(e.key)) continue;
    b.writeln('  static const double ${e.key} = ${(e.value as num).toDouble()};');
  }
  b.writeln('  /// Amplitudes de los micro-movimientos. Las duraciones van en');
  b.writeln('  /// MotionDurations; aquí solo cuánto se mueve cada cosa.');
  b.writeln('  static const double breatheScaleMax = ${((m['breatheScale'] as List)[1] as num).toDouble()};');
  for (final k in ['enterScale', 'sleepScale', 'glanceOffset', 'wobbleDegrees', 'squashScale']) {
    if (m[k] is num) {
      b.writeln('  static const double $k = ${(m[k] as num).toDouble()};');
    }
  }
  b.writeln('  /// Pantallas donde MascotView tiene permiso de existir. La lista está');
  b.writeln('  /// en el contrato, no en el criterio de quien escriba el widget.');
  b.writeln('  static const List<String> allowedScreens = <String>[');
  for (final s in (m['allowedScreens'] as List)) {
    b.writeln("    '$s',");
  }
  b.writeln('  ];');
  b.writeln('  static const List<String> forbiddenScreens = <String>[');
  for (final s in (m['forbiddenScreens'] as List)) {
    b.writeln("    '$s',");
  }
  b.writeln('  ];\n');
  b.writeln('  /// Tamaños a los que el diseño dibujó la mascota, por pantalla. Ningún');
  b.writeln('  /// widget inventa el suyo: si una pantalla necesita otro, va al contrato.');
  for (final e in (m['sizesUsed'] as Map<String, dynamic>).entries) {
    b.writeln('  static const double ${_camel(['size', e.key])} = ${(e.value as num).toDouble()};');
  }
  b.writeln('}\n');
}

void _haptics(StringBuffer b, Map<String, dynamic> h) {
  b.writeln('enum HapticWeight { light, medium, heavy }\n');
  b.writeln('abstract final class HapticTokens {');
  for (final level in ['light', 'medium', 'heavy']) {
    b.writeln('  static const List<String> $level = <String>[');
    for (final a in (h[level] as List)) {
      b.writeln("    '$a',");
    }
    b.writeln('  ];');
  }
  b.writeln('  static const List<String> never = <String>[');
  for (final a in (h['never'] as List)) {
    b.writeln("    '$a',");
  }
  b.writeln('  ];');
  b.writeln('}');
}

// ----------------------------------------------------------- strings.g.dart

String _buildStrings(Map<String, dynamic> copy) {
  final b = StringBuffer();
  b.writeln('// GENERADO por tool/gen_tokens.dart desde el bloque `copy` de design/tokens.json');
  b.writeln('// NO EDITAR A MANO. El microcopy es del prototipo: no se inventan textos.\n');

  for (final group in copy.entries) {
    if (_meta(group.key)) continue;
    final name = group.key[0].toUpperCase() + group.key.substring(1);
    b.writeln('abstract final class S$name {');
    final map = group.value as Map<String, dynamic>;
    for (final e in map.entries) {
      if (_meta(e.key)) continue;
      if (e.value is List) {
        // Una lista son variantes de la misma frase: Erizógenes no repite
        // siempre lo mismo. Si alguna lleva huecos, la lista se vuelve una
        // función con la unión de los huecos y devuelve las variantes llenas.
        final list = (e.value as List).cast<String>();
        final holders = {
          for (final v in list) ...RegExp(r'\{(\w+)\}').allMatches(v).map((m) => m.group(1)!),
        }.toList();
        String fill(String v) {
          var body = _dartString(v);
          for (final h in holders) {
            body = body.replaceAll('{$h}', '\$$h');
          }
          return body;
        }

        final items = list.map(fill).join(', ');
        if (holders.isEmpty) {
          b.writeln('  static const List<String> ${e.key} = <String>[$items];');
        } else {
          final params = holders.map((h) => 'required Object $h').join(', ');
          b.writeln('  static List<String> ${e.key}({$params}) => <String>[$items];');
        }
        continue;
      }
      final value = e.value as String;
      final holders = RegExp(r'\{(\w+)\}')
          .allMatches(value)
          .map((m) => m.group(1)!)
          .toSet()
          .toList();
      if (holders.isEmpty) {
        b.writeln("  static const String ${e.key} = ${_dartString(value)};");
      } else {
        final params = holders.map((h) => 'required Object $h').join(', ');
        var body = _dartString(value);
        for (final h in holders) {
          body = body.replaceAll('{$h}', '\$$h');
        }
        b.writeln('  static String ${e.key}({$params}) => $body;');
      }
    }
    b.writeln('}\n');
  }
  return b.toString();
}

/// Cadena Dart segura: comillas simples, escapando `\`, `'` y `$` literales.
/// Los `{placeholder}` se sustituyen después por interpolaciones reales.
String _dartString(String v) {
  final escaped = v
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}
