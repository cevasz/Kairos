import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/import/schedule_parser.dart';
import 'package:kairos/features/import/data/claude_schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClaudeScheduleParser.decode', () {
    test('convierte el JSON estructurado al modelo del dominio', () {
      final r = ClaudeScheduleParser.decode('''
{"clases":[
  {"nombre":"Bases de datos","profesor":"M. Restrepo","salon":"604","dudoso":false,
   "sesiones":[{"dia":2,"inicio":"10:00","fin":"12:00"},{"dia":4,"inicio":"10:00","fin":"12:00"}]},
  {"nombre":"Física II","profesor":null,"salon":null,"dudoso":true,
   "sesiones":[{"dia":5,"inicio":"14:00","fin":"16:00"}]}
]}''');
      expect(r, hasLength(2));
      expect(r[0].nombre, 'Bases de datos');
      expect(r[0].profesor, 'M. Restrepo');
      expect(r[0].sessions, hasLength(2));
      expect(r[0].sessions.first.inicio, MinutesOfDay.of(10, 0));
      expect(r[0].isLowConfidence, isFalse);
      expect(r[1].profesor, isNull);
      expect(r[1].isLowConfidence, isTrue, reason: '«dudoso» se enseña con la insignia');
    });

    test('una hora ilegible descarta la sesión, no la materia', () {
      final r = ClaudeScheduleParser.decode(
        '{"clases":[{"nombre":"X","profesor":null,"salon":null,"dudoso":false,'
        '"sesiones":[{"dia":1,"inicio":"25:00","fin":"26:00"},{"dia":1,"inicio":"8:00","fin":"9:00"}]}]}',
      );
      expect(r.single.sessions, hasLength(1));
    });

    test('nombre vacío y rango al revés se marcan', () {
      final r = ClaudeScheduleParser.decode(
        '{"clases":[{"nombre":"","profesor":null,"salon":null,"dudoso":false,'
        '"sesiones":[{"dia":1,"inicio":"10:00","fin":"08:00"}]}]}',
      );
      expect(r.single.doubts, containsAll([ParseDoubt.missingName, ParseDoubt.badRange]));
    });

    test('JSON roto lanza la excepción propia', () {
      expect(() => ClaudeScheduleParser.decode('no es json'), throwsA(isA<ClaudeParseException>()));
    });
  });
}
