@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La auditoría del contrato, automatizada.
///
/// La regla «ningún literal de color, tipografía, espaciado, radio o duración
/// dentro de un widget» solo se sostiene si algo la comprueba. Revisarla a mano
/// funcionó una vez; a la tercera pantalla nueva se escapa una.
///
/// Este test lee el código de `lib/features` como texto. No es elegante, pero
/// es la única forma de verificar una regla que trata sobre cómo está escrito
/// el código y no sobre lo que hace.
///
/// Si un caso legítimo choca con una regla, la salida es añadirlo a la lista de
/// excepciones **con su razón**, no ablandar el patrón.

/// Rutas que el guardia no mira, con el porqué de cada una.
const _exemptions = <String, String>{
  // La rueda de color es una ilustración con geometría propia (radios de
  // anillo, grosor de cada paso) y el texto de cada muestra se pinta en negro
  // o blanco según la muestra, que no es un color del tema.
  'lib/features/customize/presentation/widgets/copic_wheel.dart':
      'CustomPainter: geometría de la rueda y tinta según cada muestra',
  // Un tema dibujado en miniatura, a escala: sus medidas son del dibujo, no
  // espaciado de interfaz, y sus colores son los del tema que se muestra.
  'lib/features/customize/presentation/widgets/theme_tile.dart':
      'Miniatura a escala de un tema: medidas del dibujo',
  // Dibuja un erizo. Las coordenadas de un trazo no son espaciado de interfaz:
  // son la ilustración misma, y no hay token que las pueda nombrar.
  'lib/features/mascot/mascot_view.dart':
      'CustomPainter: geometría de la ilustración, no medidas de UI',
  // Escribe los datos de los widgets nativos. Su única duración es la espera
  // para agrupar escrituras seguidas, que tampoco es movimiento.
  'lib/features/widgets/home_widget_sync.dart':
      'Debounce de escritura a disco: no es una animación',
};

/// Cada regla es un patrón y el nombre de lo que protege.
const _rules = <({String name, String pattern, String fix})>[
  (
    name: 'color literal',
    pattern: r'Color\(0x|Colors\.(?!transparent)[a-zA-Z]+|Color\.from(RGBO|ARGB)',
    fix: 'usa ColorTokens',
  ),
  (
    name: 'tamaño de fuente literal',
    pattern: r'fontSize:\s*[0-9]',
    fix: 'usa TypeTokens con context.type()',
  ),
  (
    name: 'radio literal',
    pattern: r'(BorderRadius|Radius)\.circular\(\s*[0-9]',
    fix: 'usa RadiusTokens',
  ),
  (
    name: 'espaciado literal',
    pattern: r'EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*\b[0-9]+(\.[0-9]+)?\b',
    fix: 'usa SpaceTokens',
  ),
  (
    name: 'duración literal',
    pattern: r'Duration\(\s*(milliseconds|seconds)\s*:\s*[0-9]',
    fix: 'usa MotionDurations o MotionStagger',
  ),
];

/// Las líneas de comentario no son código: un ejemplo dentro de un `///` no es
/// una infracción, y prohibirlo haría imposible documentar la regla.
bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

void main() {
  late List<File> sources;

  setUpAll(() {
    final dir = Directory('lib/features');
    sources = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !_exemptions.containsKey(f.path))
        .toList();
  });

  test('hay código de features que revisar', () {
    // Si un cambio de estructura deja la lista vacía, el resto de este archivo
    // pasaría sin comprobar nada. Mejor fallar aquí.
    expect(sources, isNotEmpty);
  });

  test('las exenciones apuntan a archivos que existen', () {
    for (final path in _exemptions.keys) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'Exención obsoleta para $path: bórrala de _exemptions.',
      );
    }
  });

  for (final rule in _rules) {
    test('sin ${rule.name} en el código de pantalla', () {
      final regex = RegExp(rule.pattern);
      final offenders = <String>[];

      for (final file in sources) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_isComment(lines[i])) continue;
          if (regex.hasMatch(lines[i])) {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Un literal en código de UI es un bug, no una preferencia. '
            '${rule.fix}.\n${offenders.join('\n')}',
      );
    });
  }

  test('el dominio no importa Flutter', () {
    final domain = Directory('lib/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final offenders = <String>[];
    for (final file in domain) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains("import 'package:flutter/")) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'lib/domain es Dart puro para poder probarse sin binding.\n'
          '${offenders.join('\n')}',
    );
  });

  test('los .g.dart no se editan a mano', () {
    final generated = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.g.dart'));

    expect(generated, isNotEmpty);
    for (final file in generated) {
      // `GENERADO` lo escribe tool/gen_tokens.dart; `GENERATED`, drift_dev.
      final head = file.readAsLinesSync().take(4).join('\n').toUpperCase();
      expect(
        head.contains('GENERADO') || head.contains('GENERATED'),
        isTrue,
        reason: '${file.path} no declara que es generado en su cabecera.',
      );
    }
  });
}
