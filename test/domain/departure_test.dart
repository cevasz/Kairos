import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/departure/departure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MinutesOfDay', () {
    test('rechaza horas fuera de rango', () {
      expect(() => MinutesOfDay.of(24, 0), throwsRangeError);
      expect(() => MinutesOfDay.of(10, 60), throwsRangeError);
    });

    test('formatea sin fecha', () {
      expect(MinutesOfDay.of(8, 5).hhmm, '8:05');
      expect(MinutesOfDay.of(13, 0).hhmm, '13:00');
    });

    test('se ancla a un día concreto sin arrastrar zona horaria', () {
      final d = MinutesOfDay.of(10, 0).onDay(DateTime(2026, 9, 1));
      expect(d, DateTime(2026, 9, 1, 10, 0));
    });
  });

  group('DeparturePlanner', () {
    test('el caso del prototipo: clase 10:00, 8 min a pie, buffer 4', () {
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(10, 0),
        now: MinutesOfDay.of(9, 41),
        travelMinutes: 8,
        bufferMinutes: 4,
        mode: TransportMode.walk,
      );
      expect(p.leaveAt.hhmm, '9:48');
      expect(p.minutesUntilLeave, 7);
      expect(p.arrivalMargin, 4, reason: 'es el «llegas 4 antes» de la pantalla');
      expect(p.urgency, DepartureUrgency.soon);
    });

    test('sin buffer la salida es hora de clase menos ruta', () {
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(10, 0),
        now: MinutesOfDay.of(9, 41),
        travelMinutes: 8,
        bufferMinutes: 0,
        mode: TransportMode.walk,
      );
      expect(p.leaveAt.hhmm, '9:52');
    });

    test('pasada la hora de salir es «ya»', () {
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(10, 0),
        now: MinutesOfDay.of(9, 53),
        travelMinutes: 8,
        bufferMinutes: 0,
        mode: TransportMode.walk,
      );
      expect(p.minutesUntilLeave, lessThanOrEqualTo(0));
      expect(p.urgency, DepartureUrgency.now);
      expect(p.isUrgent, isTrue);
    });

    test('empezada la clase el estado es tarde, no «ya»', () {
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(10, 0),
        now: MinutesOfDay.of(10, 5),
        travelMinutes: 8,
        bufferMinutes: 0,
        mode: TransportMode.walk,
      );
      expect(p.urgency, DepartureUrgency.late_);
    });

    test('lejos de la clase la card está en reposo', () {
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(13, 0),
        now: MinutesOfDay.of(9, 41),
        travelMinutes: 8,
        bufferMinutes: 5,
        mode: TransportMode.bus,
      );
      expect(p.urgency, DepartureUrgency.calm);
      expect(p.isUrgent, isFalse);
    });

    test('hay respaldo por modo cuando no hay permiso de ubicación', () {
      expect(DeparturePlanner.fallbackTravelMinutes[TransportMode.walk], 15);
      expect(DeparturePlanner.fallbackTravelMinutes.length, TransportMode.values.length);
    });

    test('el trayecto medido por la persona manda sobre el estimado', () {
      expect(DeparturePlanner.travelMinutesFor(TransportMode.walk, null), 15);
      expect(DeparturePlanner.travelMinutesFor(TransportMode.walk, 30), 30);
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(8, 0),
        now: MinutesOfDay.of(6, 0),
        travelMinutes: DeparturePlanner.travelMinutesFor(TransportMode.bus, 30),
        bufferMinutes: 5,
        mode: TransportMode.bus,
      );
      expect(p.leaveAt, MinutesOfDay.of(7, 25));
    });

    test('se sale de casa en la primera clase o si el hueco da para volver', () {
      expect(DeparturePlanner.leavesFromHome(previousEnd: null, start: MinutesOfDay.of(7, 0), travelMinutes: 30), isTrue);
      // 9:00 → 11:00: dos horas, pero ir, estar una hora y volver pide 2 h.
      expect(
        DeparturePlanner.leavesFromHome(
          previousEnd: MinutesOfDay.of(9, 0),
          start: MinutesOfDay.of(11, 0),
          travelMinutes: 30,
        ),
        isTrue,
      );
      expect(
        DeparturePlanner.leavesFromHome(
          previousEnd: MinutesOfDay.of(9, 0),
          start: MinutesOfDay.of(10, 30),
          travelMinutes: 30,
        ),
        isFalse,
      );
    });

    test('desde la U solo cuenta el margen', () {
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(14, 0),
        now: MinutesOfDay.of(12, 0),
        travelMinutes: 30,
        bufferMinutes: 5,
        mode: TransportMode.walk,
        fromHome: false,
      );
      expect(p.leaveAt, MinutesOfDay.of(13, 55));
      expect(p.travelMinutes, 0);
    });

    test('el buffer por defecto es el mismo que el de UserSettings', () {
      expect(DeparturePlanner.defaultBufferMinutes, 5);
    });
  });

  group('DeparturePlanner.ringProgress', () {
    DeparturePlan planAt(int nowHour, int nowMinute) => DeparturePlanner.plan(
          classStart: MinutesOfDay.of(10, 0),
          now: MinutesOfDay.of(nowHour, nowMinute),
          travelMinutes: 8,
          bufferMinutes: 4,
          mode: TransportMode.walk,
        );

    test('más de una ventana antes, el anillo está vacío', () {
      // Salida 9:48. A las 8:00 faltan 108 min, muy por encima de los 60.
      expect(DeparturePlanner.ringProgress(planAt(8, 0), windowMinutes: 60), 0);
    });

    test('a media ventana el anillo va por la mitad', () {
      // Salida 9:48; a las 9:18 quedan 30 de los 60 min.
      expect(DeparturePlanner.ringProgress(planAt(9, 18), windowMinutes: 60), 0.5);
    });

    test('a la hora de salir el anillo está lleno', () {
      expect(DeparturePlanner.ringProgress(planAt(9, 48), windowMinutes: 60), 1);
    });

    test('pasada la hora de salir no se pasa de lleno', () {
      expect(DeparturePlanner.ringProgress(planAt(9, 55), windowMinutes: 60), 1);
    });

    test('una ventana de cero no divide por cero', () {
      expect(DeparturePlanner.ringProgress(planAt(9, 0), windowMinutes: 0), 1);
    });
  });

  group('Llegada estimada', () {
    DeparturePlan at(int h, int m, {int travel = 30, int buffer = 5}) => DeparturePlanner.plan(
          classStart: MinutesOfDay.of(8, 0),
          now: MinutesOfDay.of(h, m),
          travelMinutes: travel,
          bufferMinutes: buffer,
          mode: TransportMode.bus,
        );

    test('saliendo a tiempo llegas con el margen', () {
      final p = at(7, 0);
      expect(p.leaveAt.hhmm, '7:25');
      expect(p.estimatedArrival.hhmm, '7:55');
      expect(p.arrivalMargin, 5);
      expect(p.leavingLate, isFalse);
    });

    test('el trayecto que la persona elige mueve la llegada', () {
      expect(at(7, 0, travel: 45).leaveAt.hhmm, '7:10');
      expect(at(7, 0, travel: 45).estimatedArrival.hhmm, '7:55');
    });

    test('saliendo tarde se come primero el margen', () {
      // Salida 7:25; a las 7:28, llegas 7:58: aún 2 min antes.
      final p = at(7, 28);
      expect(p.leavingLate, isTrue);
      expect(p.estimatedArrival.hhmm, '7:58');
      expect(p.arrivalMargin, 2);
    });

    test('y después la clase: «si sales ya, llegas 8:07 · 7 min tarde»', () {
      final p = at(7, 37);
      expect(p.estimatedArrival.hhmm, '8:07');
      expect(p.arrivalMargin, -7);
    });

    test('desde la U solo cuenta el margen', () {
      final p = DeparturePlanner.plan(
        classStart: MinutesOfDay.of(10, 0),
        now: MinutesOfDay.of(9, 58),
        travelMinutes: 30,
        bufferMinutes: 5,
        mode: TransportMode.walk,
        fromHome: false,
      );
      expect(p.estimatedArrival.hhmm, '9:58');
      expect(p.arrivalMargin, 2);
    });
  });
}
