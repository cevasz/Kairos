import 'package:kairos/domain/attendance/attendance.dart';
import 'package:kairos/domain/attendance/home_check.dart';
import 'package:kairos/domain/departure/departure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('se comprueba al acabar la tolerancia', () {
    final at = HomeCheck.checkAt(DateTime(2026, 9, 23), 14 * 60);
    expect(at, DateTime(2026, 9, 23, 14, DeparturePlanner.lateToleranceMinutes));
  });

  group('veredictos', () {
    test('«sigue en casa» anota falta solo en una sesión sin resolver', () {
      expect(HomeCheck.apply(current: SessionStatus.pendiente, verdict: SessionStatus.falto), SessionStatus.falto);
      expect(HomeCheck.apply(current: SessionStatus.posibleFalta, verdict: SessionStatus.falto), SessionStatus.falto);
      expect(HomeCheck.apply(current: SessionStatus.asistio, verdict: SessionStatus.falto), isNull,
          reason: 'si marcaste que fuiste, manda eso');
      expect(HomeCheck.apply(current: SessionStatus.canceladaProfe, verdict: SessionStatus.falto), isNull);
      expect(HomeCheck.apply(current: SessionStatus.justificada, verdict: SessionStatus.falto), isNull);
    });

    test('«Sí fui» deshace la falta automática', () {
      expect(HomeCheck.apply(current: SessionStatus.falto, verdict: SessionStatus.asistio), SessionStatus.asistio);
      expect(HomeCheck.apply(current: SessionStatus.pendiente, verdict: SessionStatus.asistio), SessionStatus.asistio);
      expect(HomeCheck.apply(current: SessionStatus.canceladaProfe, verdict: SessionStatus.asistio), isNull);
    });
  });
}
