import 'package:kairos/core/db/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KairosDatabase db;

  setUp(() async {
    db = KairosDatabase.forTesting(NativeDatabase.memory());
    final semester = await db.subjectsDao.ensureActiveSemester();
    for (final (nombre, cancelada) in [('Gimnasio', false), ('Trabajo', false), ('Pintura', true)]) {
      await db.into(db.subjects).insert(SubjectsCompanion.insert(
            semesterId: semester.id,
            nombre: nombre,
            colorIndex: 0,
            cancelada: Value(cancelada),
          ));
    }
  });

  tearDown(() => db.close());

  test('pendientes: los abiertos de actividades vivas, por fecha; sin fecha al final', () async {
    final dao = db.tasksDao;
    await dao.addTask(subjectId: 1, titulo: 'Renovar la tarjeta');
    await dao.addTask(subjectId: 2, titulo: 'Llevar la toalla', fecha: DateTime(2026, 9, 25));
    final hecha = await dao.addTask(subjectId: 1, titulo: 'Ya hecha', fecha: DateTime(2026, 9, 23));
    await dao.setDone(hecha, done: true);
    await dao.addTask(subjectId: 3, titulo: 'De actividad en pausa', fecha: DateTime(2026, 9, 23));
    await dao.addTask(subjectId: 2, titulo: 'Vencido', fecha: DateTime(2026, 9, 20));

    final items = await dao.watchPending().first;
    expect(items.map((i) => i.titulo), ['Vencido', 'Llevar la toalla', 'Renovar la tarjeta']);
    expect(items.first.subject.nombre, 'Trabajo');
    expect(items.last.fecha, isNull);
  });

  test('borrar una actividad se lleva sus pendientes', () async {
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
