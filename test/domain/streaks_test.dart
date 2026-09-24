import 'package:flutter_test/flutter_test.dart';
import 'package:kairos/domain/attendance/attendance.dart';
import 'package:kairos/domain/streaks/streaks.dart';

/// Hoy es jueves 24 de septiembre de 2026. `tuesdayOf(n)` es el martes de
/// hace n semanas (0 = el de esta semana, el 22).
final DateTime today = DateTime(2026, 9, 24);

DateTime tuesdayOf(int weeksAgo) => DateTime(2026, 9, 22 - 7 * weeksAgo);

DatedStatus s(DateTime d, SessionStatus st) => DatedStatus(d, st);

const done = SessionStatus.asistio;
const skipped = SessionStatus.falto;
const cancelled = SessionStatus.canceladaProfe;
const justified = SessionStatus.justificada;
const pending = SessionStatus.pendiente;

Streak run(List<DatedStatus> sessions) => StreakCounter.compute(sessions, today: today);

void main() {
  test('sin historial no hay racha', () {
    expect(run(const []), Streak.none);
  });

  test('cuatro semanas hechas seguidas, hasta esta: racha de 4', () {
    expect(
      run([for (var w = 3; w >= 0; w--) s(tuesdayOf(w), done)]),
      const Streak(current: 4, best: 4),
    );
  });

  test('un «Saltado» corta la racha; la mejor se recuerda', () {
    final sessions = [
      for (var w = 6; w >= 3; w--) s(tuesdayOf(w), done), // 4 seguidas
      s(tuesdayOf(2), skipped),
      s(tuesdayOf(1), done),
      s(tuesdayOf(0), done),
    ];
    expect(run(sessions), const Streak(current: 2, best: 4));
  });

  test('cancelado y justificado cumplen la semana', () {
    expect(
      run([s(tuesdayOf(2), cancelled), s(tuesdayOf(1), justified), s(tuesdayOf(0), done)]),
      const Streak(current: 3, best: 3),
    );
  });

  test('una semana con dos sesiones necesita las dos', () {
    final sessions = [
      s(tuesdayOf(1), done),
      s(tuesdayOf(1).add(const Duration(days: 2)), skipped), // jueves pasado
      s(tuesdayOf(0), done),
    ];
    expect(run(sessions), const Streak(current: 1, best: 1));
  });

  test('una sesión pasada sin marcar corta en una semana cerrada', () {
    expect(
      run([s(tuesdayOf(2), done), s(tuesdayOf(1), pending), s(tuesdayOf(0), done)]),
      const Streak(current: 1, best: 1),
    );
  });

  test('en la semana en curso, lo sin marcar no suma ni corta', () {
    expect(
      run([s(tuesdayOf(2), done), s(tuesdayOf(1), done), s(tuesdayOf(0), pending)]),
      const Streak(current: 2, best: 2),
    );
  });

  test('un «Saltado» esta semana deja la racha actual en 0', () {
    expect(
      run([s(tuesdayOf(2), done), s(tuesdayOf(1), done), s(tuesdayOf(0), skipped)]),
      const Streak(current: 0, best: 2),
    );
  });

  test('lo futuro y lo pendiente de hoy no cuentan; lo marcado hoy sí', () {
    final sessions = [
      s(tuesdayOf(1), done),
      s(today, pending), // más tarde hoy
      s(DateTime(2026, 9, 29), skipped), // la otra semana: todavía no pasó
    ];
    expect(run(sessions), const Streak(current: 1, best: 1));
    expect(run([s(tuesdayOf(1), done), s(today, done)]), const Streak(current: 2, best: 2));
    expect(run([s(tuesdayOf(1), done), s(today, skipped)]), const Streak(current: 0, best: 1));
  });

  test('una semana sin sesiones (vacaciones) no corta la racha', () {
    expect(
      run([s(tuesdayOf(3), done), s(tuesdayOf(1), done), s(tuesdayOf(0), done)]),
      const Streak(current: 3, best: 3),
    );
  });

  test('el orden de entrada no importa', () {
    final sessions = [s(tuesdayOf(0), done), s(tuesdayOf(2), skipped), s(tuesdayOf(1), done)];
    expect(run(sessions), const Streak(current: 2, best: 2));
  });

  test('las semanas van de lunes a domingo', () {
    // Domingo 20 y lunes 21: semanas distintas. El domingo saltado es de la
    // semana pasada, que queda rota; esta semana va cumplida.
    expect(
      run([s(DateTime(2026, 9, 14), done), s(DateTime(2026, 9, 20), skipped), s(DateTime(2026, 9, 21), done)]),
      const Streak(current: 1, best: 1),
    );
  });
}
