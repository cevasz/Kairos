import 'dart:convert';
import 'dart:io';

import 'package:kairos/core/db/daos/subjects_dao.dart';
import 'package:kairos/core/db/database.dart';
import 'package:kairos/core/providers.dart';
import 'package:kairos/features/import/application/import_controller.dart';
import 'package:kairos/features/import/data/column_schedule_parser.dart';
import 'package:kairos/features/import/data/pdf_text.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// El bug que se reportó: «se demora bastante importando y solo fueron 3
/// materias». El horario real trae salones como «Lab. de Física Mecánica y
/// Eléctrica» (35 letras); la columna aceptaba 20, así que el guardado
/// reventaba en la tercera materia, dejaba las dos primeras y media, y la
/// pantalla se quedaba girando para siempre.
void main() {
  late KairosDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = KairosDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  List<PositionedLine> fixture() => [
        for (final e in jsonDecode(File('test/fixtures/horario_santo_tomas.json').readAsStringSync()) as List)
          PositionedLine(
            text: normalizeSpaces(e['s'] as String),
            left: (e['l'] as num).toDouble(),
            right: (e['r'] as num).toDouble(),
            top: (e['t'] as num).toDouble(),
            pageIndex: e['p'] as int,
          ),
      ];

  test('el horario real se guarda completo: 7 materias, 18 clases', () async {
    final sub = container.listen(importControllerProvider, (_, __) {});
    addTearDown(sub.close);
    final ctrl = container.read(importControllerProvider.notifier);

    ctrl.startReview(ColumnScheduleParser.parse(fixture()));
    await ctrl.confirm();

    final state = container.read(importControllerProvider);
    expect(state, isA<ImportDone>());
    expect((state as ImportDone).subjects, 7);
    expect(state.sessions, 18);

    final subjects = await db.select(db.subjects).get();
    expect(subjects, hasLength(7));
    final rooms = await db.select(db.rooms).get();
    expect(rooms.map((r) => r.codigo), contains('Lab. de Física Mecánica y Eléctrica'));
  });

  test('si el guardado falla no queda nada a medias y se dice', () async {
    // La tercera materia revienta, como pasaba con el salón largo.
    final failing = _FailingOnThird(db);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      subjectsDaoProvider.overrideWithValue(failing),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(importControllerProvider, (_, __) {});
    addTearDown(sub.close);
    final ctrl = c.read(importControllerProvider.notifier);

    ctrl.startReview(ColumnScheduleParser.parse(fixture()));
    await ctrl.confirm();

    final state = c.read(importControllerProvider);
    expect(state, isA<ImportFailed>());
    expect((state as ImportFailed).reason, ImportFailure.saveFailed);
    expect(await db.select(db.subjects).get(), isEmpty, reason: 'la transacción deshace las dos primeras');
    expect(await db.select(db.classSessions).get(), isEmpty);
  });
}

class _FailingOnThird extends SubjectsDao {
  _FailingOnThird(super.db);
  int _calls = 0;

  @override
  Future<int> createSubject({
    required String nombre,
    required int colorIndex,
    required int limiteFaltas,
    String? profesor,
    int? creditos,
    DateTime? fechaLimiteCancelacion,
  }) {
    if (++_calls == 3) throw StateError('falla simulada');
    return super.createSubject(
      nombre: nombre,
      colorIndex: colorIndex,
      limiteFaltas: limiteFaltas,
      profesor: profesor,
      creditos: creditos,
      fechaLimiteCancelacion: fechaLimiteCancelacion,
    );
  }
}
