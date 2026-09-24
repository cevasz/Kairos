import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/platform/route_client.dart';
import '../../../core/providers.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../domain/departure/departure.dart';
import '../../../domain/departure/travel_estimator.dart';

final routeClientProvider = Provider<RouteClient>((ref) => RouteClient());

/// Los viajes medidos del periodo que mira el estimador. Se vuelve a leer al
/// cambiar de día, no con cada minuto del reloj.
final recentTripsProvider = StreamProvider<List<TripSample>>((ref) {
  final day = ref.watch(todayProvider);
  return ref.watch(tripsDaoProvider).watchRecent(day.add(const Duration(days: 1)));
});

/// El trayecto que manda, ya resuelto: número de partida más viajes. Hoy, los
/// widgets, las alarmas y Ajustes lo piden aquí; nadie más suma trayectos.
class TravelModel {
  const TravelModel({
    required this.mode,
    required this.prior,
    required this.priorSource,
    required this.trips,
    required this.learn,
    required this.now,
  });

  factory TravelModel.from(UserSetting? s, List<TripSample> trips, DateTime now) {
    final mode = s?.modoTransporte ?? TransportMode.walk;
    final (prior, source) = TravelEstimator.prior(
      mode: mode,
      custom: s?.trayectoMinutos,
      walkRoute: s?.rutaPieMin,
      carRoute: s?.rutaCarroMin,
    );
    return TravelModel(
      mode: mode,
      prior: prior,
      priorSource: source,
      trips: trips,
      learn: s?.aprenderTrayecto ?? true,
      now: now,
    );
  }

  final TransportMode mode;
  final int prior;
  final TravelSource priorSource;
  final List<TripSample> trips;
  final bool learn;
  final DateTime now;

  /// El trayecto para salir el día [weekday] hacia la clase de [classStart].
  /// La franja se busca alrededor de la hora de salida con el número de
  /// partida: es la hora a la que se miden los viajes.
  TravelEstimate forClass({required int weekday, required MinutesOfDay classStart, int buffer = 0}) =>
      TravelEstimator.estimate(
        mode: mode,
        prior: prior,
        priorSource: priorSource,
        trips: learn ? trips : const [],
        now: now,
        weekday: weekday,
        leaveAround: classStart.minus(prior + buffer),
      );

  /// Sin día ni hora: el número general, para Ajustes y las alarmas semanales
  /// cuando no se sabe más.
  TravelEstimate get overall => TravelEstimator.estimate(
        mode: mode,
        prior: prior,
        priorSource: priorSource,
        trips: learn ? trips : const [],
        now: now,
      );
}

final travelModelProvider = Provider<TravelModel>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  final trips = ref.watch(recentTripsProvider).valueOrNull ?? const [];
  return TravelModel.from(settings, trips, ref.watch(todayProvider));
});

/// El centro del campus: el promedio de los salones ubicados en el mapa. Null
/// hasta que haya al menos uno.
final campusPointProvider = StreamProvider<GeoPoint?>((ref) {
  return ref.watch(scheduleDaoProvider).watchLiveSessions().map((rows) {
    final seen = <int>{};
    var lat = 0.0, lng = 0.0, n = 0;
    for (final (_, _, room) in rows) {
      if (room == null || room.lat == null || room.lng == null || !seen.add(room.id)) continue;
      lat += room.lat!;
      lng += room.lng!;
      n++;
    }
    return n == 0 ? null : (lat: lat / n, lng: lng / n);
  });
});

enum RouteCalcResult { ok, noHome, noCampus, offline }

/// Calcula la ruta por calles de casa al campus y la guarda. La llama
/// Ajustes con un botón: es una petición a un servidor ajeno y no se repite
/// sola.
final calculateRouteProvider = Provider<Future<RouteCalcResult> Function()>((ref) {
  return () async {
    final s = await ref.read(settingsDaoProvider).get();
    if (s.homeLat == null || s.homeLng == null) return RouteCalcResult.noHome;
    final campus = await ref.read(campusPointProvider.future);
    if (campus == null) return RouteCalcResult.noCampus;
    final home = (lat: s.homeLat!, lng: s.homeLng!);
    final client = ref.read(routeClientProvider);
    final (walk, car) = await (client.walkMinutes(home, campus), client.carMinutes(home, campus)).wait;
    if (walk == null && car == null) return RouteCalcResult.offline;
    await ref.read(settingsDaoProvider).setRouteMinutes(walk: walk, car: car);
    return RouteCalcResult.ok;
  };
});

/// «Ya voy» saliendo de casa empieza a medir; «Llegué» lo cierra. Un viaje
/// que nadie cerró en tres horas ya no dice nada y se descarta.
const Duration kTripExpiry = Duration(hours: 3);

final tripInProgressProvider = Provider<DateTime?>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  final from = s?.enCaminoDesde;
  if (from == null) return null;
  final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  return now.difference(from) > kTripExpiry ? null : from;
});
