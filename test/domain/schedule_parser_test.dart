import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/import/schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleParser', () {
    test('una fila por clase: nombre, día, hora y salón en la misma línea', () {
      final r = ScheduleParser.parse([
        'HORARIO 2026-2',
        'Bases de datos   Martes 10:00 - 12:00   Salón 604',
        'Cálculo III      Lunes 8:00-10:00       Aula 301',
      ]);
      expect(r, hasLength(2));
      expect(r[0].nombre, 'Bases de datos');
      expect(r[0].salon, '604');
      expect(r[0].sessions, [
        ParsedSession(diaSemana: 2, inicio: MinutesOfDay.of(10, 0), fin: MinutesOfDay.of(12, 0)),
      ]);
      expect(r[0].isLowConfidence, isFalse);
      expect(r[1].nombre, 'Cálculo III');
      expect(r[1].salon, '301');
    });

    test('nombre en una línea y horario en la siguiente', () {
      final r = ScheduleParser.parse([
        'Física II',
        'Mar - Jue 14:00-16:00 12-201',
      ]);
      expect(r.single.nombre, 'Física II');
      expect(r.single.salon, '12-201');
      expect(r.single.sessions.map((s) => s.diaSemana), [2, 4]);
      expect(r.single.doubts, {ParseDoubt.nameFromPreviousLine});
    });

    test('encabezado de día y las clases debajo', () {
      final r = ScheduleParser.parse([
        'LUNES',
        '7:00-9:00 Ética 105',
        '10:00-12:00 Bases de datos 604',
        'MIÉRCOLES',
        '7:00-9:00 Ética 105',
      ]);
      expect(r, hasLength(2));
      final etica = r.firstWhere((c) => c.nombre == 'Ética');
      expect(etica.sessions.map((s) => s.diaSemana), [1, 3]);
      expect(etica.salon, '105');
      expect(etica.isLowConfidence, isFalse);
    });

    test('«martes y jueves» produce dos sesiones con la misma hora', () {
      final r = ScheduleParser.parse(['Programación  Martes y Jueves 14:00 a 16:00']);
      expect(r.single.sessions.map((s) => s.diaSemana), [2, 4]);
      expect(r.single.sessions.first.inicio, MinutesOfDay.of(14, 0));
    });

    test('las horas sin minutos y en pm se entienden', () {
      final r = ScheduleParser.parse(['Estadística  Viernes 1-3 pm']);
      final s = r.single.sessions.single;
      expect(s.inicio, MinutesOfDay.of(13, 0));
      expect(s.fin, MinutesOfDay.of(15, 0));
    });

    test('«11-1» sin marcador cruza el mediodía', () {
      final r = ScheduleParser.parse(['Inglés  Lunes 11-1']);
      final s = r.single.sessions.single;
      expect(s.inicio, MinutesOfDay.of(11, 0));
      expect(s.fin, MinutesOfDay.of(13, 0));
    });

    test('el profesor con etiqueta se recoge, en la fila o en la siguiente', () {
      final r = ScheduleParser.parse([
        'Bases de datos  Martes 10:00-12:00  Prof. M. Restrepo',
        'Cálculo III  Lunes 8:00-10:00',
        'Docente: Luis Ordóñez',
      ]);
      expect(r[0].profesor, 'M. Restrepo');
      expect(r[1].profesor, 'Luis Ordóñez');
    });

    test('la misma materia en dos filas se une, no se duplica', () {
      final r = ScheduleParser.parse([
        'Física II  Martes 14:00-16:00  12-201',
        'Física II  Jueves 14:00-16:00  12-201',
      ]);
      expect(r, hasLength(1));
      expect(r.single.sessions, hasLength(2));
    });

    test('hora sin día ni nombre queda con dudas, no se inventa', () {
      final r = ScheduleParser.parse(['10:00-12:00']);
      expect(r.single.nombre, '');
      expect(r.single.doubts, containsAll([ParseDoubt.missingName, ParseDoubt.missingDays]));
      expect(r.single.sessions.single.diaSemana, 0);
    });

    test('un rango al revés se marca', () {
      final r = ScheduleParser.parse(['Química  Lunes 12:00-10:00']);
      expect(r.single.doubts, contains(ParseDoubt.badRange));
    });

    test('un PDF sin texto no produce nada', () {
      expect(ScheduleParser.parse([]), isEmpty);
      expect(ScheduleParser.parse(['', '   ']), isEmpty);
    });

    test('los encabezados de tabla no se toman como nombre', () {
      final r = ScheduleParser.parse([
        'Materia   Día   Hora   Salón',
        'Lunes 8:00-10:00 301',
      ]);
      expect(r.single.nombre, '');
      expect(r.single.doubts, contains(ParseDoubt.missingName));
    });
  });
}
