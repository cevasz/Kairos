import '../../../core/time/minutes_of_day.dart';
import '../../../domain/import/schedule_parser.dart';
import 'pdf_text.dart';

/// Parser para la retícula «clásica»: los días arriba, las horas en la
/// primera columna y en cada casilla solo la materia (y a veces el salón o el
/// profesor). Es el horario que arman muchas universidades, colegios y el que
/// la gente se hace en Excel y exporta a PDF (§50).
///
/// ```
///            Lunes        Martes       Miércoles
///   7:00     Cálculo I                 Cálculo I
///            Aula 301                  Aula 301
///   8:00     Cálculo I    Física
///   9:00                  Física
/// ```
///
/// A diferencia de [ColumnScheduleParser], la hora no está dentro de la
/// casilla: sale de la etiqueta de la fila, por coordenada Y. Una materia que
/// ocupa varias filas seguidas el mismo día se une en una sola sesión.
///
/// Dart puro y determinista. Sin encabezado de días o sin etiquetas de hora
/// devuelve vacío y el importador prueba otra cosa.
abstract final class TimeGridParser {
  /// Tolerancia vertical para decir que dos líneas están en el mismo renglón.
  static const double _rowSlack = 4;

  static final RegExp _slotLabel = RegExp(
    r'^(\d{1,2})(?:[:.h](\d{2}))?\s*([ap]\.?\s?m\.?)?\s*(?:(?:-|–|—|a)\s*(\d{1,2})(?:[:.h](\d{2}))?\s*([ap]\.?\s?m\.?)?)?$',
    caseSensitive: false,
  );

  /// «Aula 301», «Salón: 4-201», «Lab. 2» o un código suelto como «301B».
  /// Siempre con un número: «Laboratorio de Física» es una materia.
  static final RegExp _room = RegExp(
    r'^(?=.*\d)(?:sal[oó]n|aula|sala|lab(?:oratorio)?|bloque|edif(?:icio)?|of(?:icina)?)(?:[.:]|\s)\s*[:.]?\s*(.+)$|^([A-Z]?\d{1,2}-?\d{2,3}[A-Z]?)$',
    caseSensitive: false,
  );

  /// «Prof. Ramírez», «Docente: Ana». La abreviatura va seguida de punto,
  /// dos puntos o espacio: «Inglés» no es el ingeniero «lés».
  static final RegExp _teacher = RegExp(
    r'^(?:prof(?:esor|esora)?|docente|dra?|ing)(?:[.:]|\s)\s*[:.]?\s*(.+)$',
    caseSensitive: false,
  );

  static final RegExp _rangeInside = RegExp(
    r'\d{1,2}[:.]\d{2}\s*([ap]\.?\s?m\.?)?\s*(-|–|—|a)\s*\d{1,2}[:.]\d{2}',
    caseSensitive: false,
  );

  static const Map<String, int> _days = {
    'lunes': 1, 'lun': 1,
    'martes': 2, 'mar': 2,
    'miercoles': 3, 'miércoles': 3, 'mie': 3, 'mié': 3,
    'jueves': 4, 'jue': 4,
    'viernes': 5, 'vie': 5,
    'sabado': 6, 'sábado': 6, 'sab': 6, 'sáb': 6,
    'domingo': 7, 'dom': 7,
  };

  static List<ParsedClass> parse(List<PositionedLine> positioned) {
    final lines = positioned.where((l) => l.text.trim().isNotEmpty).toList()
      ..sort((a, b) {
        if (a.pageIndex != b.pageIndex) return a.pageIndex.compareTo(b.pageIndex);
        final dy = a.top.compareTo(b.top);
        return dy != 0 ? dy : a.left.compareTo(b.left);
      });

    final header = _header(lines);
    if (header == null) return const [];
    final columns = header.columns;
    final firstX = columns.first.x;
    final gap = columns.length > 1 ? (columns[1].x - columns[0].x) : 80;

    // Etiquetas de hora: a la izquierda de la primera columna de día.
    final slots = <_Slot>[];
    for (final l in lines) {
      if (l.pageIndex != header.page || l.top <= header.top + _rowSlack) continue;
      if (l.left >= firstX - gap * 0.25) continue;
      final slot = _slotFrom(l);
      if (slot != null) slots.add(slot);
    }
    if (slots.length < 2) return const [];
    slots.sort((a, b) => a.top.compareTo(b.top));
    // Sin a.m./p.m. las horas se escriben de 1 a 12: «12:00, 1:00, 2:00».
    // Bajando por la columna la hora solo crece, así que la que retrocede es
    // de la tarde.
    for (var i = 1; i < slots.length; i++) {
      final prev = slots[i - 1].start;
      final cur = slots[i];
      if (cur.start <= prev && cur.start.hour < 12) {
        final end = cur.end;
        slots[i] = _Slot(cur.top, cur.start.plus(12 * 60), end == null || end.hour >= 12 ? end : end.plus(12 * 60));
      }
    }

    // Casillas: cada línea de la retícula cae en un (día, fila).
    final cells = <(int, int), List<String>>{};
    var ownTimes = 0;
    for (final l in lines) {
      if (l.pageIndex != header.page || l.top <= header.top + _rowSlack) continue;
      if (l.left < firstX - gap * 0.25) continue;
      final center = (l.left + l.right) / 2;
      final col = _nearest(columns, l.left, center, gap);
      if (col == null) continue;
      final row = _rowOf(slots, l.top);
      if (row == null) continue;
      if (_rangeInside.hasMatch(l.text)) ownTimes++;
      if (_slotLabel.hasMatch(l.text.trim())) continue; // una hora suelta no es materia
      cells.putIfAbsent((col.day, row), () => []).add(l.text.trim());
    }
    if (cells.isEmpty) return const [];

    // Si las casillas traen su propia hora («9:00 am-11:00 am»), la retícula
    // es de las que llevan la hora adentro (la de «Servicios académicos»):
    // no es este formato y leerla por filas inventaría clases.
    if (ownTimes >= 2) return const [];

    // Cada casilla: nombre, salón y profesor.
    final byName = <String, _Acc>{};
    final days = cells.keys.map((k) => k.$1).toSet().toList()..sort();
    for (final day in days) {
      final rows = cells.keys.where((k) => k.$1 == day).map((k) => k.$2).toList()..sort();
      _Cell? open;
      void close() {
        final c = open;
        if (c == null) return;
        final acc = byName.putIfAbsent(_key(c.name), () => _Acc(c.name));
        acc.teacher ??= c.teacher;
        acc.sessions.add(ParsedSession(
          diaSemana: day,
          inicio: slots[c.firstRow].start,
          fin: _endOf(slots, c.lastRow),
          salon: c.room,
        ));
        open = null;
      }

      for (final row in rows) {
        final cell = _Cell.from(cells[(day, row)]!, row);
        if (cell == null) continue;
        final prev = open;
        // La misma materia en la fila siguiente es la misma clase que sigue.
        if (prev != null && prev.lastRow == row - 1 && _key(prev.name) == _key(cell.name)) {
          prev.lastRow = row;
          prev.room ??= cell.room;
          prev.teacher ??= cell.teacher;
          continue;
        }
        close();
        open = cell;
      }
      close();
    }

    return [
      for (final a in byName.values)
        ParsedClass(
          nombre: a.name,
          profesor: a.teacher,
          salon: a.sessions.map((s) => s.salon).whereType<String>().firstOrNull,
          sessions: a.sessions,
          doubts: {
            for (final s in a.sessions)
              if (!(s.fin > s.inicio)) ParseDoubt.badRange,
          },
        ),
    ];
  }

  static String _key(String name) => name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static _Header? _header(List<PositionedLine> lines) {
    for (final line in lines) {
      // Todos los días en una sola línea: la X de cada uno se estima por la
      // posición del carácter.
      final inLine = _dayTokens(line.text);
      if (inLine.length >= 2) {
        final perChar = (line.right - line.left) / line.text.length;
        return _Header(line.pageIndex, line.top, [
          for (final (day, index, len) in inLine) _Column(day, line.left + (index + len / 2) * perChar),
        ]);
      }
      if (inLine.length == 1) {
        final row = lines.where((l) => l.pageIndex == line.pageIndex && (l.top - line.top).abs() <= _rowSlack);
        final cols = <_Column>[];
        for (final l in row) {
          final t = _dayTokens(l.text);
          if (t.length == 1 && l.text.trim().length <= 12) cols.add(_Column(t.single.$1, (l.left + l.right) / 2));
        }
        if (cols.length >= 2) {
          cols.sort((a, b) => a.x.compareTo(b.x));
          return _Header(line.pageIndex, line.top, cols);
        }
      }
    }
    return null;
  }

  /// Los días escritos en [text], como palabra completa: `(día, índice, largo)`.
  static List<(int, int, int)> _dayTokens(String text) {
    final out = <(int, int, int)>[];
    for (final m in RegExp(r'[a-záéíóúñ]+', caseSensitive: false).allMatches(text)) {
      final w = m.group(0)!.toLowerCase();
      final day = _days[w];
      if (day != null && !out.any((t) => t.$1 == day)) out.add((day, m.start, w.length));
    }
    return out;
  }

  static _Column? _nearest(List<_Column> cols, double left, double center, num gap) {
    _Column? best;
    var bestD = double.infinity;
    for (final c in cols) {
      // El texto puede ir centrado o alineado a la izquierda de su casilla.
      final d = [(center - c.x).abs(), (left - (c.x - gap / 2)).abs()].reduce((a, b) => a < b ? a : b);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return bestD <= gap * 0.75 ? best : null;
  }

  /// La fila de [top]: la última etiqueta de hora que está a su altura o
  /// encima. El texto de una casilla puede bajar varias líneas.
  static int? _rowOf(List<_Slot> slots, double top) {
    int? row;
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].top <= top + _rowSlack) row = i;
    }
    return row;
  }

  static MinutesOfDay _endOf(List<_Slot> slots, int row) {
    final s = slots[row];
    if (s.end != null) return s.end!;
    if (row + 1 < slots.length) return slots[row + 1].start;
    // La última fila sin fin explícito dura lo que la anterior.
    final len = row > 0 ? slots[row - 1].start.difference(s.start) : 60;
    return s.start.plus(len > 0 ? len : 60);
  }

  static _Slot? _slotFrom(PositionedLine l) {
    final m = _slotLabel.firstMatch(l.text.trim().toLowerCase());
    if (m == null) return null;
    final start = _time(m.group(1), m.group(2), m.group(3) ?? m.group(6));
    if (start == null) return null;
    final end = m.group(4) == null ? null : _time(m.group(4), m.group(5), m.group(6) ?? m.group(3), after: start);
    return _Slot(l.top, start, end);
  }

  static MinutesOfDay? _time(String? h, String? mm, String? ampm, {MinutesOfDay? after}) {
    if (h == null) return null;
    var hour = int.parse(h);
    final minute = mm == null ? 0 : int.parse(mm);
    if (hour > 23 || minute > 59) return null;
    final pm = ampm != null && ampm.startsWith('p');
    final am = ampm != null && ampm.startsWith('a');
    if (pm && hour < 12) hour += 12;
    if (am && hour == 12) hour = 0;
    var t = MinutesOfDay.of(hour, minute);
    if (after != null && t <= after && hour < 12) t = t.plus(12 * 60);
    return t;
  }
}

class _Header {
  const _Header(this.page, this.top, this.columns);
  final int page;
  final double top;
  final List<_Column> columns;
}

class _Column {
  const _Column(this.day, this.x);
  final int day;
  final double x;
}

class _Slot {
  const _Slot(this.top, this.start, this.end);
  final double top;
  final MinutesOfDay start;
  final MinutesOfDay? end;
}

class _Cell {
  _Cell(this.name, this.room, this.teacher, this.firstRow) : lastRow = firstRow;

  final String name;
  String? room;
  String? teacher;
  final int firstRow;
  int lastRow;

  static _Cell? from(List<String> texts, int row) {
    final name = <String>[];
    String? room;
    String? teacher;
    for (final t in texts) {
      final r = TimeGridParser._room.firstMatch(t);
      if (r != null && room == null) {
        room = (r.group(1) ?? r.group(2))!.trim();
        continue;
      }
      final p = TimeGridParser._teacher.firstMatch(t);
      if (p != null && teacher == null) {
        teacher = p.group(1)!.trim();
        continue;
      }
      name.add(t);
    }
    if (name.isEmpty) return null;
    return _Cell(name.join(' '), room, teacher, row);
  }
}

class _Acc {
  _Acc(this.name);
  final String name;
  String? teacher;
  final List<ParsedSession> sessions = [];
}
