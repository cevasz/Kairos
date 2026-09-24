import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/core/db/daos/subjects_dao.dart';
import 'package:kairos/core/db/database.dart';

void main() {
  test('el periodo se corre: siempre hay 12 semanas de bloques por delante', () async {
    final db = KairosDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final subjectId = await db.subjectsDao.createSubject(nombre: 'Gimnasio', colorIndex: 0, limiteFaltas: 3);
    final sessionId = await db.subjectsDao.saveSession(
      subjectId: subjectId,
      diaSemana: 1,
      horaInicio: 6 * 60,
      horaFin: 7 * 60,
    );
    Future<DateTime> last() async {
      final rows = await (db.select(db.sessionInstances)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.desc(t.fecha)]))
          .get();
      return rows.first.fecha;
    }

    final semester = await db.subjectsDao.ensureActiveSemester();
    final first = await last();
    // Medio año después, sin haber tocado nada: los lunes siguen existiendo.
    final later = semester.fechaInicio.add(const Duration(days: 180));
    await db.subjectsDao.rollHorizon(later);
    final extended = await last();
    expect(extended.isAfter(first), isTrue);
    expect(extended.difference(later).inDays, greaterThanOrEqualTo(kDefaultSemesterWeeks * 7 - 7));

    // Llamarlo otra vez el mismo día no duplica nada.
    final count = (await db.select(db.sessionInstances).get()).length;
    await db.subjectsDao.rollHorizon(later);
    expect((await db.select(db.sessionInstances).get()).length, count);
  });
}
