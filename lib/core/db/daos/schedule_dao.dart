import 'package:drift/drift.dart';

import '../../../domain/attendance/attendance.dart';
import '../database.dart';
import '../tables.dart';

part 'schedule_dao.g.dart';

/// Una clase del día, ya resuelta con su materia y su salón. La vista Hoy
/// necesita las tres cosas juntas y pedirlas por separado dispararía N+1.
class DayClass {
  const DayClass({
    required this.instance,
    required this.session,
    required this.subject,
    this.room,
  });

  final SessionInstance instance;
  final ClassSession session;
  final Subject subject;
  final Room? room;

  SessionStatus get status => instance.estado;
}

@DriftAccessor(
  tables: [Subjects, ClassSessions, SessionInstances, Rooms, Semesters],
)
class ScheduleDao extends DatabaseAccessor<KairosDatabase> with _$ScheduleDaoMixin {
  ScheduleDao(super.db);

  /// Solo materias vivas: ni archivadas ni canceladas. Una materia cancelada
  /// ya no tiene clases a las que ir, así que no aparece en Hoy ni en la
  /// semana; su historial sigue en su pantalla.
  Expression<bool> get _live =>
      subjects.archivada.equals(false) & subjects.cancelada.equals(false);

  /// Todas las clases recurrentes de materias vivas con su salón. El mapa
  /// las usa para saber qué salones importan.
  Stream<List<(ClassSession, Subject, Room?)>> watchLiveSessions() {
    final query = select(classSessions).join([
      innerJoin(subjects, subjects.id.equalsExp(classSessions.subjectId)),
      leftOuterJoin(rooms, rooms.id.equalsExp(classSessions.roomId)),
    ])
      ..where(_live)
      ..orderBy([
        OrderingTerm.asc(classSessions.diaSemana),
        OrderingTerm.asc(classSessions.horaInicio),
      ]);
    return query.watch().map((rows) => [
          for (final r in rows)
            (r.readTable(classSessions), r.readTable(subjects), r.readTableOrNull(rooms)),
        ]);
  }

  /// Todos los salones, para el mapa.
  Stream<List<Room>> watchRooms() =>
      (select(rooms)..orderBy([(t) => OrderingTerm.asc(t.codigo)])).watch();

  /// Ubica un salón en el mapa. `null` lo desubica.
  Future<void> setRoomLocation(int roomId, {double? lat, double? lng}) =>
      (update(rooms)..where((t) => t.id.equals(roomId))).write(
        RoomsCompanion(lat: Value(lat), lng: Value(lng)),
      );

  /// Indicaciones libres del salón: «Bloque 4, piso 2. Entra por el patio.»
  Future<void> setRoomNotes(int roomId, String? notes) =>
      (update(rooms)..where((t) => t.id.equals(roomId))).write(
        RoomsCompanion(indicaciones: Value(notes)),
      );

  /// Clases de un día concreto, ordenadas por hora de inicio.
  ///
  /// `day` se normaliza a medianoche antes de comparar: la fila guarda la fecha
  /// absoluta del día, no un instante.
  Stream<List<DayClass>> watchDay(DateTime day) {
    final midnight = DateTime(day.year, day.month, day.day);

    final query = select(sessionInstances).join([
      innerJoin(classSessions, classSessions.id.equalsExp(sessionInstances.sessionId)),
      innerJoin(subjects, subjects.id.equalsExp(classSessions.subjectId)),
      leftOuterJoin(rooms, rooms.id.equalsExp(classSessions.roomId)),
    ])
      ..where(sessionInstances.fecha.equals(midnight) & _live)
      ..orderBy([OrderingTerm.asc(classSessions.horaInicio)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => DayClass(
                    instance: r.readTable(sessionInstances),
                    session: r.readTable(classSessions),
                    subject: r.readTable(subjects),
                    room: r.readTableOrNull(rooms),
                  ))
              .toList(),
        );
  }

  /// Clases de una semana, agrupadas por día ISO (1 = lunes).
  Stream<Map<int, List<DayClass>>> watchWeek(DateTime anyDayInWeek) {
    final monday = DateTime(anyDayInWeek.year, anyDayInWeek.month, anyDayInWeek.day)
        .subtract(Duration(days: anyDayInWeek.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final query = select(sessionInstances).join([
      innerJoin(classSessions, classSessions.id.equalsExp(sessionInstances.sessionId)),
      innerJoin(subjects, subjects.id.equalsExp(classSessions.subjectId)),
      leftOuterJoin(rooms, rooms.id.equalsExp(classSessions.roomId)),
    ])
      ..where(sessionInstances.fecha.isBetweenValues(monday, sunday) & _live)
      ..orderBy([OrderingTerm.asc(classSessions.horaInicio)]);

    return query.watch().map((rows) {
      final byDay = <int, List<DayClass>>{};
      for (final r in rows) {
        final item = DayClass(
          instance: r.readTable(sessionInstances),
          session: r.readTable(classSessions),
          subject: r.readTable(subjects),
          room: r.readTableOrNull(rooms),
        );
        byDay.putIfAbsent(item.instance.fecha.weekday, () => []).add(item);
      }
      return byDay;
    });
  }

  /// Clases de materias vivas entre dos días, ambos incluidos, en orden. Es
  /// lo que se les pasa a los widgets de la pantalla de inicio: con una
  /// semana por delante pueden elegir solos la próxima clase aunque la app no
  /// se abra.
  Stream<List<DayClass>> watchBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    final query = select(sessionInstances).join([
      innerJoin(classSessions, classSessions.id.equalsExp(sessionInstances.sessionId)),
      innerJoin(subjects, subjects.id.equalsExp(classSessions.subjectId)),
      leftOuterJoin(rooms, rooms.id.equalsExp(classSessions.roomId)),
    ])
      ..where(sessionInstances.fecha.isBetweenValues(a, b) & _live)
      ..orderBy([
        OrderingTerm.asc(sessionInstances.fecha),
        OrderingTerm.asc(classSessions.horaInicio),
      ]);
    return query.watch().map((rows) => [
          for (final r in rows)
            DayClass(
              instance: r.readTable(sessionInstances),
              session: r.readTable(classSessions),
              subject: r.readTable(subjects),
              room: r.readTableOrNull(rooms),
            ),
        ]);
  }

  /// La primera clase pendiente después de `day`, en cualquier semana.
  ///
  /// Es lo que el día vacío y el «Nada más» enseñan como «Lo próximo». Se
  /// salta las canceladas: anunciar una clase que no va a existir es peor que
  /// no anunciar nada.
  Stream<DayClass?> watchNextAfter(DateTime day) {
    final midnight = DateTime(day.year, day.month, day.day);

    final query = select(sessionInstances).join([
      innerJoin(classSessions, classSessions.id.equalsExp(sessionInstances.sessionId)),
      innerJoin(subjects, subjects.id.equalsExp(classSessions.subjectId)),
      leftOuterJoin(rooms, rooms.id.equalsExp(classSessions.roomId)),
    ])
      ..where(sessionInstances.fecha.isBiggerThanValue(midnight) &
          sessionInstances.estado.equalsValue(SessionStatus.pendiente) &
          _live)
      ..orderBy([
        OrderingTerm.asc(sessionInstances.fecha),
        OrderingTerm.asc(classSessions.horaInicio),
      ])
      ..limit(1);

    return query.watchSingleOrNull().map((r) => r == null
        ? null
        : DayClass(
            instance: r.readTable(sessionInstances),
            session: r.readTable(classSessions),
            subject: r.readTable(subjects),
            room: r.readTableOrNull(rooms),
          ));
  }

  /// Marca el resultado de una sesión y guarda cuándo se marcó, que es lo que
  /// permite el «Marcada hace 3 min · Deshacer» de la pantalla B3.
  Future<void> setStatus(int instanceId, SessionStatus status) {
    return (update(sessionInstances)..where((t) => t.id.equals(instanceId))).write(
      SessionInstancesCompanion(
        estado: Value(status),
        marcadaEn: Value(DateTime.now()),
      ),
    );
  }

  /// El estado de una sesión, o null si ya no existe (se borró la materia).
  Future<SessionStatus?> statusOf(int instanceId) async {
    final row = await (select(sessionInstances)..where((t) => t.id.equals(instanceId))).getSingleOrNull();
    return row?.estado;
  }

  /// Deshacer devuelve la sesión a pendiente y borra la marca de tiempo.
  Future<void> clearStatus(int instanceId) {
    return (update(sessionInstances)..where((t) => t.id.equals(instanceId))).write(
      const SessionInstancesCompanion(
        estado: Value(SessionStatus.pendiente),
        marcadaEn: Value(null),
      ),
    );
  }

  /// Genera las instancias de una clase recurrente entre dos fechas absolutas.
  ///
  /// Se materializan las sesiones en vez de calcularlas al vuelo porque cada una
  /// lleva estado propio (asististe, faltaste, cancelada) y ese estado tiene que
  /// sobrevivir a que cambies el horario.
  Future<int> materialize({
    required int sessionId,
    required int diaSemana,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = <SessionInstancesCompanion>[];
    var cursor = DateTime(from.year, from.month, from.day);
    while (!cursor.isAfter(to)) {
      if (cursor.weekday == diaSemana) {
        rows.add(SessionInstancesCompanion.insert(
          sessionId: sessionId,
          fecha: cursor,
        ));
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    if (rows.isEmpty) return 0;
    // El índice único (session_id, fecha) hace que regenerar sea idempotente.
    await batch((b) => b.insertAll(sessionInstances, rows, mode: InsertMode.insertOrIgnore));
    return rows.length;
  }
}
