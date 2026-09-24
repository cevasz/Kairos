import 'dart:async';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'tasks_dao.g.dart';

/// Un pendiente con la materia a la que pertenece, listo para pintar.
class PendingItem {
  const PendingItem({required this.subject, this.task, this.evaluation});

  final Subject subject;

  /// Exactamente uno de los dos no es nulo.
  final Task? task;
  final Evaluation? evaluation;

  bool get isEvaluation => evaluation != null;
  String get titulo => task?.titulo ?? evaluation!.nombre;
  DateTime? get fecha => task?.fecha ?? evaluation?.fecha;
}

/// Pendientes por materia: tareas propias y evaluaciones sin nota.
@DriftAccessor(tables: [Tasks, Subjects, Evaluations])
class TasksDao extends DatabaseAccessor<KairosDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  /// Las tareas de una materia: primero las abiertas por fecha (sin fecha al
  /// final), después las hechas, las más recientes arriba.
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

  /// Todo lo pendiente de materias vivas: tareas sin hacer y evaluaciones sin
  /// nota que no hayan pasado. Una evaluación de ayer sin nota ya no es un
  /// pendiente, es una nota que falta poner, y eso lo dice la pestaña Notas.
  Stream<List<PendingItem>> watchPending(DateTime today) {
    final live = subjects.cancelada.equals(false) & subjects.archivada.equals(false);

    final taskRows = (select(tasks).join([innerJoin(subjects, subjects.id.equalsExp(tasks.subjectId))])
          ..where(tasks.hecha.equals(false) & live))
        .watch()
        .map((rows) => [
              for (final r in rows) PendingItem(subject: r.readTable(subjects), task: r.readTable(tasks)),
            ]);

    final evalRows = (select(evaluations).join([innerJoin(subjects, subjects.id.equalsExp(evaluations.subjectId))])
          ..where(evaluations.nota.isNull() &
              evaluations.fecha.isBiggerOrEqualValue(today) &
              live))
        .watch()
        .map((rows) => [
              for (final r in rows)
                PendingItem(subject: r.readTable(subjects), evaluation: r.readTable(evaluations)),
            ]);

    return _combine(taskRows, evalRows).map((items) => items..sort(_byDate));
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
/// tiene fecha, al final y por materia.
int _byDate(PendingItem a, PendingItem b) {
  final fa = a.fecha, fb = b.fecha;
  if (fa == null && fb == null) return a.subject.nombre.compareTo(b.subject.nombre);
  if (fa == null) return 1;
  if (fb == null) return -1;
  return fa.compareTo(fb);
}

/// Une dos streams de listas: emite en cuanto los dos tienen valor y cada
/// vez que cualquiera cambia.
Stream<List<PendingItem>> _combine(Stream<List<PendingItem>> a, Stream<List<PendingItem>> b) {
  late StreamController<List<PendingItem>> controller;
  List<PendingItem>? lastA, lastB;
  StreamSubscription<List<PendingItem>>? subA, subB;
  void emit() {
    if (lastA != null && lastB != null) controller.add([...lastA!, ...lastB!]);
  }

  controller = StreamController<List<PendingItem>>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
