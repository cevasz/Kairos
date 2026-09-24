import 'dart:convert';

import 'package:kairos/core/time/minutes_of_day.dart';
import 'package:kairos/domain/import/schedule_parser.dart';
import 'package:kairos/features/import/data/ics_schedule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String _cal(String body) => 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$body\r\nEND:VCALENDAR\r\n';

void main() {
  test('reconoce un .ics por el encabezado, con o sin BOM', () {
    expect(IcsScheduleParser.looksLikeIcs(utf8.encode('﻿BEGIN:VCALENDAR\n')), isTrue);
    expect(IcsScheduleParser.looksLikeIcs(utf8.encode('%PDF-1.7')), isFalse);
  });

  test('un evento semanal con BYDAY es una clase con sus días', () {
    final classes = IcsScheduleParser.parse(_cal('''
BEGIN:VEVENT
SUMMARY:Cálculo Vectorial
DTSTART;TZID=America/Bogota:20260907T070000
DTEND;TZID=America/Bogota:20260907T090000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261130T000000Z
LOCATION:Aula 301\\, Edificio B
DESCRIPTION:Profesor: Ana Ruiz\\nGrupo 2
END:VEVENT'''));
    final c = classes.single;
    expect(c.nombre, 'Cálculo Vectorial');
    expect(c.sessions.map((s) => s.diaSemana), [1, 3]);
    expect(c.sessions.first.inicio, MinutesOfDay.of(7, 0));
    expect(c.sessions.first.fin, MinutesOfDay.of(9, 0));
    expect(c.salon, 'Aula 301, Edificio B');
    expect(c.profesor, 'Ana Ruiz');
    expect(c.isLowConfidence, isFalse);
  });

  test('las líneas partidas (RFC 5545) se unen', () {
    final classes = IcsScheduleParser.parse(_cal('''
BEGIN:VEVENT
SUMMARY:Bases de datos no rela
 cionales
DTSTART:20260908T100000
DTEND:20260908T120000
RRULE:FREQ=WEEKLY
END:VEVENT'''));
    expect(classes.single.nombre, 'Bases de datos no relacionales');
    expect(classes.single.sessions.single.diaSemana, 2);
  });

  test('sueltos que se repiten cada semana son clase; un parcial suelto no', () {
    final classes = IcsScheduleParser.parse(_cal('''
BEGIN:VEVENT
SUMMARY:Física
DTSTART:20260909T140000
DTEND:20260909T160000
END:VEVENT
BEGIN:VEVENT
SUMMARY:Física
DTSTART:20260916T140000
DTEND:20260916T160000
END:VEVENT
BEGIN:VEVENT
SUMMARY:Parcial de Química
DTSTART:20260910T080000
DTEND:20260910T100000
END:VEVENT'''));
    expect(classes.map((c) => c.nombre), ['Física']);
    expect(classes.single.sessions.single.diaSemana, 3);
  });

  test('si nada se repite, se toma todo con duda', () {
    final classes = IcsScheduleParser.parse(_cal('''
BEGIN:VEVENT
SUMMARY:Taller
DTSTART:20260911T080000
DTEND:20260911T100000
END:VEVENT'''));
    expect(classes.single.doubts, contains(ParseDoubt.missingDays));
  });

  test('eventos de todo el día no son clases', () {
    expect(
      IcsScheduleParser.parse(_cal('BEGIN:VEVENT\nSUMMARY:Festivo\nDTSTART;VALUE=DATE:20261012\nEND:VEVENT')),
      isEmpty,
    );
  });
}
