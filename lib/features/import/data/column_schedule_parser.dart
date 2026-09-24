import '../../../core/time/minutes_of_day.dart';
import '../../../domain/import/schedule_parser.dart';
import 'pdf_text.dart';

/// Parser para horarios impresos como retícula: una columna por día de la
/// semana y, a la izquierda, una columna de horas.
///
/// Trabaja con coordenadas, no con orden de lectura. El extractor de PDF
/// devuelve las celdas entremezcladas —la línea de las 9 am de miércoles puede
/// llegar antes que la de las 7 am de martes—, así que lo único fiable para
/// saber a qué día pertenece una celda es su posición X.
///
/// El formato de referencia es el de «Servicios académicos» (PACR42), donde
/// cada celda de la retícula viene así:
///
/// ```
///   Cod. 96112             ← código de la asignatura: la llave de todo
///   Prog. 31013
///   FISICA                 ← el nombre viene partido en varias líneas
///   MECANICA
///   Grupo. SIS-A1          ← cierra el nombre
///   SubGrupo.
///   03/08/26 - 10/08/26    ← bloques administrativos: se descartan
///   Aula. 606F - Av        ← salón y sede, también partidos
///   Univ - Santo
///   Domingo de
///   Guzmán
///   …                      ← los bloques se repiten con el mismo aula
///   9:00 am-11:00 am       ← la hora cierra la celda
/// ```
///
/// Y una segunda sección, «Detalle de las Materias», con el nombre canónico,
/// el docente y los créditos de cada código.
///
/// Los bloques de fechas de cada celda son cortes administrativos del
/// semestre, no las semanas en que hay clase: la clase es semanal. Sirven para
/// separar el nombre del aula, y después se descartan.
///
/// Es Dart puro y determinista: no usa red ni servicios de IA. Si el PDF no
/// tiene encabezado de días, [parse] devuelve una lista vacía y el importador
/// sigue con [ScheduleParser], el parser heurístico.
abstract final class ColumnScheduleParser {
  /// Convierte las líneas con posición de un PDF en materias con sus sesiones.
  ///
  /// Devuelve vacío —sin lanzar— cuando el PDF no tiene forma de retícula.
  static List<ParsedClass> parse(List<PositionedLine> positioned) {
    if (positioned.isEmpty) return const [];

    final lines = positioned.where((l) => l.text.trim().isNotEmpty).toList()
      ..sort(_readingOrder);

    final detailAt = lines.indexWhere(_isDetailHeading);
    final scheduleLines = detailAt < 0 ? lines : lines.sublist(0, detailAt);
    final detailLines = detailAt < 0 ? const <PositionedLine>[] : lines.sublist(detailAt);

    final grid = _DayGrid.from(scheduleLines);
    if (grid == null) return const [];

    final cells = _readCells(scheduleLines, grid);
    if (cells.isEmpty) return const [];

    final classes = _group(cells);
    _enrich(classes, _readDetail(detailLines));
    return classes;
  }

  static int _readingOrder(PositionedLine a, PositionedLine b) {
    if (a.pageIndex != b.pageIndex) return a.pageIndex.compareTo(b.pageIndex);
    final dy = a.top.compareTo(b.top);
    return dy != 0 ? dy : a.left.compareTo(b.left);
  }

  static bool _isDetailHeading(PositionedLine l) {
    final t = l.text.toLowerCase();
    return t.startsWith('detalle de') && t.contains('materia');
  }

  // ───────────────────────────────────────────────────────────────────────
  // Paso 2 — Leer las celdas de la retícula
  // ───────────────────────────────────────────────────────────────────────

  static final RegExp _reCode = RegExp(r'^cod\.\s*(\S+)$', caseSensitive: false);
  static final RegExp _reProgram = RegExp(r'^prog\.\s*\S*$', caseSensitive: false);
  static final RegExp _reGroup = RegExp(r'^grupo\.\s*(.*)$', caseSensitive: false);
  static final RegExp _reSubGroup = RegExp(r'^subgrupo\.\s*(.*)$', caseSensitive: false);
  static final RegExp _reRoom =
      RegExp(r'^(?:aula|sal[oó]n)\.?\s*(.*)$', caseSensitive: false);

  /// `03/08/26 - 10/08/26`: el rango de fechas de un bloque del semestre.
  /// Se comprueba antes que la hora porque `26 - 06` también parece un rango.
  static final RegExp _reDateRange = RegExp(
    r'^\d{1,2}/\d{1,2}/\d{2,4}\s*[-–—]\s*\d{1,2}/\d{1,2}/\d{2,4}$',
  );

  /// `9:00 am-11:00 am`, `11:00 am-1:00 pm`, `7-9`. El marcador am/pm es
  /// opcional: hay universidades que lo omiten y usan 24 horas.
  static final RegExp _reTimeRange = RegExp(
    r'(?<!\d)(\d{1,2})(?::(\d{2}))?\s*([ap])\.?\s?m\.?\s*[-–—]\s*'
    r'(\d{1,2})(?::(\d{2}))?\s*([ap])?\.?\s?m?\.?(?!\d)',
    caseSensitive: false,
  );

  /// Lo mismo sin exigir am/pm en ningún lado, para los PDF que usan 24 horas.
  static final RegExp _reTimeRangePlain = RegExp(
    r'^(\d{1,2})(?::(\d{2}))?\s*[-–—]\s*(\d{1,2})(?::(\d{2}))?$',
  );

  static List<_Cell> _readCells(List<PositionedLine> lines, _DayGrid grid) {
    final builders = <int, _CellBuilder>{};
    final cells = <_Cell>[];

    for (final line in lines) {
      // Todo lo que está por encima del encabezado son títulos y metadatos.
      if (line.pageIndex == grid.headerPage && line.top < grid.headerTop + 4) {
        continue;
      }
      final column = grid.columnFor(line.left);
      if (column == null || column.day == null) continue; // fuera, o columna de horas

      final day = column.day!;
      final builder = builders.putIfAbsent(day, _CellBuilder.new);
      final text = line.text;

      if (_reDateRange.hasMatch(text)) {
        builder.closeRoom();
        continue;
      }

      final range = _parseTimeRange(text);
      if (range != null) {
        final cell = builder.build(day, range.$1, range.$2);
        if (cell != null) cells.add(cell);
        builder.reset();
        continue;
      }

      final code = _reCode.firstMatch(text);
      if (code != null) {
        builder.reset();
        builder.codigo = code.group(1);
        continue;
      }

      if (_reProgram.hasMatch(text)) continue;

      final subGroup = _reSubGroup.firstMatch(text);
      if (subGroup != null) {
        builder.closeName();
        continue;
      }

      final group = _reGroup.firstMatch(text);
      if (group != null) {
        builder.grupo = group.group(1)?.trim();
        builder.closeName();
        continue;
      }

      final room = _reRoom.firstMatch(text);
      if (room != null) {
        builder.openRoom(room.group(1) ?? '');
        continue;
      }

      builder.addText(text);
    }

    return cells;
  }

  static (MinutesOfDay, MinutesOfDay)? _parseTimeRange(String text) {
    final m = _reTimeRange.firstMatch(text);
    if (m != null) {
      return _buildRange(
        h1: int.parse(m.group(1)!),
        min1: int.tryParse(m.group(2) ?? '') ?? 0,
        marker1: m.group(3),
        h2: int.parse(m.group(4)!),
        min2: int.tryParse(m.group(5) ?? '') ?? 0,
        marker2: m.group(6),
      );
    }
    final p = _reTimeRangePlain.firstMatch(text);
    if (p == null) return null;
    return _buildRange(
      h1: int.parse(p.group(1)!),
      min1: int.tryParse(p.group(2) ?? '') ?? 0,
      marker1: null,
      h2: int.parse(p.group(3)!),
      min2: int.tryParse(p.group(4) ?? '') ?? 0,
      marker2: null,
    );
  }

  /// Pasa un rango a 24 horas. Sin marcador am/pm se asume que una clase no
  /// termina antes de empezar: `11-1` es de 11:00 a 13:00.
  static (MinutesOfDay, MinutesOfDay)? _buildRange({
    required int h1,
    required int min1,
    required String? marker1,
    required int h2,
    required int min2,
    required String? marker2,
  }) {
    final pm1 = marker1?.toLowerCase().startsWith('p');
    final pm2 = marker2?.toLowerCase().startsWith('p');

    if (pm1 == true && h1 < 12) h1 += 12;
    if (pm1 == false && h1 == 12) h1 = 0;
    if (pm2 == true && h2 < 12) h2 += 12;
    if (pm2 == false && h2 == 12) h2 = 0;

    // La hora de fin sin marcador hereda el del inicio cuando tiene sentido.
    if (pm2 == null && pm1 == true && h2 < 12) h2 += 12;
    if (pm2 == null && pm1 == null && h2 < h1 && h2 <= 8) h2 += 12;

    if (h1 > 23 || h2 > 23 || min1 > 59 || min2 > 59) return null;
    final inicio = MinutesOfDay.of(h1, min1);
    final fin = MinutesOfDay.of(h2, min2);
    if (fin.raw <= inicio.raw) return null;
    return (inicio, fin);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Paso 3 — Agrupar celdas en materias
  // ───────────────────────────────────────────────────────────────────────

  static List<ParsedClass> _group(List<_Cell> cells) {
    final order = <String>[];
    final grouped = <String, List<_Cell>>{};

    for (final cell in cells) {
      final key = cell.codigo ?? _normalize(cell.nombre);
      if (key.isEmpty) continue;
      if (!grouped.containsKey(key)) {
        grouped[key] = <_Cell>[];
        order.add(key);
      }
      grouped[key]!.add(cell);
    }

    return [
      for (final key in order) _classFrom(grouped[key]!),
    ];
  }

  static ParsedClass _classFrom(List<_Cell> group) {
    final nombre = group
        .map((c) => c.nombre)
        .firstWhere((n) => n.isNotEmpty, orElse: () => '');

    final sessions = <ParsedSession>[];
    for (final cell in group) {
      final s = ParsedSession(
        diaSemana: cell.day,
        inicio: cell.inicio,
        fin: cell.fin,
        salon: cell.salon,
      );
      if (!sessions.contains(s)) sessions.add(s);
    }
    sessions.sort((a, b) => a.diaSemana != b.diaSemana
        ? a.diaSemana.compareTo(b.diaSemana)
        : a.inicio.raw.compareTo(b.inicio.raw));

    final doubts = <ParseDoubt>{};
    if (nombre.isEmpty) doubts.add(ParseDoubt.missingName);
    if (sessions.isEmpty) doubts.add(ParseDoubt.missingDays);

    return ParsedClass(
      nombre: nombre,
      codigo: group.first.codigo,
      salon: _mostCommonRoom(sessions),
      sessions: sessions,
      doubts: doubts,
    );
  }

  /// El salón que la materia usa más veces. Es el que la pantalla de revisión
  /// muestra y el que se guarda si el modelo solo admite uno.
  static String? _mostCommonRoom(List<ParsedSession> sessions) {
    final tally = <String, int>{};
    for (final s in sessions) {
      final room = s.salon;
      if (room != null && room.isNotEmpty) tally[room] = (tally[room] ?? 0) + 1;
    }
    if (tally.isEmpty) return null;
    var best = tally.keys.first;
    for (final entry in tally.entries) {
      if (entry.value > tally[best]!) best = entry.key;
    }
    return best;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Paso 4 — Sección «Detalle de las Materias»
  // ───────────────────────────────────────────────────────────────────────

  /// Fila completa en una sola línea:
  /// `96112 FISICA MECANICA SIS-A1  03/08/26 25/11/26 3 96 3 31013 20262 DOCENTE`
  static final RegExp _reDetailFull = RegExp(
    r'^(\d{4,6})\s+(.+?)\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+(\d{1,2}/\d{1,2}/\d{2,4})'
    r'\s+(\d+)\s+(\d+)\s+(\d+)\b(.*)$',
  );

  /// La misma fila cuando el código va en su propia línea y aquí solo queda
  /// `CULDIS  04/08/26 25/11/26 4 64 2 31013 20262`.
  static final RegExp _reDetailData = RegExp(
    r'^(\S+)\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+(\d{1,2}/\d{1,2}/\d{2,4})'
    r'\s+(\d+)\s+(\d+)\s+(\d+)\b(.*)$',
  );

  static final RegExp _reBareCode = RegExp(r'^(\d{4,6})$');
  static final RegExp _reLeadingCode = RegExp(r'^(\d{4,6})\b');

  /// Alto de una fila del detalle. El nombre y el docente se parten en dos
  /// líneas, una encima y otra debajo de la del código, a menos de 7 pt.
  static const double _detailRowBand = 8;

  static Map<String, _DetailRow> _readDetail(List<PositionedLine> lines) {
    if (lines.isEmpty) return const {};

    // La columna de sede es la más a la derecha de toda la tabla; se descarta.
    var sedeX = double.infinity;
    for (final l in lines) {
      if (l.left > 100 && (sedeX == double.infinity || l.left > sedeX)) sedeX = l.left;
    }

    final rows = <String, _DetailRow>{};

    for (final anchor in lines) {
      if (anchor.left > 140) continue; // la columna del código va a la izquierda
      final code = _reLeadingCode.firstMatch(anchor.text)?.group(1);
      if (code == null) continue;

      final window = lines
          .where((l) =>
              l.pageIndex == anchor.pageIndex &&
              (l.top - anchor.top).abs() <= _detailRowBand)
          .toList()
        ..sort((a, b) => a.top.compareTo(b.top));

      rows[code] = _detailRow(code, anchor, window, sedeX);
    }

    return rows;
  }

  static _DetailRow _detailRow(
    String code,
    PositionedLine anchor,
    List<PositionedLine> window,
    double sedeX,
  ) {
    final String nombre;
    int? creditos;
    var docente = <String>[];
    double dataX;

    final full = _reDetailFull.firstMatch(anchor.text);
    if (full != null) {
      // Fila en una línea: el nombre y el grupo van pegados; el grupo es el
      // último token antes de las fechas.
      nombre = _dropTrailingGroup(full.group(2)!);
      creditos = int.tryParse(full.group(7)!);
      // Lo que sigue son los dos códigos (programa y pensum) y el docente.
      final tail = full.group(8)!.replaceFirst(RegExp(r'^\s*\d+\s+\d+\s*'), '').trim();
      if (tail.isNotEmpty) docente.add(tail);
      dataX = anchor.left;
    } else {
      // Fila repartida: el nombre está en las líneas vecinas de su columna.
      final data = window
          .map((l) => (l, _reDetailData.firstMatch(l.text)))
          .where((p) => p.$2 != null && p.$1.left > anchor.left)
          .firstOrNull;
      creditos = data == null ? null : int.tryParse(data.$2!.group(6)!);
      dataX = data?.$1.left ?? double.infinity;

      final parts = <String>[];
      for (final l in window) {
        if (identical(l, anchor)) continue;
        if (l.left <= anchor.left || l.left >= dataX) continue;
        parts.add(l.text);
      }
      // Cuando el código está solo en su línea, el nombre empieza en la de
      // arriba; si trae cola (`15653 IV …`), esa cola es el final del nombre.
      if (!_reBareCode.hasMatch(anchor.text)) {
        final rest = anchor.text.replaceFirst(_reLeadingCode, '').trim();
        if (rest.isNotEmpty) parts.add(_dropTrailingGroup(rest));
      }
      nombre = _collapse(parts.join(' '));
    }

    for (final l in window) {
      if (identical(l, anchor)) continue;
      if (l.left > dataX && l.left < sedeX - 5) docente.add(l.text);
    }

    final profesor = _collapse(docente.join(' '));
    return _DetailRow(
      codigo: code,
      nombre: nombre.isEmpty ? null : nombre,
      profesor: profesor.isEmpty ? null : profesor,
      creditos: creditos,
    );
  }

  /// `ALGEBRA LINEAL IND-B` → `ALGEBRA LINEAL`. En la fila de una sola línea
  /// el grupo queda pegado al nombre y es siempre el último token.
  static String _dropTrailingGroup(String raw) {
    final parts = _collapse(raw).split(' ');
    if (parts.length < 2) return _collapse(raw);
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  // ───────────────────────────────────────────────────────────────────────
  // Paso 5 — Cruzar retícula y detalle
  // ───────────────────────────────────────────────────────────────────────

  /// El nombre se toma de la retícula, que lo delimita sin ambigüedad entre
  /// `Prog.` y `Grupo.`. Del detalle salen el docente y los créditos, que la
  /// retícula no trae.
  static void _enrich(List<ParsedClass> classes, Map<String, _DetailRow> detail) {
    if (detail.isEmpty) return;

    for (var i = 0; i < classes.length; i++) {
      final c = classes[i];
      final row = c.codigo != null
          ? detail[c.codigo]
          : detail.values
              .where((r) => r.nombre != null && _normalize(r.nombre!) == _normalize(c.nombre))
              .firstOrNull;
      if (row == null) continue;

      final doubts = {...c.doubts};
      final nombre = c.nombre.isNotEmpty ? c.nombre : (row.nombre ?? '');
      if (nombre.isNotEmpty) doubts.remove(ParseDoubt.missingName);

      classes[i] = c.copyWith(
        nombre: nombre,
        profesor: row.profesor,
        creditos: row.creditos,
        doubts: doubts,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Utilidades
  // ───────────────────────────────────────────────────────────────────────

  static String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _normalize(String s) => _collapse(s).toLowerCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// La retícula de días
// ─────────────────────────────────────────────────────────────────────────────

/// Dónde empieza cada columna del horario.
///
/// El encabezado llega de dos formas según el PDF: una línea por día, o todos
/// los días en una sola línea (`HORAS LUNES MARTES … DOMINGO`). En el segundo
/// caso la X de cada día se estima repartiendo el ancho de la línea entre sus
/// caracteres, y después se afina con la posición real de las celdas.
class _DayGrid {
  _DayGrid._(this._anchors, this.headerPage, this.headerTop);

  final List<_Anchor> _anchors;
  final int headerPage;
  final double headerTop;

  /// `horas` entra como columna para que las etiquetas de la izquierda
  /// (`7:00 am`) caigan en ella y no se cuelen como clases del lunes.
  static const Map<String, int?> _headings = {
    'horas': null,
    'hora': null,
    'lunes': 1,
    'martes': 2,
    'miercoles': 3,
    'miércoles': 3,
    'jueves': 4,
    'viernes': 5,
    'sabado': 6,
    'sábado': 6,
    'domingo': 7,
  };

  static _DayGrid? from(List<PositionedLine> lines) {
    for (final line in lines) {
      final tokens = _tokensIn(line.text);
      final days = tokens.where((t) => t.day != null).length;

      if (days >= 2) {
        // Todos los días en una línea: se reparte el ancho entre caracteres.
        final perChar = (line.right - line.left) / line.text.length;
        final anchors = [
          for (final t in tokens) _Anchor(t.day, line.left + t.index * perChar),
        ];
        final grid = _DayGrid._(anchors, line.pageIndex, line.top);
        grid._refineWith(lines);
        return grid;
      }

      if (days == 1) {
        // Un día por línea: la X de cada columna es la de su propia línea.
        final row = lines.where((l) =>
            l.pageIndex == line.pageIndex && (l.top - line.top).abs() < 6);
        final anchors = <_Anchor>[];
        for (final l in row) {
          final t = _tokensIn(l.text);
          if (t.length == 1) anchors.add(_Anchor(t.single.day, l.left));
        }
        if (anchors.where((a) => a.day != null).length >= 2) {
          return _DayGrid._(anchors, line.pageIndex, line.top);
        }
      }
    }
    return null;
  }

  static List<_HeaderToken> _tokensIn(String text) {
    final lower = text.toLowerCase();
    final found = <_HeaderToken>[];
    final seen = <Object>{};
    for (final entry in _headings.entries) {
      final index = lower.indexOf(entry.key);
      if (index < 0) continue;
      // Palabra completa: «domingo» dentro de «Domingo de Guzmán» no cuenta
      // como encabezado, pero sí como texto de una celda.
      final after = index + entry.key.length;
      if (index > 0 && _isWordChar(lower[index - 1])) continue;
      if (after < lower.length && _isWordChar(lower[after])) continue;
      final key = entry.value ?? 'horas';
      if (!seen.add(key)) continue;
      found.add(_HeaderToken(entry.value, index));
    }
    found.sort((a, b) => a.index.compareTo(b.index));
    return found;
  }

  static bool _isWordChar(String c) => RegExp(r'[a-z0-9áéíóúñ]').hasMatch(c);

  /// El reparto por caracteres da una X aproximada. Las celdas reales están
  /// alineadas a la izquierda de su columna, así que si todas las que caen en
  /// una columna comparten X, esa X es mejor que la estimada.
  void _refineWith(List<PositionedLine> lines) {
    final observed = <int, List<double>>{};
    for (final l in lines) {
      if (l.pageIndex == headerPage && l.top < headerTop + 4) continue;
      final anchor = columnFor(l.left);
      if (anchor == null) continue;
      (observed[_anchors.indexOf(anchor)] ??= <double>[]).add(l.left);
    }
    for (final entry in observed.entries) {
      final xs = entry.value..sort();
      final median = xs[xs.length ~/ 2];
      // Solo se afina si la columna es consistente: celdas alineadas.
      final spread = xs.last - xs.first;
      if (spread <= 6 || xs.length >= 4) {
        _anchors[entry.key] = _Anchor(_anchors[entry.key].day, median);
      }
    }
  }

  /// Tolerancia: la separación media entre columnas. Más lejos que eso y la
  /// línea no pertenece a la tabla.
  double get _tolerance {
    if (_anchors.length < 2) return 40;
    final sorted = [..._anchors]..sort((a, b) => a.x.compareTo(b.x));
    var total = 0.0;
    for (var i = 1; i < sorted.length; i++) {
      total += sorted[i].x - sorted[i - 1].x;
    }
    return total / (sorted.length - 1);
  }

  /// La columna a la que pertenece una X, o `null` si cae fuera de la tabla.
  _Anchor? columnFor(double x) {
    _Anchor? best;
    var bestDistance = double.infinity;
    for (final anchor in _anchors) {
      final d = (x - anchor.x).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = anchor;
      }
    }
    return bestDistance <= _tolerance ? best : null;
  }
}

class _Anchor {
  const _Anchor(this.day, this.x);

  /// ISO 8601: 1 = lunes … 7 = domingo. `null` es la columna de horas.
  final int? day;
  final double x;
}

class _HeaderToken {
  const _HeaderToken(this.day, this.index);
  final int? day;
  final int index;
}

// ─────────────────────────────────────────────────────────────────────────────
// Celdas
// ─────────────────────────────────────────────────────────────────────────────

/// Va juntando las líneas de una celda hasta que llega la hora, que la cierra.
class _CellBuilder {
  String? codigo;
  String? grupo;

  final List<String> _name = [];
  final List<String> _room = [];
  bool _nameClosed = false;
  bool _inRoom = false;

  void addText(String text) {
    if (_inRoom) {
      _room.add(text);
      return;
    }
    // Tras `Grupo.` lo que queda son fechas y el nombre de la sede: ruido.
    if (_nameClosed) return;
    _name.add(text);
  }

  void closeName() {
    _nameClosed = true;
    _inRoom = false;
  }

  /// El aula se repite en cada bloque de fechas; nos quedamos con la primera.
  void openRoom(String first) {
    _nameClosed = true;
    if (_room.isNotEmpty) {
      _inRoom = false;
      return;
    }
    _inRoom = true;
    if (first.trim().isNotEmpty) _room.add(first.trim());
  }

  void closeRoom() => _inRoom = false;

  void reset() {
    codigo = null;
    grupo = null;
    _name.clear();
    _room.clear();
    _nameClosed = false;
    _inRoom = false;
  }

  _Cell? build(int day, MinutesOfDay inicio, MinutesOfDay fin) {
    final nombre = _clean(_name.join(' '));
    if (nombre.isEmpty && codigo == null) return null;
    return _Cell(
      day: day,
      inicio: inicio,
      fin: fin,
      codigo: codigo,
      nombre: nombre,
      salon: _roomName(),
    );
  }

  /// `606F - Av Univ - Santo Domingo de Guzmán` → `606F`.
  ///
  /// En el PDF el aula y la sede van en el mismo campo. La sede se reconoce
  /// por cómo empieza, y todo lo que va de ahí en adelante sobra: al
  /// estudiante le sirve «Sala de Sistemas 2E», no el nombre del campus.
  static final RegExp _campus = RegExp(
    r'\s*[-–]?\s*(?:av\.?\s+univ\b|univ\s*[-–]|santo\s+domingo\b|sede\b|campus\b).*$',
    caseSensitive: false,
  );

  String? _roomName() {
    final joined = _clean(_room.join(' '));
    if (joined.isEmpty) return null;
    final withoutCampus = joined.replaceAll(_campus, '').trim();
    final trimmed = withoutCampus.replaceAll(RegExp(r'[\s,;:.\-–]+$'), '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _Cell {
  const _Cell({
    required this.day,
    required this.inicio,
    required this.fin,
    required this.nombre,
    this.codigo,
    this.salon,
  });

  final int day;
  final MinutesOfDay inicio;
  final MinutesOfDay fin;
  final String nombre;
  final String? codigo;
  final String? salon;
}

class _DetailRow {
  const _DetailRow({required this.codigo, this.nombre, this.profesor, this.creditos});

  final String codigo;
  final String? nombre;
  final String? profesor;
  final int? creditos;
}
