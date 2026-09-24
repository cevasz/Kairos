import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'tasks_dao.g.dart';

/// Un pendiente con la actividad a la que pertenece, listo para pintar.
class PendingItem {
  const PendingItem({required this.subject, required this.task});

  final Subject subject;
  final Task task;

  String get titulo => task.titulo;
  DateTime? get fecha => task.fecha;
}

/// Pendientes por actividad: lo que hay que hacer, con o sin fecha.
@DriftAccessor(tables: [Tasks, Subjects])
class TasksDao extends DatabaseAccessor<KairosDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  /// Los pendientes de una actividad: primero los abiertos por fecha (sin
  /// fecha al final), después los hechos, los más recientes arriba.
  Stream<List<Task>> watchForSubject(int subjectId) {
    return (select(tasks)
          ..where((t) => t.subjectId.equals(subjectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.hecha),
            (t) => OrderingTerm(expression: t.fecha, nulls: NullsOrder.last),
            (t) => OrderingTerm(expression: t.creadaEn, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Todo lo pendiente de actividades vivas, por fecha. Los vencidos también:
  /// un pendiente de ayer sin hacer sigue pendiente.
  Stream<List<PendingItem>> watchPending() {
    final live = subjects.cancelada.equals(false) & subjects.archivada.equals(false);
    return (select(tasks).join([innerJoin(subjects, subjects.id.equalsExp(tasks.subjectId))])
          ..where(tasks.hecha.equals(false) & live))
        .watch()
        .map((rows) => [
              for (final r in rows) PendingItem(subject: r.readTable(subjects), task: r.readTable(tasks)),
            ]..sort(_byDate));
  }

  Future<int> addTask({required int subjectId, required String titulo, DateTime? fecha}) {
    return into(tasks).insert(TasksCompanion.insert(
      subjectId: subjectId,
      titulo: titulo.trim(),
      fecha: Value(fecha),
    ));
  }

  Future<void> updateTask(int id, {required String titulo, DateTime? fecha}) {
    return (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
      titulo: Value(titulo.trim()),
      fecha: Value(fecha),
    ));
  }

  Future<void> setDone(int id, {required bool done}) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(hecha: Value(done)));

  Future<void> deleteTask(int id) => (delete(tasks)..where((t) => t.id.equals(id))).go();

  /// Para deshacer un borrado: vuelve a meter la fila tal como estaba.
  Future<void> restoreTask(Task task) => into(tasks).insert(task, mode: InsertMode.insertOrReplace);
}

/// Primero lo que tiene fecha, de la más cercana a la más lejana; lo que no
/// tiene fecha, al final y por actividad.
int _byDate(PendingItem a, PendingItem b) {
  final fa = a.fecha, fb = b.fecha;
  if (fa == null && fb == null) return a.subject.nombre.compareTo(b.subject.nombre);
  if (fa == null) return 1;
  if (fb == null) return -1;
  return fa.compareTo(fb);
}
