import 'package:kairos/domain/attendance/absence_state.g.dart';
import 'package:kairos/domain/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionStatus', () {
    test('solo faltó gasta cupo', () {
      expect(SessionStatus.falto.countsAsAbsence, isTrue);
      for (final s in [
        SessionStatus.asistio,
        SessionStatus.canceladaProfe,
        SessionStatus.justificada,
        SessionStatus.pendiente,
        SessionStatus.posibleFalta,
      ]) {
        expect(s.countsAsAbsence, isFalse, reason: '$s no debería gastar cupo');
      }
    });

    test('posibleFalta no está resuelta: hay que preguntarle al usuario', () {
      expect(SessionStatus.posibleFalta.isResolved, isFalse);
      expect(SessionStatus.falto.isResolved, isTrue);
    });
  });

  group('AttendanceCounter', () {
    test('el caso del prototipo: 3 de 6 es atención', () {
      final t = AttendanceCounter.tally(
        sessions: const [
          SessionStatus.asistio,
          SessionStatus.falto,
          SessionStatus.canceladaProfe,
          SessionStatus.asistio,
          SessionStatus.falto,
          SessionStatus.falto,
        ],
        limit: 6,
      );
      expect(t.used, 3);
      expect(t.remaining, 3);
      expect(t.cancelledByProfessor, 1);
      expect(t.state, AbsenceState.attention);
    });

    test('las canceladas por el profe no acercan a perder la materia', () {
      final t = AttendanceCounter.tally(
        sessions: List.filled(5, SessionStatus.canceladaProfe),
        limit: 6,
      );
      expect(t.used, 0);
      expect(t.state, AbsenceState.ok);
    });

    test('con el límite por defecto, riesgo entra cuando queda una sola falta', () {
      final t = AttendanceCounter.tally(
        sessions: List.filled(5, SessionStatus.falto),
        limit: 6,
      );
      expect(t.remaining, 1);
      expect(t.state, AbsenceState.risk);
    });

    test('alcanzar el límite es materia perdida', () {
      final t = AttendanceCounter.tally(
        sessions: List.filled(6, SessionStatus.falto),
        limit: 6,
      );
      expect(t.remaining, 0);
      expect(t.isLost, isTrue);
    });

    test('los umbrales son fracción, así que un límite de 3 también funciona', () {
      expect(AttendanceCounter.stateFor(1 / 3), AbsenceState.ok);
      expect(AttendanceCounter.stateFor(2 / 3), AbsenceState.attention);
      expect(AttendanceCounter.stateFor(1.0), AbsenceState.lost);
    });

    test('el shake se dispara una sola vez, al cruzar hacia riesgo', () {
      expect(
        AttendanceCounter.shouldShake(AbsenceState.attention, AbsenceState.risk),
        isTrue,
      );
      expect(
        AttendanceCounter.shouldShake(AbsenceState.risk, AbsenceState.risk),
        isFalse,
        reason: 'no debe repetirse en cada rebuild',
      );
      expect(
        AttendanceCounter.shouldShake(AbsenceState.lost, AbsenceState.risk),
        isFalse,
        reason: 'volver desde perdida no es un primer cruce',
      );
    });
  });
}
