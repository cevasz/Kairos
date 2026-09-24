import 'package:drift/drift.dart';

import '../../../domain/attendance/attendance.dart';
import '../../../domain/streaks/streaks.dart';
import '../../async/combine_latest.dart';
import '../database.dart';
import '../tables.dart';

part 'subjects_dao.g.dart';

/// Una fila de la lista de materias, ya con lo que la tarjeta necesita.
///
/// Lleva los datos crudos, no los cálculos: quien los interpreta es
/// `AttendanceCounter`, que es Dart puro y vive en el dominio. Esta clase solo
/// evita cuatro consultas por actividad.
class SubjectOverview {
  const SubjectOverview({
    required this.subject,
    required this.weeklyClasses,
    required this.history,
    required this.evaluations,
  });

  final Subject subject;

  /// Cuántas veces a la semana se dicta. Es el número de ClassSession, no de
  /// instancias: la tarjeta dice «2 a la semana», no «32 en el semestre».
  final int weeklyClasses;

  /// Cada sesión ya materializada con su fecha y su estado. Alimenta el
  /// contador de saltos y la racha.
  final List<DatedStatus> history;

  List<SessionStatus> get statuses => [for (final h in history) h.status];

  /// Herencia de Cátedra: Kairós ya no crea evaluaciones, pero la tabla sigue
  /// y la mascota todavía la lee. Vacía en una instalación nueva.
  final List<Evaluation> evaluations;
}

/// Una clase recurrente con su salón resuelto.
class SessionWithRoom {
  const SessionWithRoom({required this.session, this.room});

  final ClassSession session;
  final Room? room;
}

/// Todo lo que la pantalla de materia necesita, en un solo stream.
class SubjectDetail {
  const SubjectDetail({
    required this.subject,
    required this.sessions,
    required this.instances,
  });

  final Subject subject;
  final List<SessionWithRoom> sessions;

  /// Instancias pasadas y futuras, de más reciente a más antigua. El historial
  /// de la pestaña Asistencia se lee en ese orden.
  final List<SessionInstance> instances;

  List<SessionStatus> get statuses => instances.map((i) => i.estado).toList();

  List<DatedStatus> get history => [for (final i in instances) DatedStatus(i.fecha, i.estado)];
}

/// Cuánto hacia adelante existen los bloques. Kairós no tiene fin de
/// semestre: el periodo activo se corre solo (`rollHorizon`) y siempre hay
/// este margen de semanas generadas por delante de hoy.
const int kDefaultSemesterWeeks = 12;

@DriftAccessor(
  tables: [Semesters, Subjects, ClassSessions, SessionInstances, Rooms, Evaluations, Tasks],
)
class SubjectsDao extends DatabaseAccessor<KairosDatabase> with _$SubjectsDaoMixin {
  SubjectsDao(super.db);

  // ------------------------------------------------------------- semestre

  /// El semestre activo, creándolo si no existe.
  ///
  /// La app no puede tener una materia sin semestre: sin él «cambio de
  /// semestre» no tendría dónde vivir y el horario viejo contaminaría Hoy.
  Future<Semester> ensureActiveSemester() async {
    final existing = await (select(semesters)..where((t) => t.activo.equals(true)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return into(semesters).insertReturning(
      SemestersCompanion.insert(
        nombre: 'Semestre actual',
        fechaInicio: start,
        fechaFin: start.add(const Duration(days: kDefaultSemesterWeeks * 7)),
        activo: const Value(true),
      ),
    );
  }

  /// Corre el periodo para que siempre haya [kDefaultSemesterWeeks] semanas
  /// de bloques por delante de [today], y genera los que falten. Se llama al
  /// abrir la app y al cambiar de día. Regenerar es idempotente (índice único
  /// sesión-fecha), así que llamarlo de más no duplica nada.
  Future<void> rollHorizon(DateTime today) async {
    final semester = await ensureActiveSemester();
    final day = DateTime(today.year, today.month, today.day);
    final until = day.add(const Duration(days: kDefaultSemesterWeeks * 7));
    if (!semester.fechaFin.isBefore(until)) return;
    final from = semester.fechaFin.isAfter(day) ? semester.fechaFin : day;
    await (update(semesters)..where((t) => t.id.equals(semester.id)))
        .write(SemestersCompanion(fechaFin: Value(until)));
    for (final s in await select(classSessions).get()) {
      await db.scheduleDao.materialize(sessionId: s.id, diaSemana: s.diaSemana, from: from, to: until);
    }
  }

  // ------------------------------------------------------------- lecturas

  /// Lista de materias con lo justo para pintar la tarjeta.
  ///
  /// Cuatro consultas en paralelo y no una por materia: al marcar una falta el
  /// contador de la lista tiene que moverse en vivo, y eso solo pasa si el
  /// stream depende de `session_instances`.
  Stream<List<SubjectOverview>> watchOverview({bool includeArchived = false}) {
    final subjectsQuery = select(subjects)
      ..where((t) => includeArchived ? const Constant(true) : t.archivada.equals(false))
      // Las canceladas van al final: siguen ahí, pero ya no son lo primero.
      ..orderBy([
        (t) => OrderingTerm.asc(t.cancelada),
        (t) => OrderingTerm.asc(t.nombre),
      ]);

    final statusQuery = select(sessionInstances).join([
      innerJoin(classSessions, classSessions.id.equalsExp(sessionInstances.sessionId)),
    ]);

    return combineLatest4<List<Subject>, List<ClassSession>, List<TypedResult>,
        List<Evaluation>, List<SubjectOverview>>(
      subjectsQuery.watch(),
      select(classSessions).watch(),
      statusQuery.watch(),
      select(evaluations).watch(),
      (subjectRows, sessionRows, statusRows, evaluationRows) {
        final weekly = <int, int>{};
        for (final s in sessionRows) {
          weekly[s.subjectId] = (weekly[s.subjectId] ?? 0) + 1;
        }

        final history = <int, List<DatedStatus>>{};
        for (final r in statusRows) {
          final subjectId = r.readTable(classSessions).subjectId;
          final instance = r.readTable(sessionInstances);
          history
              .putIfAbsent(subjectId, () => <DatedStatus>[])
              .add(DatedStatus(instance.fecha, instance.estado));
        }

        final evals = <int, List<Evaluation>>{};
        for (final e in evaluationRows) {
          evals.putIfAbsent(e.subjectId, () => <Evaluation>[]).add(e);
        }

        return [
          for (final s in subjectRows)
            SubjectOverview(
              subject: s,
              weeklyClasses: weekly[s.id] ?? 0,
              history: history[s.id] ?? const <DatedStatus>[],
              evaluations: evals[s.id] ?? const <Evaluation>[],
            ),
        ];
      },
    );
  }

  /// Una materia con su horario, su historial y sus evaluaciones.
  ///
  /// Emite `null` si la materia se borró mientras la pantalla estaba abierta,
  /// que es lo que permite cerrarla sin condición de carrera.
  Stream<SubjectDetail?> watchDetail(int subjectId) {
    final subjectQuery = select(subjects)..where((t) => t.id.equals(subjectId));

    final sessionQuery = select(classSessions).join([
      leftOuterJoin(rooms, rooms.id.equalsExp(classSessions.roomId)),
    ])
      ..where(classSessions.subjectId.equals(subjectId))
      ..orderBy([
        OrderingTerm.asc(classSessions.diaSemana),
        OrderingTerm.asc(classSessions.horaInicio),
      ]);

    final instanceQuery = select(sessionInstances).join([
      innerJoin(classSessions, classSessions.id.equalsExp(sessionInstances.sessionId)),
    ])
      ..where(classSessions.subjectId.equals(subjectId))
      ..orderBy([OrderingTerm.desc(sessionInstances.fecha)]);

    return combineLatest3<List<Subject>, List<TypedResult>, List<TypedResult>, SubjectDetail?>(
      subjectQuery.watch(),
      sessionQuery.watch(),
      instanceQuery.watch(),
      (subjectRows, sessionRows, instanceRows) {
        if (subjectRows.isEmpty) return null;
        return SubjectDetail(
          subject: subjectRows.first,
          sessions: [
            for (final r in sessionRows)
              SessionWithRoom(
                session: r.readTable(classSessions),
                room: r.readTableOrNull(rooms),
              ),
          ],
          instances: [
            for (final r in instanceRows) r.readTable(sessionInstances),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------- materia

  Future<int> createSubject({
    required String nombre,
    required int colorIndex,
    required int limiteFaltas,
    String? profesor,
  }) async {
    final semester = await ensureActiveSemester();
    return into(subjects).insert(
      SubjectsCompanion.insert(
        semesterId: semester.id,
        nombre: nombre,
        colorIndex: colorIndex,
        limiteFaltas: Value(limiteFaltas),
        profesor: Value(profesor),
      ),
    );
  }

  /// Las columnas de créditos y fecha límite de cancelación siguen en la
  /// tabla (herencia de Cátedra) pero Kairós no las escribe.
  Future<void> updateSubject({
    required int id,
    required String nombre,
    required int colorIndex,
    required int limiteFaltas,
    String? profesor,
  }) {
    return (update(subjects)..where((t) => t.id.equals(id))).write(
      SubjectsCompanion(
        nombre: Value(nombre),
        colorIndex: Value(colorIndex),
        limiteFaltas: Value(limiteFaltas),
        profesor: Value(profesor),
      ),
    );
  }

  /// El color de la materia: un índice de la paleta o un ARGB de la rueda
  /// (`SubjectPalette.isCustom`, §48).
  Future<void> setColor(int id, int colorIndex) =>
      (update(subjects)..where((t) => t.id.equals(id))).write(SubjectsCompanion(colorIndex: Value(colorIndex)));

  /// Cancela la materia (o la reactiva con `cancelled: false`).
  ///
  /// No borra nada: las sesiones ya marcadas son historia. Las pendientes se
  /// quedan como están y solo dejan de verse, porque Hoy y la semana filtran
  /// por materia viva; si la cancelación se deshace, vuelven intactas.
  Future<void> setCancelled(int id, {required bool cancelled, DateTime? at}) {
    return (update(subjects)..where((t) => t.id.equals(id))).write(
      SubjectsCompanion(
        cancelada: Value(cancelled),
        fechaCancelacion: Value(cancelled ? (at ?? DateTime.now()) : null),
      ),
    );
  }

  /// Borra la materia y todo lo que cuelga de ella.
  ///
  /// El orden importa: las claves foráneas están activas, así que las hojas se
  /// van primero. Va en una transacción para que un fallo a media eliminación
  /// no deje sesiones huérfanas apuntando a una materia que ya no existe.
  Future<void> deleteSubject(int id) {
    return transaction(() async {
      final sessionIds = await (select(classSessions)
            ..where((t) => t.subjectId.equals(id)))
          .map((s) => s.id)
          .get();

      if (sessionIds.isNotEmpty) {
        await (delete(sessionInstances)..where((t) => t.sessionId.isIn(sessionIds))).go();
      }
      await (delete(evaluations)..where((t) => t.subjectId.equals(id))).go();
      await (delete(tasks)..where((t) => t.subjectId.equals(id))).go();
      await (delete(classSessions)..where((t) => t.subjectId.equals(id))).go();
      await (delete(subjects)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------------------------------------------------------- clase

  /// Crea o actualiza una clase recurrente y regenera sus sesiones.
  ///
  /// Al cambiar día u hora, las instancias viejas dejan de corresponder al
  /// horario. Se borran solo las que siguen pendientes: una sesión ya marcada
  /// es un hecho del pasado y no se reescribe porque muevas la clase.
  Future<int> saveSession({
    int? id,
    required int subjectId,
    required int diaSemana,
    required int horaInicio,
    required int horaFin,
    int? roomId,
  }) async {
    final semester = await ensureActiveSemester();

    final sessionId = await transaction(() async {
      if (id == null) {
        return into(classSessions).insert(
          ClassSessionsCompanion.insert(
            subjectId: subjectId,
            diaSemana: diaSemana,
            horaInicio: horaInicio,
            horaFin: horaFin,
            roomId: Value(roomId),
          ),
        );
      }

      await (update(classSessions)..where((t) => t.id.equals(id))).write(
        ClassSessionsCompanion(
          diaSemana: Value(diaSemana),
          horaInicio: Value(horaInicio),
          horaFin: Value(horaFin),
          roomId: Value(roomId),
        ),
      );
      await (delete(sessionInstances)
            ..where((t) =>
                t.sessionId.equals(id) & t.estado.equalsValue(SessionStatus.pendiente)))
          .go();
      return id;
    });

    await db.scheduleDao.materialize(
      sessionId: sessionId,
      diaSemana: diaSemana,
      from: semester.fechaInicio,
      to: semester.fechaFin,
    );
    return sessionId;
  }

  Future<void> deleteSession(int sessionId) {
    return transaction(() async {
      await (delete(sessionInstances)..where((t) => t.sessionId.equals(sessionId))).go();
      await (delete(classSessions)..where((t) => t.id.equals(sessionId))).go();
    });
  }

  // ---------------------------------------------------------------- salón

  /// Devuelve el salón con ese código, creándolo si hace falta.
  ///
  /// Se reutiliza por código para que dos materias en el mismo salón compartan
  /// fila: cuando llegue la Fase 4 se geocodifica una vez, no una por materia.
  Future<int?> ensureRoom({String? codigo, String? edificio}) async {
    final code = codigo?.trim();
    if (code == null || code.isEmpty) return null;

    final existing =
        await (select(rooms)..where((t) => t.codigo.equals(code))).getSingleOrNull();
    if (existing != null) {
      final building = edificio?.trim();
      if (building != null && building.isNotEmpty && building != existing.edificio) {
        await (update(rooms)..where((t) => t.id.equals(existing.id)))
            .write(RoomsCompanion(edificio: Value(building)));
      }
      return existing.id;
    }

    final building = edificio?.trim();
    return into(rooms).insert(
      RoomsCompanion.insert(
        codigo: code,
        edificio: Value(building != null && building.isEmpty ? null : building),
      ),
    );
  }
}
