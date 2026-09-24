import 'package:kairos/domain/alarms/alarm_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Martes y jueves Física a las 8:00, lunes Química a las 7:00 y a las 14:00
  // Álgebra el martes. Salir = inicio − 20 (15 de trayecto + 5 de buffer).
  const classes = [
    WeeklyClass(subject: 'Física', weekday: 2, start: 8 * 60),
    WeeklyClass(subject: 'Física', weekday: 4, start: 8 * 60),
    WeeklyClass(subject: 'Química', weekday: 1, start: 7 * 60),
    WeeklyClass(subject: 'Álgebra', weekday: 2, start: 14 * 60),
  ];

  test('despertar: una por hora distinta, juntando los días que coinciden', () {
    final alarms = AlarmPlanner.weekly(
      classes: classes,
      leaveOffset: 20,
      wake: true,
      wakeMinutes: 60,
      leave: false,
    );
    expect(alarms, [
      const PlannedAlarm(kind: AlarmKind.wake, minute: 5 * 60 + 40, weekdays: [1]),
      const PlannedAlarm(kind: AlarmKind.wake, minute: 6 * 60 + 40, weekdays: [2, 4]),
    ]);
  });

  test('salir: por clase y hora, con todos sus días', () {
    final alarms = AlarmPlanner.weekly(
      classes: classes,
      leaveOffset: 20,
      wake: false,
      wakeMinutes: 60,
      leave: true,
    );
    expect(alarms, [
      const PlannedAlarm(kind: AlarmKind.leave, minute: 6 * 60 + 40, weekdays: [1], subject: 'Química'),
      const PlannedAlarm(kind: AlarmKind.leave, minute: 7 * 60 + 40, weekdays: [2, 4], subject: 'Física'),
      const PlannedAlarm(kind: AlarmKind.leave, minute: 13 * 60 + 40, weekdays: [2], subject: 'Álgebra'),
    ]);
    expect(alarms[1].hour, 7);
    expect(alarms[1].minuteOfHour, 40);
  });

  test('una clase a medianoche no genera una hora negativa', () {
    final alarms = AlarmPlanner.weekly(
      classes: const [WeeklyClass(subject: 'Madrugada', weekday: 3, start: 10)],
      leaveOffset: 20,
      wake: true,
      wakeMinutes: 60,
      leave: true,
    );
    expect(alarms.every((a) => a.minute >= 0), isTrue);
  });

  test('sin clases no hay alarmas', () {
    expect(
      AlarmPlanner.weekly(classes: const [], leaveOffset: 20, wake: true, wakeMinutes: 60, leave: true),
      isEmpty,
    );
  });

  test('avisos de evaluación: la víspera a la hora pedida, solo los que no pasaron', () {
    final now = DateTime(2026, 9, 22, 21);
    final reminders = AlarmPlanner.evaluationReminders(
      evaluations: [
        DatedEvaluation(id: 1, name: 'Parcial 1', subject: 'Física', date: DateTime(2026, 9, 25)),
        // La víspera fue hoy a las 20:00: ya pasó.
        DatedEvaluation(id: 2, name: 'Quiz', subject: 'Química', date: DateTime(2026, 9, 23)),
        DatedEvaluation(id: 3, name: 'Taller', subject: 'Álgebra', date: DateTime(2026, 9, 24)),
      ],
      reminderMinute: 20 * 60,
      now: now,
    );
    expect(reminders.map((r) => r.evaluation.id), [3, 1]);
    expect(reminders.first.at, DateTime(2026, 9, 23, 20));
  });

  test('entre dos clases seguidas no hay alarma de salir: ya estás en la U', () {
    final alarms = AlarmPlanner.weekly(
      classes: const [
        WeeklyClass(subject: 'Lengua', weekday: 3, start: 7 * 60, end: 9 * 60),
        WeeklyClass(subject: 'Cálculo', weekday: 3, start: 11 * 60, end: 13 * 60),
        WeeklyClass(subject: 'Empresarial', weekday: 3, start: 14 * 60, end: 16 * 60),
      ],
      leaveOffset: 35,
      wake: false,
      wakeMinutes: 60,
      leave: true,
      travelMinutes: 30,
    );
    expect(alarms.map((a) => a.subject), ['Lengua', 'Cálculo'],
        reason: 'Cálculo: 2 h de hueco dan para volver a casa; Empresarial, a una hora, no');
  });
}
