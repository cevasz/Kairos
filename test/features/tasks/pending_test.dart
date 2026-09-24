import 'package:kairos/core/db/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KairosDatabase db;
  final today = DateTime(2026, 9, 22);

  setUp(() async {
    db = KairosDatabase.forTesting(NativeDatabase.memory());
    final semester = await db.subjectsDao.ensureActiveSemester();
    for (final (nombre, cancelada) in [('Física', false), ('Química', false), ('Arte', true)]) {
      await db.into(db.subjects).insert(SubjectsCompanion.insert(
            semesterId: semester.id,
            nombre: nombre,
            colorIndex: 0,
            cancelada: Value(cancelada),
          ));
    }
  });

  tearDown(() => db.close());

  Future<void> eval(int subjectId, String nombre, DateTime? fecha, {double? nota}) =>
      db.into(db.evaluations).insert(EvaluationsCompanion.insert(
            subjectId: subjectId,
            nombre: nombre,
            porcentaje: 0.3,
            nota: Value(nota),
            fecha: Value(fecha),
          ));

  test('pendientes: tareas abiertas y evaluaciones sin nota desde hoy, por fecha', () async {
    final dao = db.tasksDao;
    await dao.addTask(subjectId: 1, titulo: 'Leer cap. 4');
    await dao.addTask(subjectId: 2, titulo: 'Taller 3', fecha: DateTime(2026, 9, 25));
    final hecha = await dao.addTask(subjectId: 1, titulo: 'Ya hecha', fecha: DateTime(2026, 9, 23));
    await dao.setDone(hecha, done: true);
    await dao.addTask(subjectId: 3, titulo: 'De materia cancelada', fecha: DateTime(2026, 9, 23));

    await eval(1, 'Parcial 1', DateTime(2026, 9, 24));
    await eval(1, 'Quiz ya pasado', DateTime(2026, 9, 20));
    await eval(2, 'Parcial calificado', DateTime(2026, 9, 26), nota: 4.2);
    await eval(2, 'Parcial de hoy', today);

    final items = await dao.watchPending(today).first;
    expect(items.map((i) => i.titulo), ['Parcial de hoy', 'Parcial 1', 'Taller 3', 'Leer cap. 4']);
    expect(items.first.isEvaluation, isTrue);
    expect(items.first.subject.nombre, 'Química');
    expect(items.last.fecha, isNull);
  });

  test('borrar una materia se lleva sus tareas', () async {
    await db.tasksDao.addTask(subjectId: 1, titulo: 'Taller');
    await db.subjectsDao.deleteSubject(1);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('deshacer un borrado devuelve la tarea tal cual', () async {
    final id = await db.tasksDao.addTask(subjectId: 1, titulo: 'Taller', fecha: DateTime(2026, 9, 30));
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
    await db.tasksDao.deleteTask(id);
    await db.tasksDao.restoreTask(task);
    final back = await db.select(db.tasks).getSingle();
    expect(back.titulo, 'Taller');
    expect(back.fecha, DateTime(2026, 9, 30));
  });
}
