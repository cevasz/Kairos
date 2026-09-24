import 'dart:math' as math;

import '../../core/time/minutes_of_day.dart';
import 'departure.dart';

/// De dónde sale el número del trayecto. La pantalla lo dice para que se
/// sepa por qué la hora de salida es la que es.
enum TravelSource {
  /// La tabla fija por modo (15 / 35 / 20).
  table,

  /// La ruta por calles entre casa y el campus (OSRM).
  route,

  /// Lo que la persona fijó en Ajustes.
  custom,

  /// El número de partida corregido con viajes reales.
  learned,
}

/// Un viaje medido: salió de casa a [leftAt] y tardó [minutes] en llegar.
class TripSample {
  const TripSample({required this.leftAt, required this.minutes, required this.mode});

  final DateTime leftAt;
  final int minutes;
  final TransportMode mode;
}

class TravelEstimate {
  const TravelEstimate({
    required this.minutes,
    required this.source,
    required this.samples,
    required this.prior,
  });

  /// El trayecto que se usa para la hora de salida.
  final int minutes;
  final TravelSource source;

  /// Cuántos viajes reales pesaron en el número. Cero si no aprendió nada.
  final int samples;

  /// El número de partida, antes de los viajes.
  final int prior;
}

/// Cuánto se tarda en llegar a la U, cada vez mejor.
///
/// Parte de un número (lo que la persona fijó, la ruta por calles o la tabla)
/// y lo corrige con los viajes que la app midió: «Ya voy» al salir de casa y
/// «Llegué» al entrar. Los viajes recientes, del mismo día de la semana y de
/// la misma franja horaria pesan más: el bus de las 6:30 no es el de las 11.
///
/// Dart puro: sin reloj ni base, todo entra por parámetro.
abstract final class TravelEstimator {
  /// Viajes por fuera de esto son un olvido de tocar «Llegué», no un trayecto.
  static const int minTripMinutes = 3;
  static const int maxTripMinutes = 180;

  /// El número de partida vale como tantos viajes. Con uno o dos viajes raros
  /// no se tira el número que la persona conoce; con diez, mandan los viajes.
  static const double priorWeight = 3;

  /// Un viaje de hace un mes y medio pesa la mitad que uno de hoy: cambian el
  /// semestre, las obras y la ruta del bus.
  static const int halfLifeDays = 45;

  /// Más peso a los viajes del mismo día de la semana y de la misma franja.
  static const double sameWeekdayBoost = 1.5;
  static const double sameSlotBoost = 1.5;
  static const int slotMinutes = 60;

  /// Solo se miran los viajes de este periodo.
  static const int lookbackDays = 120;

  /// En bus se tarda lo que en carro más la espera y las paradas. Sin datos de
  /// transporte público en OpenStreetMap, es lo más honesto que hay.
  static int busFromCar(int carMinutes) => (carMinutes * 1.5).round() + 10;

  /// El número de partida para [mode], en orden de confianza: lo que la
  /// persona midió, la ruta por calles, la tabla.
  static (int, TravelSource) prior({
    required TransportMode mode,
    int? custom,
    int? walkRoute,
    int? carRoute,
  }) {
    if (custom != null) return (custom, TravelSource.custom);
    final route = switch (mode) {
      TransportMode.walk => walkRoute,
      TransportMode.car => carRoute,
      TransportMode.bus => carRoute == null ? null : busFromCar(carRoute),
    };
    if (route != null) {
      return (
        route.clamp(DeparturePlanner.minTravelMinutes, DeparturePlanner.maxTravelMinutes),
        TravelSource.route,
      );
    }
    return (DeparturePlanner.fallbackTravelMinutes[mode]!, TravelSource.table);
  }

  static bool isPlausible(int minutes) => minutes >= minTripMinutes && minutes <= maxTripMinutes;

  /// El trayecto para salir el día [weekday] (1 = lunes) hacia las
  /// [leaveAround]. Sin viajes útiles devuelve el número de partida tal cual.
  static TravelEstimate estimate({
    required TransportMode mode,
    required int prior,
    required TravelSource priorSource,
    required List<TripSample> trips,
    required DateTime now,
    int? weekday,
    MinutesOfDay? leaveAround,
  }) {
    final useful = [
      for (final t in trips)
        if (t.mode == mode &&
            isPlausible(t.minutes) &&
            !t.leftAt.isAfter(now) &&
            now.difference(t.leftAt).inDays <= lookbackDays)
          t,
    ];
    final kept = _withoutOutliers(useful);
    if (kept.isEmpty) {
      return TravelEstimate(minutes: prior, source: priorSource, samples: 0, prior: prior);
    }

    var sumW = 0.0;
    var sumWx = 0.0;
    final weights = <double>[];
    for (final t in kept) {
      final ageDays = now.difference(t.leftAt).inHours / 24;
      var w = math.pow(0.5, ageDays / halfLifeDays).toDouble();
      if (weekday != null && t.leftAt.weekday == weekday) w *= sameWeekdayBoost;
      if (leaveAround != null) {
        final at = MinutesOfDay.of(t.leftAt.hour, t.leftAt.minute);
        if (at.difference(leaveAround).abs() <= slotMinutes) w *= sameSlotBoost;
      }
      weights.add(w);
      sumW += w;
      sumWx += w * t.minutes;
    }
    final mean = (priorWeight * prior + sumWx) / (priorWeight + sumW);

    // Si los viajes varían mucho, mejor salir un poco antes: llegar temprano
    // cuesta menos que llegar tarde. Medio desvío, con tope de 10 min.
    var caution = 0.0;
    if (kept.length >= 3) {
      final tripMean = sumWx / sumW;
      var varSum = 0.0;
      for (var i = 0; i < kept.length; i++) {
        varSum += weights[i] * math.pow(kept[i].minutes - tripMean, 2);
      }
      caution = math.min(10, 0.5 * math.sqrt(varSum / sumW));
    }

    final minutes = (mean + caution)
        .ceil()
        .clamp(DeparturePlanner.minTravelMinutes, DeparturePlanner.maxTravelMinutes);
    return TravelEstimate(
      minutes: minutes,
      source: TravelSource.learned,
      samples: kept.length,
      prior: prior,
    );
  }

  /// Con cuatro viajes o más se descartan los que se alejan mucho de la
  /// mediana: el día del paro o el que se olvidó de tocar «Llegué».
  static List<TripSample> _withoutOutliers(List<TripSample> trips) {
    if (trips.length < 4) return trips;
    final sorted = [for (final t in trips) t.minutes]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd ? sorted[mid].toDouble() : (sorted[mid - 1] + sorted[mid]) / 2;
    final tolerance = math.max(10, 0.6 * median);
    return [for (final t in trips) if ((t.minutes - median).abs() <= tolerance) t];
  }
}
