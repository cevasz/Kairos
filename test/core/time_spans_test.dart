import 'package:kairos/core/format/durations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los minutos se escriben como los diría una persona', () {
    expect(TimeSpans.minutes(45), '45 min');
    expect(TimeSpans.minutes(60), '1 h');
    expect(TimeSpans.minutes(80), '1 h 20 min');
    expect(TimeSpans.minutes(300), '5 h', reason: 'nunca «300 min»');
    expect(TimeSpans.minutes(-3), '0 min');
  });

  test('en el anillo cabe poco: minutos, o h:mm', () {
    expect(TimeSpans.compact(45), (value: '45', unit: 'min'));
    expect(TimeSpans.compact(245), (value: '4:05', unit: 'h'));
  });
}
