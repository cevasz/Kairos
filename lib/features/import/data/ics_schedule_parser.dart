import 'dart:convert';

import '../../../core/time/minutes_of_day.dart';
import '../../../domain/import/parsed_schedule.dart';

/// Horarios que llegan como calendario (.ics): lo que exportan Google
/// Calendar, Outlook/Teams, Moodle y varios portales académicos (§50).
///
/// Cada evento semanal (`RRULE:FREQ=WEEKLY;BYDAY=MO,WE`) es una clase con sus
/// días. Un evento sin repetición solo cuenta si el mismo título se repite a
/// la misma hora el mismo día de la semana en dos semanas o más: un parcial
/// suelto no es una clase. Si el calendario no tiene nada repetido, se toman
/// todos, con duda, para que la persona decida.
///
/// Dart puro. Las horas en UTC (`…Z`) se pasan a la hora local del teléfono.
abstract final class IcsScheduleParser {
  static bool looksLikeIcs(List<int> bytes) {
    final head = utf8
        .decode(bytes.take(64).toList(), allowMalformed: true)
        .replaceAll('﻿', '')
        .trimLeft()
        .toUpperCase();
    return head.startsWith('BEGIN:VCALENDAR');
  }

  static const Map<String, int> _byDay = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};

  static List<ParsedClass> parse(String ics) {
    final events = _events(_unfold(ics));
    final weekly = <_Occurrence>[];
    final single = <_Occurrence>[];
    for (final e in events) {
      final start = e.start;
      final end = e.end ?? start?.add(const Duration(hours: 1));
      final title = e.summary?.trim();
      if (start == null || end == null || title == null || title.isEmpty) continue;
      final from = MinutesOfDay.of(start.hour, start.minute);
      final to = MinutesOfDay.of(end.hour, end.minute);
      final rule = e.rrule?.toUpperCase();
      if (rule != null && rule.contains('FREQ=WEEKLY')) {
        final days = RegExp(r'BYDAY=([A-Z,0-9+-]+)').firstMatch(rule)?.group(1);
        final list = days == null
            ? [start.weekday]
            : [
                for (final d in days.split(','))
                  if (_byDay[d.replaceAll(RegExp(r'[^A-Z]'), '')] != null) _byDay[d.replaceAll(RegExp(r'[^A-Z]'), '')]!,
              ];
        for (final day in list) {
          weekly.add(_Occurrence(title, day, from, to, e.location, e.teacher, start));
        }
      } else {
        single.add(_Occurrence(title, start.weekday, from, to, e.location, e.teacher, start));
      }
    }

    // Los sueltos que se repiten semana a semana son clases.
    final groups = <String, List<_Occurrence>>{};
    for (final o in single) {
      groups.putIfAbsent('${o.title.toLowerCase()}|${o.day}|${o.from.raw}|${o.to.raw}', () => []).add(o);
    }
    final repeated = [
      for (final g in groups.values)
        if (g.map((o) => _weekOf(o.at)).toSet().length >= 2) g.first,
    ];
    var chosen = [...weekly, ...repeated];
    var doubtful = false;
    if (chosen.isEmpty && single.isNotEmpty) {
      chosen = [for (final g in groups.values) g.first];
      doubtful = true;
    }

    final byName = <String, List<_Occurrence>>{};
    for (final o in chosen) {
      byName.putIfAbsent(o.title.toLowerCase(), () => []).add(o);
    }
    return [
      for (final list in byName.values)
        ParsedClass(
          nombre: list.first.title,
          profesor: list.map((o) => o.teacher).whereType<String>().firstOrNull,
          salon: list.map((o) => o.room).whereType<String>().firstOrNull,
          sessions: {
            for (final o in list) ParsedSession(diaSemana: o.day, inicio: o.from, fin: o.to, salon: o.room),
          }.toList()
            ..sort((a, b) => a.diaSemana != b.diaSemana
                ? a.diaSemana.compareTo(b.diaSemana)
                : a.inicio.raw.compareTo(b.inicio.raw)),
          doubts: {
            if (doubtful) ParseDoubt.missingDays,
            for (final o in list)
              if (!(o.to > o.from)) ParseDoubt.badRange,
          },
        ),
    ];
  }

  static int _weekOf(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2000, 1, 3)).inDays ~/ 7;

  /// RFC 5545: una línea que empieza con espacio o tab continúa la anterior.
  static List<String> _unfold(String raw) {
    final out = <String>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
        out[out.length - 1] += line.substring(1);
      } else {
        out.add(line);
      }
    }
    return out;
  }

  static List<_Event> _events(List<String> lines) {
    final events = <_Event>[];
    _Event? cur;
    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        cur = _Event();
        continue;
      }
      if (line == 'END:VEVENT') {
        if (cur != null) events.add(cur);
        cur = null;
        continue;
      }
      final e = cur;
      if (e == null) continue;
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final nameAndParams = line.substring(0, colon);
      final value = line.substring(colon + 1);
      final name = nameAndParams.split(';').first.toUpperCase();
      switch (name) {
        case 'SUMMARY':
          e.summary = _text(value);
        case 'LOCATION':
          final loc = _text(value).trim();
          e.location = loc.isEmpty ? null : loc;
        case 'DESCRIPTION':
          final m = RegExp(r'(?:profesor(?:a)?|docente|teacher|instructor)\s*[:.]?\s*([^\n,;]+)', caseSensitive: false)
              .firstMatch(_text(value));
          e.teacher = m?.group(1)?.trim();
        case 'DTSTART':
          e.start = _date(value);
        case 'DTEND':
          e.end = _date(value);
        case 'RRULE':
          e.rrule = value;
      }
    }
    return events;
  }

  static String _text(String v) =>
      v.replaceAll(r'\n', '\n').replaceAll(r'\N', '\n').replaceAll(r'\,', ',').replaceAll(r'\;', ';').replaceAll(r'\\', r'\');

  /// `20260907T070000`, `20260907T120000Z` o solo fecha (evento de todo el
  /// día: no es una clase, se descarta).
  static DateTime? _date(String v) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$').firstMatch(v.trim());
    if (m == null) return null;
    final parts = [for (var i = 1; i <= 6; i++) int.parse(m.group(i) ?? '0')];
    if (m.group(7) != null) {
      return DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]).toLocal();
    }
    return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  }
}

class _Event {
  String? summary;
  String? location;
  String? teacher;
  DateTime? start;
  DateTime? end;
  String? rrule;
}

class _Occurrence {
  const _Occurrence(this.title, this.day, this.from, this.to, this.room, this.teacher, this.at);
  final String title;
  final int day;
  final MinutesOfDay from;
  final MinutesOfDay to;
  final String? room;
  final String? teacher;
  final DateTime at;
}
