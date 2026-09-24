/// Qué alarmas crear en el Reloj del teléfono a partir del horario semanal.
///
/// Dart puro: recibe clases y ajustes, devuelve alarmas. Quién las crea (un
/// intent de Android) y con qué texto (el contrato) es cosa de otras capas.
library;

import '../../core/time/minutes_of_day.dart';
import '../departure/departure.dart';

/// Una clase del horario semanal, lo mínimo para planear alarmas.
class WeeklyClass {
  const WeeklyClass({required this.subject, required this.weekday, required this.start, this.end});

  final String subject;

  /// ISO 8601: 1 = lunes … 7 = domingo.
  final int weekday;

  /// Minutos desde medianoche.
  final int start;

  /// Minutos desde medianoche. Sin él no se sabe si la siguiente clase del
  /// día te encuentra ya en la U, y se asume que sales de casa.
  final int? end;
}

enum AlarmKind { wake, leave }

/// Una alarma semanal: suena a [minute] los [weekdays] indicados.
class PlannedAlarm {
  const PlannedAlarm({required this.kind, required this.minute, required this.weekdays, this.subject});

  final AlarmKind kind;

  /// Minutos desde medianoche.
  final int minute;

  /// ISO 8601, ordenados y sin repetir.
  final List<int> weekdays;

  /// Solo en las de salir: para qué clase.
  final String? subject;

  int get hour => minute ~/ 60;
  int get minuteOfHour => minute % 60;

  @override
  bool operator ==(Object other) =>
      other is PlannedAlarm &&
      other.kind == kind &&
      other.minute == minute &&
      other.subject == subject &&
      _sameDays(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(kind, minute, subject, Object.hashAll(weekdays));

  @override
  String toString() => 'PlannedAlarm($kind, ${hour}h$minuteOfHour, $weekdays, $subject)';
}

bool _sameDays(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Un pendiente con fecha, para el aviso de la víspera.
class DatedPending {
  const DatedPending({required this.id, required this.name, required this.subject, required this.date});

  final int id;
  final String name;
  final String subject;
  final DateTime date;
}

/// El aviso de la víspera de un pendiente: fecha y hora exactas.
class PendingReminder {
  const PendingReminder({required this.pending, required this.at});

  final DatedPending pending;
  final DateTime at;
}

abstract final class AlarmPlanner {
  /// Rango del margen de despertar que Ajustes deja escoger, en minutos.
  static const int minWakeMinutes = 15;
  static const int maxWakeMinutes = 180;
  static const int wakeStep = 15;

  /// Alarmas semanales. [leaveOffset] es trayecto + buffer: salir a las
  /// `inicio − leaveOffset`, igual que la card de Hoy y los widgets.
  ///
  /// Las que caen a la misma hora se juntan en una sola alarma con varios
  /// días: el Reloj las muestra así y hay menos que borrar si cambia el horario.
  ///
  /// La de salir solo se crea cuando de verdad sales de casa
  /// ([DeparturePlanner.leavesFromHome] con [travelMinutes]): entre dos
  /// clases seguidas ya estás en la U y un «Salir» a mitad de día sobra.
  static List<PlannedAlarm> weekly({
    required List<WeeklyClass> classes,
    required int leaveOffset,
    required bool wake,
    required int wakeMinutes,
    required bool leave,
    int? travelMinutes,
  }) {
    final out = <PlannedAlarm>[];
    int clamp(int m) => m.clamp(0, 24 * 60 - 1);

    if (wake) {
      // La primera clase de cada día manda la hora de levantarse.
      final firstByDay = <int, int>{};
      for (final c in classes) {
        final prev = firstByDay[c.weekday];
        if (prev == null || c.start < prev) firstByDay[c.weekday] = c.start;
      }
      final daysByMinute = <int, List<int>>{};
      firstByDay.forEach((day, start) {
        daysByMinute.putIfAbsent(clamp(start - leaveOffset - wakeMinutes), () => []).add(day);
      });
      daysByMinute.forEach((minute, days) {
        out.add(PlannedAlarm(kind: AlarmKind.wake, minute: minute, weekdays: days..sort()));
      });
    }

    if (leave) {
      final daysBy = <(int, String), List<int>>{};
      final ordered = [...classes]..sort((a, b) => a.start.compareTo(b.start));
      final lastEnd = <int, int>{};
      final fromHome = <WeeklyClass, bool>{};
      for (final c in ordered) {
        final prev = lastEnd[c.weekday];
        fromHome[c] = travelMinutes == null ||
            DeparturePlanner.leavesFromHome(
              previousEnd: prev == null ? null : MinutesOfDay(prev),
              start: MinutesOfDay(c.start),
              travelMinutes: travelMinutes,
            );
        final end = c.end;
        if (end != null && (prev == null || end > prev)) lastEnd[c.weekday] = end;
      }
      for (final c in classes) {
        if (!(fromHome[c] ?? true)) continue;
        final list = daysBy.putIfAbsent((clamp(c.start - leaveOffset), c.subject), () => []);
        if (!list.contains(c.weekday)) list.add(c.weekday);
      }
      daysBy.forEach((key, days) {
        out.add(PlannedAlarm(kind: AlarmKind.leave, minute: key.$1, weekdays: days..sort(), subject: key.$2));
      });
    }

    out.sort((a, b) {
      final byDay = a.weekdays.first.compareTo(b.weekdays.first);
      return byDay != 0 ? byDay : a.minute.compareTo(b.minute);
    });
    return out;
  }

  /// Avisos de la víspera a [reminderMinute] (minutos desde medianoche).
  /// Solo los que todavía no pasaron respecto de [now].
  static List<PendingReminder> pendingReminders({
    required List<DatedPending> pending,
    required int reminderMinute,
    required DateTime now,
  }) {
    final out = <PendingReminder>[];
    for (final e in pending) {
      final eve = DateTime(e.date.year, e.date.month, e.date.day - 1).add(Duration(minutes: reminderMinute));
      if (eve.isAfter(now)) out.add(PendingReminder(pending: e, at: eve));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
