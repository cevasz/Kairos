import 'dart:convert';
import 'dart:io';

import 'package:kairos/domain/import/schedule_parser.dart';
import 'package:kairos/features/import/data/column_schedule_parser.dart';
import 'package:kairos/features/import/data/pdf_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// El fixture son las líneas con posición que Syncfusion saca del horario real
/// de un estudiante de la Santo Tomás (PACR42), anonimizado. Se guarda ya
/// extraído para que el test no dependa del PDF ni de la librería de PDF: lo
/// que se prueba aquí es el parser, no el extractor.
List<PositionedLine> _fixture(String name) {
  final raw = File('test/fixtures/$name.json').readAsStringSync();
  return [
    for (final e in jsonDecode(raw) as List)
      PositionedLine(
        text: normalizeSpaces(e['s'] as String),
        left: (e['l'] as num).toDouble(),
        right: (e['r'] as num).toDouble(),
        top: (e['t'] as num).toDouble(),
        pageIndex: e['p'] as int,
      ),
  ];
}

/// `[(día, inicio, fin, salón)]` de una materia, para comparar de un vistazo.
List<String> _schedule(ParsedClass c) => [
      for (final s in c.sessions) '${s.diaSemana} ${s.inicio.hhmm}-${s.fin.hhmm} ${s.salon}',
    ];

void main() {
  group('ColumnScheduleParser · horario real Santo Tomás', () {
    late List<ParsedClass> classes;

    setUpAll(() {
      classes = ColumnScheduleParser.parse(_fixture('horario_santo_tomas'));
    });

    test('encuentra las siete materias y ninguna de más', () {
      // El orden es el de aparición en la retícula: la celda que cierra
      // primero es la de las 7 am del martes. Es estable entre pasadas.
      expect(classes.map((c) => c.nombre).toList(), [
        'LENGUA EXTRANJERA IV',
        'BASES DE DATOS NOSQL',
        'FISICA MECANICA',
        'CALCULO VECTORIAL',
        'DESARROLLO EMPRESARIAL',
        'ALGEBRA LINEAL',
        'METODOS NUMERICOS',
      ]);
    });

    test('no se cuela el texto de la cabecera ni el nombre de la sede', () {
      final nombres = classes.map((c) => c.nombre.toLowerCase()).join(' | ');
      expect(nombres, isNot(contains('universidad')));
      expect(nombres, isNot(contains('domingo')));
      expect(nombres, isNot(contains('guzm')));
      expect(nombres, isNot(contains('periodo')));
      expect(nombres, isNot(contains('20262')));
    });

    test('las 18 sesiones caen de lunes a viernes', () {
      final sessions = classes.expand((c) => c.sessions).toList();
      expect(sessions, hasLength(18));
      expect(sessions.map((s) => s.diaSemana).toSet(), {1, 2, 3, 4, 5});
    });

    test('ninguna materia queda marcada con dudas', () {
      for (final c in classes) {
        expect(c.doubts, isEmpty, reason: '${c.nombre} tiene dudas: ${c.doubts}');
      }
    });

    test('FISICA MECANICA: tres días y el laboratorio del martes', () {
      final c = classes.firstWhere((c) => c.nombre == 'FISICA MECANICA');
      expect(c.codigo, '96112');
      expect(_schedule(c), [
        '1 9:00-11:00 606F',
        '2 9:00-11:00 Lab. de Física Mecánica y Eléctrica',
        '3 9:00-11:00 511F',
      ]);
    });

    test('BASES DE DATOS NOSQL: tres salas distintas, una por día', () {
      final c = classes.firstWhere((c) => c.nombre == 'BASES DE DATOS NOSQL');
      expect(c.codigo, '41151');
      expect(_schedule(c), [
        '2 11:00-13:00 Sala de Sistemas 2E',
        '4 7:00-9:00 Sala de Sistemas 1F',
        '5 7:00-9:00 Sala de sistemas 4E',
      ]);
    });

    test('DESARROLLO EMPRESARIAL: la tarde del miércoles cruza el mediodía', () {
      final c = classes.firstWhere((c) => c.nombre == 'DESARROLLO EMPRESARIAL');
      expect(_schedule(c), [
        '1 16:00-18:00 Sala de Sistemas 2E',
        '3 14:00-16:00 Sala de IT and Big Data - 5E',
        '5 14:00-16:00 Sala de IT and Big Data - 5E',
      ]);
    });

    test('CALCULO VECTORIAL: 11 am-1 pm se lee como 11:00-13:00', () {
      final c = classes.firstWhere((c) => c.nombre == 'CALCULO VECTORIAL');
      expect(_schedule(c), [
        '1 11:00-13:00 610F',
        '3 11:00-13:00 510F',
        '4 11:00-13:00 401F',
      ]);
    });

    test('ALGEBRA LINEAL y METODOS NUMERICOS, dos días cada una', () {
      expect(_schedule(classes.firstWhere((c) => c.nombre == 'ALGEBRA LINEAL')), [
        '2 14:00-16:00 509F',
        '4 14:00-16:00 510F',
      ]);
      expect(_schedule(classes.firstWhere((c) => c.nombre == 'METODOS NUMERICOS')), [
        '2 16:00-18:00 406F',
        '4 16:00-18:00 209E',
      ]);
    });

    test('LENGUA EXTRANJERA IV: el nombre se arma de dos líneas', () {
      final c = classes.firstWhere((c) => c.codigo == '15653');
      expect(c.nombre, 'LENGUA EXTRANJERA IV');
      expect(_schedule(c), ['2 7:00-9:00 302E', '3 7:00-9:00 508F']);
    });

    test('el detalle aporta docente y créditos de cada código', () {
      final porCodigo = {for (final c in classes) c.codigo: c};
      expect(porCodigo['15653']!.profesor, 'LOPES VILLAS BOAS PALOMA ALINE');
      expect(porCodigo['30115']!.profesor, 'CARRILLO CHAPARRO JOSE ALBERTO');
      expect(porCodigo['40748']!.profesor, 'CONTRERAS ORTIZ MARTHA SUSANA');
      expect(porCodigo['41151']!.profesor, 'SOLER GALINDO HARRIZON ALEXANDER');
      // Fila que el PDF imprime entera en una línea, con el docente al final.
      expect(porCodigo['96112']!.profesor, 'SEGURA PENA SULLY');
      expect(porCodigo['96115']!.profesor, 'PABON CACHOPE LUZ ADRIANA');

      expect(porCodigo['15653']!.creditos, 2);
      expect(porCodigo['96112']!.creditos, 3);
      expect(porCodigo['96103']!.creditos, 2);
      expect(porCodigo['40748']!.creditos, 3);
    });

    test('el salón de la materia es el que más se repite', () {
      final c = classes.firstWhere((c) => c.nombre == 'DESARROLLO EMPRESARIAL');
      expect(c.salon, 'Sala de IT and Big Data - 5E');
    });

    test('es determinista: dos pasadas dan lo mismo', () {
      final otra = ColumnScheduleParser.parse(_fixture('horario_santo_tomas'));
      expect(otra.map(_schedule), classes.map(_schedule));
      expect(otra.map((c) => c.nombre), classes.map((c) => c.nombre));
    });
  });

  group('ColumnScheduleParser · cuándo no aplica', () {
    test('sin líneas devuelve vacío', () {
      expect(ColumnScheduleParser.parse(const []), isEmpty);
    });

    test('un PDF sin encabezado de días devuelve vacío y no lanza', () {
      final lines = [
        for (var i = 0; i < 5; i++)
          PositionedLine(
            text: 'Bases de datos Martes 10:00-12:00',
            left: 40,
            right: 300,
            top: 100.0 + i * 12,
            pageIndex: 0,
          ),
      ];
      expect(ColumnScheduleParser.parse(lines), isEmpty);
    });

    test('«Domingo de Guzmán» en una celda no crea una columna de domingo', () {
      // Dos días en el encabezado y la sede repetida abajo: si el detector
      // tomara la palabra suelta como encabezado, todo caería en domingo.
      final lines = [
        _line('LUNES', 100, 160, 50),
        _line('MARTES', 200, 260, 50),
        _line('Cod. 111', 100, 140, 70),
        _line('ALGO', 100, 140, 80),
        _line('Grupo. A', 100, 140, 90),
        _line('Aula. 101', 100, 140, 100),
        _line('Domingo de Guzmán', 100, 160, 110),
        _line('7:00 am-9:00 am', 100, 160, 120),
      ];
      final out = ColumnScheduleParser.parse(lines);
      expect(out, hasLength(1));
      expect(out.single.sessions.single.diaSemana, 1);
      expect(out.single.nombre, 'ALGO');
    });
  });

  group('ColumnScheduleParser · encabezado con una línea por día', () {
    test('usa la X de cada línea del encabezado', () {
      final lines = [
        _line('LUNES', 100, 150, 50),
        _line('MARTES', 200, 250, 50),
        _line('Cod. 10', 100, 140, 70),
        _line('CALCULO', 100, 140, 80),
        _line('Grupo. A', 100, 140, 90),
        _line('Aula. 201', 100, 140, 100),
        _line('7:00-9:00', 100, 140, 110),
        _line('Cod. 20', 200, 240, 70),
        _line('FISICA', 200, 240, 80),
        _line('Grupo. B', 200, 240, 90),
        _line('14:00-16:00', 200, 240, 110),
      ];
      final out = ColumnScheduleParser.parse(lines);
      expect(out.map((c) => c.nombre), ['CALCULO', 'FISICA']);
      expect(out[0].sessions.single.diaSemana, 1);
      expect(out[0].sessions.single.salon, '201');
      expect(out[1].sessions.single.diaSemana, 2);
      expect(out[1].sessions.single.salon, isNull);
    });
  });
}

PositionedLine _line(String text, double left, double right, double top) =>
    PositionedLine(text: text, left: left, right: right, top: top, pageIndex: 0);
