import 'package:kairos/core/db/daos/schedule_dao.dart';
import 'package:kairos/core/db/database.dart';
import 'package:kairos/core/providers.dart';
import 'package:kairos/domain/attendance/attendance.dart';
import 'package:kairos/domain/departure/departure.dart';
import 'package:kairos/domain/departure/travel_estimator.dart';
import 'package:kairos/features/today/application/today_providers.dart';
import 'package:kairos/features/travel/application/travel_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 9, 8); // martes

DayClass _clase({
  required int id,
  required int inicio,
  required int fin,
  SessionStatus estado = SessionStatus.pendiente,
  DateTime? marcadaEn,
}) =>
    DayClass(
      instance: SessionInstance(
        id: id,
        sessionId: id,
        fecha: _day,
        estado: estado,
        marcadaEn: marcadaEn,
      ),
      session: ClassSession(
        id: id,
        subjectId: 1,
        diaSemana: 2,
        horaInicio: inicio,
        horaFin: fin,
      ),
      subject: const Subject(
        id: 1,
        semesterId: 1,
        nombre: 'Bases de datos',
        colorIndex: 0,
        limiteFaltas: 6,
        archivada: false,
        cancelada: false,
      ),
    );

const _settings = UserSetting(
  id: 1,
  bufferMinutos: 4,
  modoTransporte: TransportMode.bus,
  tema: 0,
  limiteFaltasPorDefecto: 6,
  mascotaEsquina: true,
  alarmaDespertar: true,
  alarmaDespertarMin: 60,
  alarmaSalir: true,
  alarmaEvaluaciones: true,
  avisoEvaluacionMin: 20 * 60,
  detectarCasa: false,
  aprenderTrayecto: true,
  temaPaleta: 'papiro',
);

/// Monta el provider de Hoy con clases, hora y ajustes fijos. Nada toca la BD.
Future<TodayState> _state(
  List<DayClass> classes, {
  required int hour,
  required int minute,
  List<TripSample> trips = const [],
}) async {
  final now = DateTime(_day.year, _day.month, _day.day, hour, minute);
  final container = ProviderContainer(overrides: [
    todayProvider.overrideWith((ref) => _day),
    todayClassesProvider.overrideWith((ref) => Stream.value(classes)),
    clockProvider.overrideWith((ref) => Stream.value(now)),
    settingsProvider.overrideWith((ref) => Stream.value(_settings)),
    recentTripsProvider.overrideWith((ref) => Stream.value(trips)),
  ]);
  addTearDown(container.dispose);

  // Se espera el primer valor de los tres streams para que el provider
  // derivado no vea el loading.
  await container.read(todayClassesProvider.future);
  await container.read(clockProvider.future);
  await container.read(settingsProvider.future);
  await container.read(recentTripsProvider.future);
  return container.read(todayStateProvider).requireValue;
}

void main() {
  group('todayStateProvider', () {
    test('los viajes medidos corrigen el trayecto y la hora de salir (§47)', () async {
      // Bus con la tabla (35 min) y buffer 4: salida 7:21 para las 8:00.
      final plain = await _state([_clase(id: 1, inicio: 480, fin: 600)], hour: 6, minute: 0);
      expect(plain.plan!.leaveAt.hhmm, '7:21');
      // Diez viajes de 50 min los martes a las 7: la salida se adelanta.
      final learned = await _state(
        [_clase(id: 1, inicio: 480, fin: 600)],
        hour: 6,
        minute: 0,
        trips: [
          for (var w = 1; w <= 10; w++)
            TripSample(leftAt: _day.subtract(Duration(days: 7 * w)).add(const Duration(hours: 7)), minutes: 50, mode: TransportMode.bus),
        ],
      );
      expect(learned.plan!.travelMinutes, greaterThanOrEqualTo(45));
      expect(learned.plan!.leaveAt < plain.plan!.leaveAt, isTrue);
      expect(learned.plan!.estimatedArrival.hhmm, '7:56');
    });

    test('la próxima es la primera que no ha terminado', () async {
      final s = await _state(
        [_clase(id: 1, inicio: 480, fin: 600), _clase(id: 2, inicio: 840, fin: 960)],
        hour: 10,
        minute: 30,
      );
      expect(s.next?.instance.id, 2);
      expect(s.isDone, isFalse);
    });

    test('una clase que empezó hace más que la tolerancia ya no es «a la que hay que ir»', () async {
      // Lo que se vio en el teléfono: a las 12:30, «Ya. Camina.» para una
      // clase de 11:00 a 13:00.
      final s = await _state(
        [_clase(id: 1, inicio: 660, fin: 780), _clase(id: 2, inicio: 840, fin: 960)],
        hour: 12,
        minute: 30,
      );
      expect(s.next?.instance.id, 2);
    });

    test('dentro de la tolerancia todavía se va, tarde pero se entra', () async {
      final s = await _state([_clase(id: 1, inicio: 660, fin: 780)], hour: 11, minute: 10);
      expect(s.next?.instance.id, 1);
      expect(s.plan!.toleranceEnd.raw, 660 + DeparturePlanner.lateToleranceMinutes);
    });

    test('una falta (marcada o detectada) no se persigue', () async {
      final s = await _state(
        [
          _clase(id: 1, inicio: 660, fin: 780, estado: SessionStatus.posibleFalta),
          _clase(id: 2, inicio: 840, fin: 960),
        ],
        hour: 10,
        minute: 0,
      );
      expect(s.next?.instance.id, 2);
    });

    test('sin marcar la anterior no se supone nada: se sale de casa', () async {
      // Lo que se vio en el teléfono: «Ya estás en la U» estando en casa.
      final s = await _state(
        [_clase(id: 1, inicio: 660, fin: 780), _clase(id: 2, inicio: 840, fin: 960)],
        hour: 12,
        minute: 56,
      );
      expect(s.next?.instance.id, 2);
      expect(s.plan!.fromHome, isTrue);
    });

    test('tras una clase marcada como asistida, la siguiente cercana no pide salir de casa', () async {
      final s = await _state(
        [_clase(id: 1, inicio: 420, fin: 540, estado: SessionStatus.asistio), _clase(id: 2, inicio: 660, fin: 780)],
        hour: 9,
        minute: 30,
      );
      expect(s.next?.instance.id, 2);
      expect(s.plan!.fromHome, isFalse);
      expect(s.plan!.travelMinutes, 0);
    });

    test('una cancelada se salta y queda como noticia hasta su hora de fin', () async {
      final s = await _state(
        [
          _clase(
            id: 1,
            inicio: 600,
            fin: 720,
            estado: SessionStatus.canceladaProfe,
            marcadaEn: DateTime(2026, 9, 8, 9, 40),
          ),
          _clase(id: 2, inicio: 840, fin: 960),
        ],
        hour: 9,
        minute: 43,
      );
      expect(s.next?.instance.id, 2);
      expect(s.cancelled?.instance.id, 1);
      expect(s.minutesSinceCancelled, 3, reason: 'es el «Marcada hace 3 min» de B3');
    });

    test('pasada su hora, la cancelada deja de ser noticia', () async {
      final s = await _state(
        [_clase(id: 1, inicio: 600, fin: 720, estado: SessionStatus.canceladaProfe)],
        hour: 12,
        minute: 1,
      );
      expect(s.cancelled, isNull);
      expect(s.isDone, isTrue);
    });

    test('«ya voy» avanza la card a la clase de después', () async {
      final s = await _state(
        [
          _clase(id: 1, inicio: 600, fin: 720, estado: SessionStatus.asistio),
          _clase(id: 2, inicio: 840, fin: 960),
        ],
        hour: 9,
        minute: 50,
      );
      expect(s.next?.instance.id, 2);
      expect(s.isUrgent, isFalse);
    });

    test('sin nada por delante el día está hecho, no vacío', () async {
      final s = await _state([_clase(id: 1, inicio: 480, fin: 600)], hour: 18, minute: 0);
      expect(s.isEmpty, isFalse);
      expect(s.isDone, isTrue);
      expect(s.plan, isNull);
    });

    test('el plan usa el buffer y el transporte de Ajustes', () async {
      final s = await _state([_clase(id: 1, inicio: 600, fin: 720)], hour: 8, minute: 0);
      final plan = s.plan!;
      expect(plan.mode, TransportMode.bus);
      expect(plan.bufferMinutes, 4);
      expect(plan.travelMinutes, DeparturePlanner.fallbackTravelMinutes[TransportMode.bus]);
      // 10:00 − 35 de bus − 4 de buffer = 9:21.
      expect(plan.leaveAt.hhmm, '9:21');
    });

    test('los huecos se miden entre clases vivas y saltan la cancelada', () async {
      final s = await _state(
        [
          _clase(id: 1, inicio: 480, fin: 600),
          _clase(id: 2, inicio: 600, fin: 720, estado: SessionStatus.canceladaProfe),
          _clase(id: 3, inicio: 840, fin: 960),
        ],
        hour: 7,
        minute: 0,
      );
      // Tras la clase 1 quedan libres 10:00–14:00: cuatro horas, no dos.
      expect(s.gapsAfter.keys, [1]);
      expect(s.gapsAfter[1]!.minutes, 240);
    });

    test('un cambio de salón no aparece como hueco', () async {
      final s = await _state(
        [_clase(id: 1, inicio: 480, fin: 600), _clase(id: 2, inicio: 615, fin: 720)],
        hour: 7,
        minute: 0,
      );
      expect(s.gapsAfter, isEmpty);
    });
  });
}
