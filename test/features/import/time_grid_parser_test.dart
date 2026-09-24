import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/features/import/data/pdf_text.dart';
import 'package:kairos/features/import/data/time_grid_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una línea en (x, y). El ancho sale del largo del texto, a 6 pt por letra.
PositionedLine _l(String text, double x, double y, {int page = 0}) =>
    PositionedLine(text: text, left: x, top: y, right: x + text.length * 6, pageIndex: page);

void main() {
  // Columnas: horas en x=20, Lunes 120, Martes 220, Miércoles 320.
  List<PositionedLine> grid({bool oneLineHeader = false, List<PositionedLine> extra = const []}) => [
        if (oneLineHeader)
          _l('Hora         Lunes          Martes         Miércoles', 20, 10)
        else ...[
          _l('Hora', 20, 10),
          _l('Lunes', 120, 10),
          _l('Martes', 220, 10),
          _l('Miércoles', 320, 10),
        ],
        _l('7:00', 20, 40),
        _l('8:00', 20, 70),
        _l('9:00', 20, 100),
        _l('10:00', 20, 130),
        _l('11:00', 20, 160),
        _l('12:00', 20, 190),
        _l('1:00', 20, 220),
        // Cálculo lunes y miércoles 7-9, con aula.
        _l('Cálculo I', 110, 40),
        _l('Aula 301', 110, 50),
        _l('Cálculo I', 110, 70),
        _l('Cálculo I', 310, 40),
        _l('Cálculo I', 310, 70),
        // Física martes 8-10, con profesor.
        _l('Física', 215, 70),
        _l('Prof. Ramírez', 205, 80),
        _l('Física', 215, 100),
        // Inglés lunes 12-1 y 1-2 (tarde sin p.m.).
        _l('Inglés', 115, 190),
        _l('Inglés', 115, 220),
        ...extra,
      ];

  test('lee la retícula por horas: días por X, horas por Y', () {
    final classes = TimeGridParser.parse(grid());
    final byName = {for (final c in classes) c.nombre: c};
    expect(byName.keys, containsAll(['Cálculo I', 'Física', 'Inglés']));

    final calc = byName['Cálculo I']!;
    expect(calc.sessions.map((s) => s.diaSemana), [1, 3]);
    expect(calc.sessions.first.inicio, MinutesOfDay.of(7, 0));
    expect(calc.sessions.first.fin, MinutesOfDay.of(9, 0), reason: 'dos filas seguidas son una sola clase');
    expect(calc.sessions.first.salon, '301');

    final fis = byName['Física']!;
    expect(fis.sessions.single.diaSemana, 2);
    expect(fis.sessions.single.inicio, MinutesOfDay.of(8, 0));
    expect(fis.sessions.single.fin, MinutesOfDay.of(10, 0));
    expect(fis.profesor, 'Ramírez');

    final ing = byName['Inglés']!.sessions.single;
    expect(ing.inicio, MinutesOfDay.of(12, 0));
    expect(ing.fin, MinutesOfDay.of(14, 0), reason: 'la 1:00 que retrocede es de la tarde');
    expect(classes.every((c) => !c.isLowConfidence), isTrue);
  });

  test('también con los días en una sola línea', () {
    final classes = TimeGridParser.parse(grid(oneLineHeader: true));
    expect(classes.map((c) => c.nombre), containsAll(['Cálculo I', 'Física']));
  });

  test('etiquetas con rango «7:00 - 8:30» fijan el fin', () {
    final classes = TimeGridParser.parse([
      _l('Lunes', 120, 10),
      _l('Martes', 220, 10),
      _l('7:00 - 8:30', 10, 40),
      _l('8:30 - 10:00', 10, 70),
      _l('Química', 110, 40),
      _l('Química', 210, 70),
    ]);
    final q = classes.single;
    expect(q.sessions.first.fin, MinutesOfDay.of(8, 30));
    expect(q.sessions.last.inicio, MinutesOfDay.of(8, 30));
    expect(q.sessions.last.fin, MinutesOfDay.of(10, 0));
  });

  test('sin encabezado de días o sin horas no inventa nada', () {
    expect(TimeGridParser.parse([_l('Cálculo lunes 7-9', 10, 10)]), isEmpty);
    expect(TimeGridParser.parse([_l('Lunes', 120, 10), _l('Martes', 220, 10), _l('Cálculo', 110, 40)]), isEmpty);
  });
}
