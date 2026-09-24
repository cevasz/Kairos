import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/schedule_dao.dart';
import '../../../core/providers.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/departure/departure.dart';
import '../../../domain/schedule/day_gaps.dart';
import '../../travel/application/travel_providers.dart';

/// Todo lo que la vista Hoy necesita saber, ya resuelto. La pantalla no hace
/// cálculos: los pide.
class TodayState {
  const TodayState({
    required this.classes,
    required this.next,
    required this.plan,
    required this.cancelled,
    required this.gapsAfter,
    required this.now,
  });

  final List<DayClass> classes;

  /// La próxima clase a la que todavía hay que ir: ni terminó, ni la cancelaron,
  /// ni ya dijiste «ya voy».
  final DayClass? next;

  /// Plan de salida de esa próxima clase. Null si no hay próxima.
  final DeparturePlan? plan;

  /// Una clase de hoy cancelada por el profe que todavía no habría terminado.
  /// Es la card B3: se enseña con su «Deshacer» hasta que pase su hora.
  final DayClass? cancelled;

  /// Minutos libres tras cada clase, por id de instancia. Solo los huecos que
  /// superan el umbral del dominio; entre dos clases pegadas no hay entrada.
  final Map<int, DayGap> gapsAfter;

  /// El instante con el que se calculó todo. La card de cancelada lo usa para
  /// «Marcada hace N min» sin volver a leer el reloj.
  final DateTime now;

  bool get isEmpty => classes.isEmpty;

  /// Hubo clases pero ya no queda ninguna por delante.
  bool get isDone => classes.isNotEmpty && next == null;

  /// Solo hay estado urgente si hay a dónde ir.
  bool get isUrgent => plan?.isUrgent ?? false;

  /// Minutos desde que se marcó la cancelada. Null si no hay marca.
  int? get minutesSinceCancelled {
    final at = cancelled?.instance.marcadaEn;
    if (at == null) return null;
    final minutes = now.difference(at).inMinutes;
    // Un reloj que va atrás del marcado no debería dar «hace −1 min».
    return minutes < 0 ? 0 : minutes;
  }
}

final todayClassesProvider = StreamProvider<List<DayClass>>((ref) {
  final day = ref.watch(todayProvider);
  return ref.watch(scheduleDaoProvider).watchDay(day);
});

/// La primera clase pendiente después de hoy. Alimenta el «Lo próximo» del día
/// vacío y del final del día.
final nextAfterTodayProvider = StreamProvider<DayClass?>((ref) {
  final day = ref.watch(todayProvider);
  return ref.watch(scheduleDaoProvider).watchNextAfter(day);
});

final todayStateProvider = Provider<AsyncValue<TodayState>>((ref) {
  final classes = ref.watch(todayClassesProvider);
  final clock = ref.watch(clockProvider);
  final settings = ref.watch(settingsProvider).valueOrNull;
  final travelModel = ref.watch(travelModelProvider);

  return classes.whenData((list) {
    final now = clock.valueOrNull ?? DateTime.now();
    final nowMinutes = MinutesOfDay.of(now.hour, now.minute);

    final next = _nextClass(list, nowMinutes);
    final mode = settings?.modoTransporte ?? TransportMode.walk;
    final buffer = settings?.bufferMinutos ?? DeparturePlanner.defaultBufferMinutes;
    // El trayecto de Ajustes (o la ruta, o la tabla) corregido con los viajes
    // medidos de este día de la semana y esta franja (§47).
    final travel = next == null
        ? 0
        : travelModel
            .forClass(weekday: now.weekday, classStart: MinutesOfDay(next.session.horaInicio), buffer: buffer)
            .minutes;

    return TodayState(
      classes: list,
      next: next,
      cancelled: _cancelledAhead(list, nowMinutes),
      gapsAfter: _gaps(list),
      now: now,
      plan: next == null
          ? null
          : DeparturePlanner.plan(
              classStart: MinutesOfDay(next.session.horaInicio),
              now: nowMinutes,
              travelMinutes: travel,
              bufferMinutes: buffer,
              mode: mode,
              fromHome: _fromHome(list, next, travel),
            ),
    );
  });
});

/// La siguiente clase del día a la que todavía hay que ir.
///
/// Una cancelada por el profe se salta: no tiene sentido avisar que salgas a
/// una clase que no existe. Una ya marcada como asistida también: si dijiste
/// «ya voy», la alerta ya cumplió y lo que sigue es la de después.
///
/// Una clase deja de serlo al pasar su inicio más la tolerancia
/// ([DeparturePlanner.lateToleranceMinutes]): a una clase que empezó hace
/// hora y media ya no se le dice «Ya. Camina.». Una falta (marcada o
/// detectada) tampoco: ya se sabe que no fuiste.
DayClass? _nextClass(List<DayClass> list, MinutesOfDay now) {
  for (final c in list) {
    if (_skipped(c.status)) continue;
    if (c.status == SessionStatus.asistio) continue;
    if (MinutesOfDay(c.session.horaInicio).plus(DeparturePlanner.lateToleranceMinutes) > now) return c;
  }
  return null;
}

/// Clases a las que no fuiste o que no hubo: no te dejan en la U.
bool _skipped(SessionStatus s) =>
    s == SessionStatus.canceladaProfe ||
    s == SessionStatus.falto ||
    s == SessionStatus.justificada ||
    s == SessionStatus.posibleFalta;

/// ¿Sales de casa hacia [next]? Solo se da por hecho que estás en la U si la
/// clase anterior de hoy está marcada como asistida y el hueco no da para
/// volver a casa. Sin marca no se supone nada: «sin marcar» no es «fui», y
/// es mejor avisarte con el trayecto que dejarte llegar tarde.
bool _fromHome(List<DayClass> list, DayClass? next, int travel) {
  if (next == null) return true;
  final start = MinutesOfDay(next.session.horaInicio);
  DayClass? previous;
  for (final c in list) {
    if (identical(c, next) || MinutesOfDay(c.session.horaInicio) >= start) break;
    if (!_skipped(c.status)) previous = c;
  }
  if (previous?.status != SessionStatus.asistio) return true;
  return DeparturePlanner.leavesFromHome(
    previousEnd: previous == null ? null : MinutesOfDay(previous.session.horaFin),
    start: start,
    travelMinutes: travel,
  );
}

/// La cancelada que todavía estaría en curso o por venir. Pasada su hora de
/// fin deja de ser noticia y se queda solo en la timeline, tachada.
DayClass? _cancelledAhead(List<DayClass> list, MinutesOfDay now) {
  for (final c in list) {
    if (c.status != SessionStatus.canceladaProfe) continue;
    if (MinutesOfDay(c.session.horaFin) > now) return c;
  }
  return null;
}

/// Los huecos se miden entre clases que sí van a ocurrir: una cancelada deja
/// su tiempo libre y ese tiempo se suma al hueco.
Map<int, DayGap> _gaps(List<DayClass> list) {
  final live = list.where((c) => c.status != SessionStatus.canceladaProfe).toList();
  final ranges = [
    for (final c in live)
      (start: MinutesOfDay(c.session.horaInicio), end: MinutesOfDay(c.session.horaFin)),
  ];
  return {
    for (final g in DayGaps.find(ranges)) live[g.afterIndex].instance.id: g,
  };
}
