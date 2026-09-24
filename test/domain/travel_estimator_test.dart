import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/departure/departure.dart';
import 'package:kairos/domain/departure/travel_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 12); // miércoles

  TripSample trip(int daysAgo, int minutes, {int hour = 7, TransportMode mode = TransportMode.bus}) =>
      TripSample(
        leftAt: DateTime(2026, 9, 23 - daysAgo, hour, 10),
        minutes: minutes,
        mode: mode,
      );

  TravelEstimate estimate(List<TripSample> trips, {int prior = 30, int? weekday, MinutesOfDay? around}) =>
      TravelEstimator.estimate(
        mode: TransportMode.bus,
        prior: prior,
        priorSource: TravelSource.custom,
        trips: trips,
        now: now,
        weekday: weekday,
        leaveAround: around,
      );

  group('número de partida', () {
    test('lo que la persona fijó manda sobre la ruta y la tabla', () {
      expect(TravelEstimator.prior(mode: TransportMode.walk, custom: 30, walkRoute: 12), (30, TravelSource.custom));
    });

    test('sin número propio, la ruta por calles', () {
      expect(TravelEstimator.prior(mode: TransportMode.walk, walkRoute: 12), (12, TravelSource.route));
      expect(TravelEstimator.prior(mode: TransportMode.bus, carRoute: 10), (25, TravelSource.route));
    });

    test('sin nada, la tabla del modo', () {
      expect(TravelEstimator.prior(mode: TransportMode.car), (20, TravelSource.table));
    });
  });

  group('aprender de los viajes', () {
    test('sin viajes devuelve el número de partida', () {
      final e = estimate(const []);
      expect(e.minutes, 30);
      expect(e.source, TravelSource.custom);
      expect(e.samples, 0);
    });

    test('un viaje suelto mueve poco el número', () {
      final e = estimate([trip(1, 50)]);
      expect(e.source, TravelSource.learned);
      expect(e.minutes, inInclusiveRange(34, 36));
    });

    test('con muchos viajes parecidos mandan los viajes', () {
      final e = estimate([for (var i = 1; i <= 12; i++) trip(i, 42 + (i % 3))]);
      expect(e.minutes, inInclusiveRange(40, 45));
      expect(e.samples, 12);
    });

    test('un viaje absurdo no cuenta', () {
      final e = estimate([trip(1, 1), trip(2, 400)]);
      expect(e.samples, 0);
      expect(e.minutes, 30);
    });

    test('el día del paro se descarta', () {
      final e = estimate([trip(1, 40), trip(2, 41), trip(3, 39), trip(4, 40), trip(5, 150)]);
      expect(e.samples, 4);
      expect(e.minutes, lessThan(45));
    });

    test('los viajes de otro modo no cuentan', () {
      final e = estimate([trip(1, 10, mode: TransportMode.walk)]);
      expect(e.samples, 0);
    });

    test('la misma franja horaria pesa más', () {
      final trips = [
        for (var i = 1; i <= 6; i++) trip(i, 50, hour: 6),
        for (var i = 1; i <= 6; i++) trip(i, 25, hour: 11),
      ];
      final early = estimate(trips, prior: 35, around: MinutesOfDay.of(6, 15));
      final late = estimate(trips, prior: 35, around: MinutesOfDay.of(11, 0));
      expect(early.minutes, greaterThan(late.minutes));
    });

    test('lo reciente pesa más que lo de hace meses', () {
      final e = estimate([
        for (var i = 0; i < 5; i++) trip(100 + i, 60),
        for (var i = 1; i <= 5; i++) trip(i, 30),
      ], prior: 30);
      expect(e.minutes, lessThan(45));
    });

    test('nunca sale de los límites de Ajustes', () {
      final e = estimate([for (var i = 1; i <= 20; i++) trip(i, 179)], prior: 120);
      expect(e.minutes, DeparturePlanner.maxTravelMinutes);
    });
  });
}
