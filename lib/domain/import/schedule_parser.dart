import '../../core/time/minutes_of_day.dart';

/// Qué tan seguro está el parser de una clase detectada.
///
/// `low` es lo que la pantalla de confirmación marca con «Revisa esto». No es
/// un porcentaje: es una lista de motivos, para que la persona sepa qué mirar.
enum ParseDoubt {
  /// No se encontró nombre en la fila ni en la línea anterior.
  missingName,

  /// Hay hora pero ningún día reconocible.
  missingDays,

  /// La hora de fin no va después de la de inicio.
  badRange,

  /// El nombre se tomó de una línea anterior, no de la misma fila.
  nameFromPreviousLine,
}

class ParsedSession {
  const ParsedSession({
    required this.diaSemana,
    required this.inicio,
    required this.fin,
    this.salon,
  });

  /// ISO 8601: 1 = lunes … 7 = domingo.
  final int diaSemana;
  final MinutesOfDay inicio;
  final MinutesOfDay fin;

  /// La misma materia se dicta en salones distintos según el día: en el PDF de
  /// horario el aula va en la celda, no en la materia. `null` si no se supo.
  final String? salon;

  ParsedSession copyWith({int? diaSemana, MinutesOfDay? inicio, MinutesOfDay? fin, String? salon}) =>
      ParsedSession(
        diaSemana: diaSemana ?? this.diaSemana,
        inicio: inicio ?? this.inicio,
        fin: fin ?? this.fin,
        salon: salon ?? this.salon,
      );

  @override
  bool operator ==(Object other) =>
      other is ParsedSession &&
      other.diaSemana == diaSemana &&
      other.inicio == inicio &&
      other.fin == fin &&
      other.salon == salon;

  @override
  int get hashCode => Object.hash(diaSemana, inicio, fin, salon);

  @override
  String toString() =>
      'ParsedSession($diaSemana ${inicio.hhmm}\u2013${fin.hhmm}${salon == null ? '' : ' @$salon'})';
}

class ParsedClass {
  const ParsedClass({
    required this.nombre,
    required this.sessions,
    this.profesor,
    this.salon,
    this.codigo,
    this.creditos,
    this.doubts = const {},
  });

  final String nombre;
  final String? profesor;

  /// Salón representativo de la materia: el de la primera sesión que lo trae.
  /// El salón exacto de cada clase vive en `ParsedSession.salon`.
  final String? salon;

  /// Código de la asignatura en el sistema académico (`Cod. 41151`). Es la
  /// llave con la que se cruza la retícula con la sección de detalle.
  final String? codigo;

  final int? creditos;
  final List<ParsedSession> sessions;
  final Set<ParseDoubt> doubts;

  bool get isLowConfidence => doubts.isNotEmpty;

  ParsedClass copyWith({
    String? nombre,
    String? profesor,
    String? salon,
    String? codigo,
    int? creditos,
    List<ParsedSession>? sessions,
    Set<ParseDoubt>? doubts,
    bool clearProfesor = false,
    bool clearSalon = false,
  }) =>
      ParsedClass(
        nombre: nombre ?? this.nombre,
        profesor: clearProfesor ? null : (profesor ?? this.profesor),
        salon: clearSalon ? null : (salon ?? this.salon),
        codigo: codigo ?? this.codigo,
        creditos: creditos ?? this.creditos,
        sessions: sessions ?? this.sessions,
        doubts: doubts ?? this.doubts,
      );
}

/// Parser heurístico de horarios universitarios a partir de líneas de texto.
///
/// Dart puro, sin red: es lo que corre siempre, con o sin clave de API. Cubre
/// los tres layouts que se ven en los PDF de «Servicios académicos»:
///
/// 1. Una fila por clase: `Bases de datos  Martes 10:00-12:00  Salón 604`.
/// 2. Nombre en una línea y horario en la siguiente.
/// 3. Encabezado de día (`LUNES`) y debajo las clases de ese día.
///
/// No intenta ser perfecto: intenta no inventar. Lo que no encuentra lo deja
/// vacío y lo marca con una duda para que la persona lo mire.
abstract final class ScheduleParser {
  static final RegExp _timeRange = RegExp(
    r'(?<!\d)(\d{1,2})(?:[:.h](\d{2}))?\s*([ap]\.?\s?m\.?)?\s*(?:-|–|—|a|hasta|to)\s*(\d{1,2})(?:[:.h](\d{2}))?(?!\d)\s*([ap]\.?\s?m\.?)?',
    caseSensitive: false,
  );

  /// Día → ISO. Se aceptan nombres completos y abreviaturas de dos y tres
  /// letras, con y sin tilde. Las de una letra no: `M` es martes o miércoles.
  static const Map<String, int> _dayTokens = {
    'lunes': 1, 'lun': 1, 'lu': 1,
    'martes': 2, 'mar': 2, 'ma': 2,
    'miercoles': 3, 'miércoles': 3, 'mie': 3, 'mié': 3, 'mi': 3,
    'jueves': 4, 'jue': 4, 'ju': 4,
    'viernes': 5, 'vie': 5, 'vi': 5,
    'sabado': 6, 'sábado': 6, 'sab': 6, 'sáb': 6, 'sa': 6,
    'domingo': 7, 'dom': 7, 'do': 7,
  };

  static final RegExp _dayWord = RegExp(
    r'\b(lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo|lun|mar|mi[eé]|jue|vie|s[aá]b|dom|lu|ma|mi|ju|vi|sa|do)\b\.?',
    caseSensitive: false,
  );

  static final RegExp _roomLabeled = RegExp(
    r'\b(?:sal[oó]n|aula|sala|lab(?:oratorio)?|bloque|bl\.?|edificio|ed\.?)\s*[:.]?\s*([A-Za-z]?\d[\w\-]*(?:\s*[-–]\s*\w+)?)',
    caseSensitive: false,
  );

  /// `12-201`, `604`, `B-305`: un código suelto al final de la fila.
  static final RegExp _roomBare = RegExp(r'(?<!\d)([A-Z]?\d{1,2}-\d{2,3}[A-Z]?|\d{3}[A-Z]?)(?!\d)');

  static final RegExp _professorLabeled = RegExp(
    r'\b(?:[Pp]rof\.?|[Pp]rofesora?|[Dd]ocente|PROF\.?|PROFESORA?|DOCENTE)\s*[:.]?\s*([A-ZÁÉÍÓÚÑ][\wáéíóúñÁÉÍÓÚÑ.]*(?:\s+[A-ZÁÉÍÓÚÑ][\wáéíóúñÁÉÍÓÚÑ.]*){0,3})',
  );

  /// Palabras que delatan un encabezado de tabla o de página, no una materia.
  static final RegExp _headerWords = RegExp(
    r'\b(horario|semestre|per[ií]odo|c[oó]digo|cr[eé]ditos?|estudiante|universidad|facultad|programa|materia|asignatura|d[ií]a|hora|sal[oó]n|aula|profesor|docente|grupo|p[aá]gina|total)\b',
    caseSensitive: false,
  );

  static final RegExp _separators = RegExp(r'[|\t]+|\s{2,}');
  static final RegExp _punctEdges = RegExp(r'^[\s\-–—:;,.·|]+|[\s\-–—:;,.·|]+$');

  static List<ParsedClass> parse(Iterable<String> rawLines) {
    final lines = rawLines.map((l) => l.replaceAll(_separators, '  ').trim()).where((l) => l.isNotEmpty).toList();

    final classes = <ParsedClass>[];
    String? pendingName; // última línea sin hora que parece un nombre
    int? headerDay; // encabezado de día vigente (layout 3)
    int lastClassIndex = -1; // para pegarle el profesor de la línea siguiente

    for (final line in lines) {
      final times = _timeRange.allMatches(line).toList();

      if (times.isEmpty) {
        final day = _soleDay(line);
        if (day != null) {
          headerDay = day;
          pendingName = null;
          continue;
        }
        final prof = _professorLabeled.firstMatch(line);
        if (prof != null && lastClassIndex >= 0 && classes[lastClassIndex].profesor == null) {
          classes[lastClassIndex] = classes[lastClassIndex].copyWith(profesor: prof.group(1)!.trim());
          continue;
        }
        if (_looksLikeName(line)) pendingName = line;
        continue;
      }

      // Hay hora: esto es una fila de clase.
      var rest = line;
      final sessions = <ParsedSession>[];
      final doubts = <ParseDoubt>{};

      var days = _daysIn(line);
      rest = rest.replaceAll(_dayWord, ' ');
      if (days.isEmpty && headerDay != null) days = [headerDay];
      if (days.isEmpty) doubts.add(ParseDoubt.missingDays);

      for (final m in times) {
        final range = _range(m);
        rest = rest.replaceFirst(m.group(0)!, ' ');
        if (range == null) continue;
        if (range.$2 <= range.$1) doubts.add(ParseDoubt.badRange);
        for (final d in days.isEmpty ? [0] : days) {
          sessions.add(ParsedSession(diaSemana: d, inicio: range.$1, fin: range.$2));
        }
      }

      String? salon;
      final labeled = _roomLabeled.firstMatch(rest);
      if (labeled != null) {
        salon = labeled.group(1)!.replaceAll(RegExp(r'\s+'), '').trim();
        rest = rest.replaceFirst(labeled.group(0)!, ' ');
      } else {
        final bare = _roomBare.firstMatch(rest);
        if (bare != null) {
          salon = bare.group(1);
          rest = rest.replaceFirst(bare.group(0)!, ' ');
        }
      }

      String? profesor;
      final prof = _professorLabeled.firstMatch(rest);
      if (prof != null) {
        profesor = prof.group(1)!.trim();
        rest = rest.replaceFirst(prof.group(0)!, ' ');
      }

      var nombre = _clean(rest);
      if (!_looksLikeName(nombre)) {
        if (pendingName != null) {
          nombre = pendingName;
          doubts.add(ParseDoubt.nameFromPreviousLine);
        } else {
          nombre = '';
          doubts.add(ParseDoubt.missingName);
        }
      }

      final parsed = ParsedClass(
        nombre: nombre,
        profesor: profesor,
        salon: salon,
        sessions: sessions,
        doubts: doubts,
      );

      // Misma materia en otra fila: se le suman las sesiones, no se duplica.
      final existing = nombre.isEmpty
          ? -1
          : classes.indexWhere((c) => c.nombre.toLowerCase() == nombre.toLowerCase());
      if (existing >= 0) {
        classes[existing] = _merge(classes[existing], parsed);
        lastClassIndex = existing;
      } else {
        classes.add(parsed);
        lastClassIndex = classes.length - 1;
      }
      // Un nombre de la línea anterior sirve para una fila, no para todas.
      if (doubts.contains(ParseDoubt.nameFromPreviousLine)) pendingName = null;
    }

    return classes;
  }

  static ParsedClass _merge(ParsedClass a, ParsedClass b) {
    final sessions = [...a.sessions];
    for (final s in b.sessions) {
      if (!sessions.contains(s)) sessions.add(s);
    }
    // Si la fila de arriba ya tenía nombre propio, que otra lo haya heredado
    // no es una duda nueva: la materia existe.
    final doubts = {...a.doubts, ...b.doubts}..remove(ParseDoubt.nameFromPreviousLine);
    if (a.doubts.contains(ParseDoubt.nameFromPreviousLine) && b.doubts.contains(ParseDoubt.nameFromPreviousLine)) {
      doubts.add(ParseDoubt.nameFromPreviousLine);
    }
    return ParsedClass(
      nombre: a.nombre,
      profesor: a.profesor ?? b.profesor,
      salon: a.salon ?? b.salon,
      sessions: sessions,
      doubts: doubts,
    );
  }

  /// Días mencionados en la línea, en orden y sin repetir.
  static List<int> _daysIn(String line) {
    final out = <int>[];
    for (final m in _dayWord.allMatches(line)) {
      final d = _dayTokens[m.group(1)!.toLowerCase()];
      if (d != null && !out.contains(d)) out.add(d);
    }
    return out;
  }

  /// Una línea que es solo un día («LUNES», «Martes:») es un encabezado.
  static int? _soleDay(String line) {
    final cleaned = _clean(line).toLowerCase();
    return _dayTokens[cleaned];
  }

  /// Convierte un match de rango horario en dos horas del día. Null si los
  /// números no son horas.
  static (MinutesOfDay, MinutesOfDay)? _range(RegExpMatch m) {
    var h1 = int.parse(m.group(1)!);
    final m1 = int.tryParse(m.group(2) ?? '') ?? 0;
    var h2 = int.parse(m.group(4)!);
    final m2 = int.tryParse(m.group(5) ?? '') ?? 0;
    final pm1 = _isPm(m.group(3));
    final pm2 = _isPm(m.group(6));

    if (pm1 == true && h1 < 12) h1 += 12;
    if (pm2 == true && h2 < 12) h2 += 12;
    // «1-3 pm»: el pm de la segunda hora aplica también a la primera si así
    // el rango sigue teniendo sentido («11-1 pm» se queda en 11).
    if (pm1 == null && pm2 == true && h1 < 12 && h1 + 12 <= h2) h1 += 12;
    // «11-1» sin marcador: si la segunda es menor, cruzó el mediodía.
    if (pm1 == null && pm2 == null && h2 < h1 && h2 <= 8) h2 += 12;

    if (h1 > 23 || h2 > 23 || m1 > 59 || m2 > 59) return null;
    return (MinutesOfDay.of(h1, m1), MinutesOfDay.of(h2, m2));
  }

  static bool? _isPm(String? marker) {
    if (marker == null) return null;
    return marker.toLowerCase().startsWith('p');
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').replaceAll(_punctEdges, '').trim();

  /// Tiene al menos tres letras seguidas, no es un encabezado y no es solo
  /// números o códigos.
  static bool _looksLikeName(String s) {
    final c = _clean(s);
    if (c.length < 3) return false;
    if (!RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]{3,}').hasMatch(c)) return false;
    if (_headerWords.hasMatch(c) && c.split(' ').length <= 4) return false;
    return true;
  }
}
