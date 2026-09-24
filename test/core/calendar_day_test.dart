import 'package:kairos/core/time/calendar_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startOfDay', () {
    test('recorta a medianoche local sin mover el día', () {
      final d = startOfDay(DateTime(2026, 9, 7, 23, 59, 59));
      expect(d, DateTime(2026, 9, 7));
    });

    test('medianoche ya es medianoche', () {
      expect(startOfDay(DateTime(2026, 9, 7)), DateTime(2026, 9, 7));
    });
  });

  group('isFutureDay', () {
    final now = DateTime(2026, 9, 7, 14, 30);

    test('mañana es futuro', () {
      expect(isFutureDay(DateTime(2026, 9, 8), now: now), isTrue);
    });

    test('hoy no es futuro, ni siquiera una clase de esta noche', () {
      // El caso que motivó el helper: una sesión de hoy a las 20:00 todavía
      // pertenece al día en curso y tiene que aparecer en el historial.
      expect(isFutureDay(DateTime(2026, 9, 7, 20, 0), now: now), isFalse);
    });

    test('ayer no es futuro', () {
      expect(isFutureDay(DateTime(2026, 9, 6, 23, 59), now: now), isFalse);
    });

    test('cruzar el fin de mes no confunde el orden', () {
      expect(
        isFutureDay(DateTime(2026, 10, 1), now: DateTime(2026, 9, 30, 23, 0)),
        isTrue,
      );
    });
  });
}
