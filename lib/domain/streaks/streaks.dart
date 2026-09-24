import '../attendance/attendance.dart';

/// Una sesión con su fecha y su resultado: lo mínimo para contar rachas.
class DatedStatus {
  const DatedStatus(this.date, this.status);

  /// El día de la sesión. La hora se ignora.
  final DateTime date;
  final SessionStatus status;
}

/// La racha de una actividad, en semanas.
class Streak {
  const Streak({required this.current, required this.best});

  static const Streak none = Streak(current: 0, best: 0);

  /// Semanas seguidas cumplidas que llegan hasta hoy.
  final int current;

  /// La racha más larga de todo el historial. Nunca menor que [current].
  final int best;

  @override
  bool operator ==(Object other) => other is Streak && other.current == current && other.best == best;

  @override
  int get hashCode => Object.hash(current, best);

  @override
  String toString() => 'Streak(current: $current, best: $best)';
}

/// Cuenta rachas de semanas cumplidas. Dart puro.
///
/// Una semana (lunes a domingo) está **cumplida** cuando todas sus sesiones
/// ya pasadas quedaron hechas, justificadas o canceladas. Un «Saltado» la
/// rompe, y también una sesión pasada que nadie marcó: la racha es de lo que
/// hiciste, no de lo que se olvidó anotar.
///
/// Reglas de borde:
/// - Una semana sin sesiones pasadas (vacaciones, un bloque que todavía no
///   empieza) no suma ni corta: se salta.
/// - La semana en curso todavía se puede arreglar: si tiene un «Saltado» la
///   racha actual es 0, pero si solo tiene sesiones sin marcar no suma ni
///   corta. Cumplida hasta hoy, suma.
/// - De hoy cuenta lo ya marcado; lo pendiente de hoy todavía no pasó.
abstract final class StreakCounter {
  static Streak compute(Iterable<DatedStatus> sessions, {required DateTime today}) {
    final day = _day(today);
    final currentWeek = _monday(day);

    // Resultado de cada semana con al menos una sesión que cuenta.
    final weeks = <DateTime, _Week>{};
    for (final s in sessions) {
      final d = _day(s.date);
      final counts = d.isBefore(day) || (d == day && s.status.isResolved);
      if (!counts) continue;
      final week = weeks.putIfAbsent(_monday(d), _Week.new);
      switch (s.status) {
        case SessionStatus.asistio || SessionStatus.justificada || SessionStatus.canceladaProfe:
          break;
        case SessionStatus.falto:
          week.skipped = true;
        case SessionStatus.pendiente || SessionStatus.posibleFalta:
          week.unmarked = true;
      }
    }

    final order = weeks.keys.toList()..sort();
    var run = 0;
    var best = 0;
    for (final monday in order) {
      final w = weeks[monday]!;
      final inProgress = monday == currentWeek;
      if (w.skipped || (w.unmarked && !inProgress)) {
        run = 0;
      } else if (!w.unmarked) {
        run++;
      }
      if (run > best) best = run;
    }
    return Streak(current: run, best: best);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// El lunes de la semana de [d]. Con fechas de calendario, no con
  /// `Duration`: un cambio de hora no descuadra el día.
  static DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

class _Week {
  bool skipped = false;
  bool unmarked = false;
}
