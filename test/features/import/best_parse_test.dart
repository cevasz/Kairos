import 'dart:convert';
import 'dart:io';

import 'package:kairos/features/import/application/import_controller.dart';
import 'package:kairos/features/import/data/column_schedule_parser.dart';
import 'package:kairos/features/import/data/pdf_text.dart';
import 'package:kairos/features/import/data/time_grid_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('con el horario real de la Santo Tomás gana la retícula de siempre', () {
    final lines = [
      for (final e in jsonDecode(File('test/fixtures/horario_santo_tomas.json').readAsStringSync()) as List)
        PositionedLine(
          text: normalizeSpaces(e['s'] as String),
          left: (e['l'] as num).toDouble(),
          top: (e['t'] as num).toDouble(),
          right: (e['r'] as num).toDouble(),
          pageIndex: e['p'] as int,
        ),
    ];
    final column = ColumnScheduleParser.parse(lines);
    final timeGrid = TimeGridParser.parse(lines);
    expect(timeGrid, isEmpty, reason: 'las casillas traen su hora: no es una retícula por filas');
    final best = bestParse([column, timeGrid]);
    expect(best, same(column));
    expect(best.length, 7);
  });

  test('una lectura vacía nunca gana', () {
    expect(bestParse([const [], const []]), isEmpty);
  });
}
