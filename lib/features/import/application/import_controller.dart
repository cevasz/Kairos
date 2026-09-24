import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/import/schedule_parser.dart';
import '../../../theme/tokens.g.dart';
import '../data/claude_schedule_parser.dart';
import '../data/column_schedule_parser.dart';
import '../data/ics_schedule_parser.dart';
import '../data/pdf_text.dart';
import '../data/time_grid_parser.dart';

/// Por qué falló la importación. Cada motivo tiene su texto en A5.
enum ImportFailure {
  /// Hay páginas pero ninguna trae texto: está escaneado como imagen.
  noText,

  /// No se pudo abrir: dañado, cifrado o no es un PDF.
  unreadable,

  /// Sí hay texto, pero ninguna línea parece una clase.
  nothingFound,

  /// Se leyó bien, pero guardar falló. No queda nada a medias: el guardado
  /// va en una transacción.
  saveFailed,
}

/// La máquina de estados del importador: A2 → A3 → A4 (o A5).
sealed class ImportState {
  const ImportState();
}

/// A2: esperando un archivo.
class ImportIdle extends ImportState {
  const ImportIdle();
}

/// A3, primera mitad: sacando el texto del PDF, página a página.
class ImportExtracting extends ImportState {
  const ImportExtracting({required this.fileName});
  final String fileName;
}

/// A3, segunda mitad: las filas van apareciendo. `refining` es la pasada con
/// Claude, que corre sobre lo que la heurística ya enseñó.
class ImportParsing extends ImportState {
  const ImportParsing({
    required this.fileName,
    required this.found,
    required this.done,
    required this.total,
    this.refining = false,
  });

  final String fileName;
  final List<ParsedClass> found;
  final int done;
  final int total;
  final bool refining;
}

/// A4: la persona revisa y corrige antes de guardar.
class ImportReview extends ImportState {
  ImportReview({required this.classes, required this.usedClaude, List<int>? ids})
      : ids = ids ?? List<int>.generate(classes.length, (i) => i);

  final List<ParsedClass> classes;

  /// Identidad estable de cada fila mientras se edita. Los índices cambian al
  /// quitar una materia; los campos de texto necesitan una clave que no.
  final List<int> ids;

  /// Para decirlo en la pantalla si hace falta; hoy solo se registra.
  final bool usedClaude;

  int get sessionCount => classes.fold(0, (n, c) => n + c.sessions.length);
  int get doubtCount => classes.where((c) => c.isLowConfidence).length;

  /// Se puede confirmar cuando toda materia tiene nombre y todo horario tiene
  /// día. Lo demás (profesor, salón) puede faltar.
  bool get canConfirm =>
      classes.isNotEmpty &&
      classes.every((c) => c.nombre.trim().isNotEmpty) &&
      classes.every((c) => c.sessions.every((s) => s.diaSemana >= 1 && s.diaSemana <= 7)) &&
      sessionCount > 0;

  ImportReview copyWith({List<ParsedClass>? classes, List<int>? ids}) =>
      ImportReview(classes: classes ?? this.classes, usedClaude: usedClaude, ids: ids ?? this.ids);
}

class ImportSaving extends ImportState {
  const ImportSaving();
}

class ImportDone extends ImportState {
  const ImportDone({required this.subjects, required this.sessions});
  final int subjects;
  final int sessions;
}

/// A5.
class ImportFailed extends ImportState {
  const ImportFailed(this.reason);
  final ImportFailure reason;
}

/// Cuántas filas se revelan por paso en A3. El revelado es una cascada de
/// `MotionStagger.pdfRows` por fila; con esto un PDF de cien líneas tarda lo
/// mismo en aparecer que uno de veinte.
const int _revealSteps = 20;

class ImportController extends StateNotifier<ImportState> {
  ImportController(this._ref) : super(const ImportIdle());

  final Ref _ref;

  /// Sube con cada importación o cancelación. Un resultado que llega con una
  /// generación vieja se descarta sin tocar el estado.
  int _generation = 0;

  /// Abre el selector del sistema. Si la persona lo cierra sin escoger, no
  /// pasa nada: A2 sigue ahí.
  Future<void> pick() async {
    final PlatformFile? file;
    final Uint8List bytes;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        // PDF del portal o calendario .ics (Google, Outlook, Moodle) (§50).
        allowedExtensions: const ['pdf', 'ics'],
      );
      if (file == null) return;
      bytes = await file.readAsBytes();
    } on Exception {
      // El selector del sistema falló o el archivo no se pudo leer: es el
      // mismo caso que un PDF ilegible, y A5 ya sabe decirlo.
      if (mounted) state = const ImportFailed(ImportFailure.unreadable);
      return;
    }
    await importBytes(bytes, fileName: file.name);
  }

  /// Un resultado es viejo si la persona canceló, empezó otra importación o
  /// cerró la pantalla mientras llegaba.
  bool _stale(int generation) => !mounted || generation != _generation;

  Future<void> importBytes(Uint8List bytes, {required String fileName}) async {
    final generation = ++_generation;
    state = ImportExtracting(fileName: fileName);

    // Un calendario no pasa por el extractor de PDF: ya trae días y horas.
    if (IcsScheduleParser.looksLikeIcs(bytes)) {
      final found = IcsScheduleParser.parse(utf8.decode(bytes, allowMalformed: true));
      if (found.isEmpty) {
        state = const ImportFailed(ImportFailure.nothingFound);
        return;
      }
      if (!await _reveal(found, fileName, generation)) return;
      _review(found, usedClaude: false);
      return;
    }

    final PdfTextResult text;
    try {
      text = await PdfText.extract(bytes);
    } on Exception {
      // PdfUnreadableException o cualquier tropiezo interno del extractor con
      // un archivo raro: para la persona es lo mismo, no se pudo abrir.
      if (_stale(generation)) return;
      state = const ImportFailed(ImportFailure.unreadable);
      return;
    }
    if (_stale(generation)) return;

    if (!text.hasText) {
      state = const ImportFailed(ImportFailure.noText);
      return;
    }

    // ── Primera pasada: la retícula, por coordenadas ────────────────────────
    // Los horarios de servicios académicos vienen como tabla con una columna
    // por día. Ahí la posición X de cada celda dice el día sin ambigüedad, y
    // el resultado es exacto: nombre, días, horas, salón, docente y créditos.
    // Dos retículas: la de «Servicios académicos» (la hora dentro de cada
    // celda) y la clásica (la hora en la fila). Gana la que lea más clases
    // sin dudas (§50).
    final grid = bestParse([
      ColumnScheduleParser.parse(text.positioned),
      TimeGridParser.parse(text.positioned),
    ]);

    final lines = text.lines;
    var found = grid;
    if (found.isEmpty) {
      // ── Segunda pasada: heurístico en cascada ─────────────────────────────
      // El PDF no tiene forma de retícula. El heurístico lee el texto plano y
      // las filas entran de a pocas para que la persona vea qué se encuentra.
      final step = (lines.length / _revealSteps).ceil().clamp(1, lines.length);
      for (var done = step; done <= lines.length + step - 1; done += step) {
        final upTo = done.clamp(0, lines.length);
        found = ScheduleParser.parse(lines.sublist(0, upTo));
        state = ImportParsing(fileName: fileName, found: found, done: upTo, total: lines.length);
        if (upTo == lines.length) break;
        await Future<void>.delayed(MotionStagger.pdfRows);
        if (_stale(generation)) return;
      }
    } else {
      if (!await _reveal(found, fileName, generation)) return;
    }

    // ── Tercera pasada: Claude, solo como red de seguridad ──────────────────
    // La importación no depende de la API: solo se pide ayuda cuando lo
    // determinista no alcanzó —ninguna materia, o todas con dudas—. Con la
    // retícula resuelta no se toca la red aunque haya clave configurada.
    var classes = found;
    var usedClaude = false;
    final needsHelp = found.isEmpty || found.every((c) => c.isLowConfidence);
    if (needsHelp && ClaudeScheduleParser.isConfigured) {
      state = ImportParsing(
        fileName: fileName,
        found: found,
        done: lines.length,
        total: lines.length,
        refining: true,
      );
      try {
        final source = text.layout.trim().isNotEmpty ? text.layout : lines.join('\n');
        final refined = await ClaudeScheduleParser().parse(source);
        if (_stale(generation)) return;
        if (refined.isNotEmpty) {
          classes = refined;
          usedClaude = true;
        }
      } on ClaudeParseException {
        // Sin red o sin respuesta útil: se sigue con lo que ya se encontró.
      }
    }
    if (_stale(generation)) return;

    if (classes.isEmpty) {
      state = const ImportFailed(ImportFailure.nothingFound);
      return;
    }
    state = ImportReview(classes: classes, usedClaude: usedClaude);
  }

  /// Revela lo leído fila a fila en A3: la lectura es de golpe, pero se
  /// entiende mejor viéndola llegar. False si la importación quedó vieja.
  Future<bool> _reveal(List<ParsedClass> found, String fileName, int generation) async {
    for (var shown = 1; shown <= found.length; shown++) {
      state = ImportParsing(
        fileName: fileName,
        found: found.sublist(0, shown),
        done: shown,
        total: found.length,
      );
      if (shown == found.length) break;
      await Future<void>.delayed(MotionStagger.pdfRows);
      if (_stale(generation)) return false;
    }
    return !_stale(generation);
  }

  void _review(List<ParsedClass> classes, {required bool usedClaude}) =>
      state = ImportReview(classes: classes, usedClaude: usedClaude);

  /// Durante la pasada con Claude: no esperar más y revisar lo que ya se
  /// encontró. La respuesta, si llega, se descarta por generación.
  void skipRefining() {
    final s = state;
    if (s is! ImportParsing || !s.refining) return;
    _generation++;
    state = s.found.isEmpty
        ? const ImportFailed(ImportFailure.nothingFound)
        : ImportReview(classes: s.found, usedClaude: false);
  }

  /// Cancelar durante A3 vuelve a A2. Lo que estaba en vuelo se descarta al
  /// llegar porque la generación ya no coincide.
  void cancel() {
    _generation++;
    state = const ImportIdle();
  }

  void reset() {
    _generation++;
    state = const ImportIdle();
  }

  // ------------------------------------------------------------- revisión

  /// Entra directo a A4 con unas materias ya leídas. Para tests: así el
  /// guardado se prueba con el horario real sin pasar por un PDF.
  @visibleForTesting
  void startReview(List<ParsedClass> classes) {
    _generation++;
    state = ImportReview(classes: classes, usedClaude: false);
  }

  void updateClass(int index, ParsedClass updated) {
    final s = state;
    if (s is! ImportReview) return;
    final list = [...s.classes];
    list[index] = updated;
    state = s.copyWith(classes: list);
  }

  void removeClass(int index) {
    final s = state;
    if (s is! ImportReview) return;
    final list = [...s.classes]..removeAt(index);
    final ids = [...s.ids]..removeAt(index);
    state = s.copyWith(classes: list, ids: ids);
  }

  /// Corregir un campo quita la duda que lo señalaba: si la persona ya lo
  /// miró, la insignia sobra.
  void setName(int index, String value) {
    final s = state;
    if (s is! ImportReview) return;
    final c = s.classes[index];
    updateClass(
      index,
      c.copyWith(
        nombre: value,
        doubts: {...c.doubts}..removeAll([ParseDoubt.missingName, ParseDoubt.nameFromPreviousLine]),
      ),
    );
  }

  void setProfesor(int index, String value) {
    final s = state;
    if (s is! ImportReview) return;
    final c = s.classes[index];
    final v = value.trim();
    updateClass(index, v.isEmpty ? c.copyWith(clearProfesor: true) : c.copyWith(profesor: v));
  }

  void setSalon(int index, String value) {
    final s = state;
    if (s is! ImportReview) return;
    final c = s.classes[index];
    final v = value.trim();
    // El salón que se escribe aquí vale para toda la materia: se limpia el de
    // cada sesión para que la corrección no quede tapada por el del PDF.
    final sessions = [for (final ses in c.sessions) ParsedSession(
      diaSemana: ses.diaSemana,
      inicio: ses.inicio,
      fin: ses.fin,
    )];
    updateClass(
      index,
      v.isEmpty
          ? c.copyWith(clearSalon: true, sessions: sessions)
          : c.copyWith(salon: v, sessions: sessions),
    );
  }

  void setSession(int classIndex, int sessionIndex, ParsedSession session) {
    final s = state;
    if (s is! ImportReview) return;
    final c = s.classes[classIndex];
    final sessions = [...c.sessions];
    if (sessionIndex < sessions.length) {
      sessions[sessionIndex] = session;
    } else {
      sessions.add(session);
    }
    updateClass(
      classIndex,
      c.copyWith(sessions: sessions, doubts: _sessionDoubts(c.doubts, sessions)),
    );
  }

  void removeSession(int classIndex, int sessionIndex) {
    final s = state;
    if (s is! ImportReview) return;
    final c = s.classes[classIndex];
    final sessions = [...c.sessions]..removeAt(sessionIndex);
    updateClass(
      classIndex,
      c.copyWith(sessions: sessions, doubts: _sessionDoubts(c.doubts, sessions)),
    );
  }

  static Set<ParseDoubt> _sessionDoubts(Set<ParseDoubt> current, List<ParsedSession> sessions) {
    final d = {...current}..removeAll([ParseDoubt.missingDays, ParseDoubt.badRange]);
    if (sessions.any((s) => s.diaSemana < 1 || s.diaSemana > 7)) d.add(ParseDoubt.missingDays);
    if (sessions.any((s) => s.fin <= s.inicio)) d.add(ParseDoubt.badRange);
    return d;
  }

  // ------------------------------------------------------------- guardar

  /// Crea materias, salones y clases. El color se asigna por orden de
  /// aparición, no al azar, para que dos importaciones del mismo PDF den el
  /// mismo resultado.
  Future<void> confirm() async {
    final s = state;
    if (s is! ImportReview || !s.canConfirm) return;
    state = const ImportSaving();
    try {
      final (subjects, sessions) = await _save(s);
      if (mounted) state = ImportDone(subjects: subjects, sessions: sessions);
    } on Object {
      // Antes un salón de más de 20 letras reventaba aquí a media materia: se
      // guardaban las primeras y la pantalla se quedaba girando para siempre.
      // Ahora la transacción deshace todo y la persona ve qué pasó.
      if (mounted) state = const ImportFailed(ImportFailure.saveFailed);
    }
  }

  /// Nombre y profesor aceptan hasta 80 en la base. Lo que venga más largo
  /// del PDF se recorta en vez de hacer fallar el guardado.
  static String _fit(String raw) {
    final t = raw.trim();
    return t.length <= 80 ? t : t.substring(0, 80).trim();
  }

  Future<(int, int)> _save(ImportReview s) async {
    final dao = _ref.read(subjectsDaoProvider);
    final defaultLimit = _ref.read(settingsProvider).valueOrNull?.limiteFaltasPorDefecto ??
        AttendanceCounter.defaultLimit;

    // Todo o nada: si una materia falla, no se queda la mitad del horario.
    return dao.transaction(() async {
    // Los colores siguen tras las materias que ya existen, para no repetir
    // el primero de la paleta en cada importación.
    final existing = await dao.watchOverview(includeArchived: true).first;
    var colorCursor = existing.length;

    // Los salones se comparten entre materias: se resuelven una sola vez.
    final roomIds = <String, int>{};
    Future<int?> ensureRoom(String? raw) async {
      var codigo = raw?.trim();
      if (codigo == null || codigo.isEmpty) return null;
      // El contrato del salón es de 80. Un PDF raro no debe tumbar el guardado.
      if (codigo.length > kRoomCodeMax) codigo = codigo.substring(0, kRoomCodeMax).trim();
      final cached = roomIds[codigo];
      if (cached != null) return cached;
      final id = await dao.ensureRoom(codigo: codigo);
      if (id != null) roomIds[codigo] = id;
      return id;
    }

    var sessions = 0;
    for (final c in s.classes) {
      final subjectId = await dao.createSubject(
        nombre: _fit(c.nombre),
        colorIndex: colorCursor++ % SubjectPalette.length,
        limiteFaltas: defaultLimit,
        profesor: c.profesor == null ? null : _fit(c.profesor!),
        creditos: c.creditos,
      );
      for (final ses in c.sessions) {
        // La misma materia se dicta en salas distintas según el día.
        await dao.saveSession(
          subjectId: subjectId,
          diaSemana: ses.diaSemana,
          horaInicio: ses.inicio.raw,
          horaFin: ses.fin.raw,
          roomId: await ensureRoom(ses.salon ?? c.salon),
        );
        sessions++;
      }
    }
    return (s.classes.length, sessions);
    });
  }
}

/// Largo máximo del código de salón. Igual a `Rooms.codigo`.
const int kRoomCodeMax = 80;

final importControllerProvider =
    StateNotifierProvider.autoDispose<ImportController, ImportState>(
  (ref) => ImportController(ref),
);

/// De varias lecturas del mismo archivo, la que más sirve: más sesiones y
/// menos materias con dudas. Una lectura vacía nunca gana a una con algo. En
/// empate, la primera (la del formato más específico).
List<ParsedClass> bestParse(List<List<ParsedClass>> candidates) {
  var best = const <ParsedClass>[];
  var bestScore = 0;
  for (final c in candidates) {
    final sessions = c.fold<int>(0, (n, x) => n + x.sessions.length);
    final doubtful = c.where((x) => x.isLowConfidence).length;
    final score = sessions * 2 - doubtful * 3;
    if (c.isNotEmpty && (best.isEmpty || score > bestScore)) {
      best = c;
      bestScore = score;
    }
  }
  return best;
}
