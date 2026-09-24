import 'package:kairos/core/db/daos/subjects_dao.dart';
import 'package:kairos/core/db/database.dart';
import 'package:kairos/core/providers.dart';
import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/import/parsed_schedule.dart';
import 'package:kairos/features/import/application/import_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// El bug que se reportó en Cátedra: «se demora bastante importando y solo
/// fueron 3». Un lugar de más de 20 letras reventaba el guardado a media
/// importación y la pantalla se quedaba girando para siempre.
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

  /// Una semana real de alguien: siete actividades, dieciocho bloques, y un
  /// lugar con nombre largo, que es lo que antes tumbaba el guardado.
  List<ParsedClass> week() {
    ParsedSession b(int dia, int h, [String? lugar]) =>
        ParsedSession(diaSemana: dia, inicio: MinutesOfDay.of(h, 0), fin: MinutesOfDay.of(h + 1, 0), salon: lugar);
    return [
      ParsedClass(nombre: 'Gimnasio', salon: 'Smart Fit 85', sessions: [b(1, 6), b(3, 6), b(5, 6)]),
      ParsedClass(nombre: 'Trabajo', salon: 'Oficina', sessions: [b(1, 9), b(2, 9), b(3, 9), b(4, 9), b(5, 9)]),
      ParsedClass(
        nombre: 'Terapia',
        profesor: 'Dra. Ruiz',
        sessions: [b(2, 17, 'Consultorio de Fisioterapia y Rehabilitación Integral')],
      ),
      ParsedClass(nombre: 'Inglés', salon: 'Colombo', sessions: [b(2, 18), b(4, 18)]),
      ParsedClass(nombre: 'Natación', salon: 'Piscina', sessions: [b(6, 8), b(7, 8)]),
      ParsedClass(nombre: 'Mercado', sessions: [b(6, 11)]),
      ParsedClass(nombre: 'Guitarra', profesor: 'Andrés', sessions: [b(1, 19), b(3, 19), b(5, 19), b(7, 17)]),
    ];
  }

  test('la semana se guarda completa: 7 actividades, 18 bloques', () async {
    final sub = container.listen(importControllerProvider, (_, __) {});
    addTearDown(sub.close);
    final ctrl = container.read(importControllerProvider.notifier);

    ctrl.startReview(week());
    await ctrl.confirm();

    final state = container.read(importControllerProvider);
    expect(state, isA<ImportDone>());
    expect((state as ImportDone).subjects, 7);
    expect(state.sessions, 18);

    final subjects = await db.select(db.subjects).get();
    expect(subjects, hasLength(7));
    final rooms = await db.select(db.rooms).get();
    expect(rooms.map((r) => r.codigo), contains('Consultorio de Fisioterapia y Rehabilitación Integral'));
  });

  test('si el guardado falla no queda nada a medias y se dice', () async {
    // La tercera actividad revienta, como pasaba con el lugar largo.
    final failing = _FailingOnThird(db);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      subjectsDaoProvider.overrideWithValue(failing),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(importControllerProvider, (_, __) {});
    addTearDown(sub.close);
    final ctrl = c.read(importControllerProvider.notifier);

    ctrl.startReview(week());
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
  }) {
    if (++_calls == 3) throw StateError('falla simulada');
    return super.createSubject(
      nombre: nombre,
      colorIndex: colorIndex,
      limiteFaltas: limiteFaltas,
      profesor: profesor,
    );
  }
}
