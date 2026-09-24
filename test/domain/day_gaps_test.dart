import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/schedule/day_gaps.dart';
import 'package:flutter_test/flutter_test.dart';

({MinutesOfDay start, MinutesOfDay end}) _r(int h1, int m1, int h2, int m2) =>
    (start: MinutesOfDay.of(h1, m1), end: MinutesOfDay.of(h2, m2));

void main() {
  group('DayGaps', () {
    test('sin clases o con una sola no hay huecos', () {
      expect(DayGaps.find([]), isEmpty);
      expect(DayGaps.find([_r(8, 0, 10, 0)]), isEmpty);
    });

    test('dos clases pegadas no producen hueco', () {
      expect(DayGaps.find([_r(8, 0, 10, 0), _r(10, 0, 12, 0)]), isEmpty);
    });

    test('el cambio de salón no es un hueco', () {
      final gaps = DayGaps.find([_r(8, 0, 10, 0), _r(10, 15, 12, 0)]);
      expect(gaps, isEmpty);
    });

    test('media hora exacta ya es hueco', () {
      final gaps = DayGaps.find([_r(8, 0, 10, 0), _r(10, 30, 12, 0)]);
      expect(gaps, hasLength(1));
      expect(gaps.single.afterIndex, 0);
      expect(gaps.single.minutes, 30);
    });

    test('el hueco se descompone en horas y minutos', () {
      final gap = DayGaps.find([_r(8, 0, 10, 0), _r(11, 45, 13, 0)]).single;
      expect(gap.hours, 1);
      expect(gap.remainderMinutes, 45);
    });

    test('clases solapadas no producen hueco negativo', () {
      expect(DayGaps.find([_r(8, 0, 10, 0), _r(9, 0, 11, 0)]), isEmpty);
    });

    test('varios huecos conservan el índice de la clase anterior', () {
      final gaps = DayGaps.find([
        _r(7, 0, 9, 0),
        _r(9, 0, 11, 0),
        _r(14, 0, 16, 0),
        _r(17, 0, 18, 0),
      ]);
      expect(gaps.map((g) => g.afterIndex), [1, 2]);
      expect(gaps.map((g) => g.minutes), [180, 60]);
    });
  });
}
