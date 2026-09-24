import 'package:drift/drift.dart';

import '../../../domain/departure/departure.dart';
import '../../../domain/departure/travel_estimator.dart';
import '../database.dart';
import '../tables.dart';

part 'trips_dao.g.dart';

/// Los viajes medidos y el que está en curso. El viaje en curso vive en la
/// fila de ajustes: hay uno solo a la vez y tiene que sobrevivir a cerrar la
/// app entre «Ya voy» y «Llegué».
@DriftAccessor(tables: [Trips, UserSettings])
class TripsDao extends DatabaseAccessor<KairosDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  /// Los viajes del periodo que el estimador mira, del más nuevo al más viejo.
  Stream<List<TripSample>> watchRecent(DateTime now) {
    final since = now.subtract(const Duration(days: TravelEstimator.lookbackDays));
    final q = select(trips)
      ..where((t) => t.salida.isBiggerOrEqualValue(since))
      ..orderBy([(t) => OrderingTerm.desc(t.salida)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            TripSample(leftAt: r.salida, minutes: r.llegada.difference(r.salida).inMinutes, mode: r.modo),
        ]);
  }

  /// «Ya voy» saliendo de casa. Un viaje anterior sin cerrar se pisa: si no
  /// tocaste «Llegué» ayer, ese viaje no se sabe cuánto duró.
  Future<void> start(DateTime at, TransportMode mode) => _settings(
        UserSettingsCompanion(enCaminoDesde: Value(at), enCaminoModo: Value(mode)),
      );

  /// «Llegué». Guarda el viaje si la duración es creíble y devuelve los
  /// minutos, o null si no había viaje o no era creíble.
  Future<int?> arrive(DateTime at) => transaction(() async {
        final s = await (select(userSettings)..where((t) => t.id.equals(1))).getSingle();
        final from = s.enCaminoDesde;
        await discard();
        if (from == null) return null;
        final minutes = at.difference(from).inMinutes;
        if (!TravelEstimator.isPlausible(minutes)) return null;
        await into(trips).insert(TripsCompanion.insert(
          salida: from,
          llegada: at,
          modo: s.enCaminoModo ?? s.modoTransporte,
        ));
        return minutes;
      });

  Future<void> discard() => _settings(
        const UserSettingsCompanion(enCaminoDesde: Value(null), enCaminoModo: Value(null)),
      );

  /// Borra lo aprendido. El número de partida se queda.
  Future<void> forgetAll() => delete(trips).go();

  Future<int> count() async {
    final c = trips.id.count();
    return (await (selectOnly(trips)..addColumns([c])).getSingle()).read(c) ?? 0;
  }

  Future<void> _settings(UserSettingsCompanion data) =>
      (update(userSettings)..where((t) => t.id.equals(1))).write(data);
}
