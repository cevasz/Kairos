import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/import/parsed_schedule.dart';
import '../../../theme/tokens.g.dart';
import '../data/ics_schedule_parser.dart';

/// Por qué falló la importación. Cada motivo tiene su texto en la pantalla
/// de error.
enum ImportFailure {
  /// El archivo no es un calendario .ics.
  notCalendar,

  /// No se pudo abrir: el selector falló o el archivo no se dejó leer.
  unreadable,

  /// Es un calendario, pero no trae ningún evento que sirva de bloque.
  nothingFound,

  /// Se leyó bien, pero guardar falló. No queda nada a medias: el guardado
  /// va en una transacción.
  saveFailed,
}

/// La máquina de estados del importador: elegir → leer → revisar (o error).
sealed class ImportState {
  const ImportState();
}

/// Esperando un archivo.
class ImportIdle extends ImportState {
  const ImportIdle();
}

/// Las actividades leídas van apareciendo de a una.
class ImportParsing extends ImportState {
  const ImportParsing({
    required this.fileName,
    required this.found,
    required this.done,
    required this.total,
  });

  final String fileName;
  final List<ParsedClass> found;
  final int done;
  final int total;
}

/// La persona revisa y corrige antes de guardar.
class ImportReview extends ImportState {
  ImportReview({required this.classes, List<int>? ids})
      : ids = ids ?? List<int>.generate(classes.length, (i) => i);

  final List<ParsedClass> classes;

  /// Identidad estable de cada fila mientras se edita. Los índices cambian al
  /// quitar una actividad; los campos de texto necesitan una clave que no.
  final List<int> ids;

  int get sessionCount => classes.fold(0, (n, c) => n + c.sessions.length);
  int get doubtCount => classes.where((c) => c.isLowConfidence).length;

  /// Se puede confirmar cuando toda actividad tiene nombre y todo bloque tiene
  /// día. Lo demás (con quién, lugar) puede faltar.
  bool get canConfirm =>
      classes.isNotEmpty &&
      classes.every((c) => c.nombre.trim().isNotEmpty) &&
      classes.every((c) => c.sessions.every((s) => s.diaSemana >= 1 && s.diaSemana <= 7)) &&
      sessionCount > 0;

  ImportReview copyWith({List<ParsedClass>? classes, List<int>? ids}) =>
      ImportReview(classes: classes ?? this.classes, ids: ids ?? this.ids);
}

class ImportSaving extends ImportState {
  const ImportSaving();
}

class ImportDone extends ImportState {
  const ImportDone({required this.subjects, required this.sessions});
  final int subjects;
  final int sessions;
}

class ImportFailed extends ImportState {
  const ImportFailed(this.reason);
  final ImportFailure reason;
}

class ImportController extends StateNotifier<ImportState> {
  ImportController(this._ref) : super(const ImportIdle());

  final Ref _ref;

  /// Sube con cada importación o cancelación. Un resultado que llega con una
  /// generación vieja se descarta sin tocar el estado.
  int _generation = 0;

  /// Abre el selector del sistema. Si la persona lo cierra sin escoger, no
  /// pasa nada: la pantalla sigue esperando.
  Future<void> pick() async {
    final PlatformFile? file;
    final Uint8List bytes;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        // Calendario exportado de Google, Outlook, Apple o cualquier otro.
        allowedExtensions: const ['ics'],
      );
      if (file == null) return;
      bytes = await file.readAsBytes();
    } on Exception {
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
    if (!IcsScheduleParser.looksLikeIcs(bytes)) {
      state = const ImportFailed(ImportFailure.notCalendar);
      return;
    }
    final found = IcsScheduleParser.parse(utf8.decode(bytes, allowMalformed: true));
    if (found.isEmpty) {
      state = const ImportFailed(ImportFailure.nothingFound);
      return;
    }
    if (!await _reveal(found, fileName, generation)) return;
    state = ImportReview(classes: found);
  }

  /// Revela lo leído fila a fila: la lectura es de golpe, pero se entiende
  /// mejor viéndola llegar. False si la importación quedó vieja.
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

  /// Cancelar mientras se lee vuelve a esperar un archivo. Lo que estaba en
  /// vuelo se descarta al llegar porque la generación ya no coincide.
  void cancel() {
    _generation++;
    state = const ImportIdle();
  }

  void reset() {
    _generation++;
    state = const ImportIdle();
  }

  // ------------------------------------------------------------- revisión

  /// Entra directo a la revisión con unas actividades ya leídas. Para tests:
  /// así el guardado se prueba sin pasar por un archivo.
  @visibleForTesting
  void startReview(List<ParsedClass> classes) {
    _generation++;
    state = ImportReview(classes: classes);
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
        doubts: {...c.doubts}..remove(ParseDoubt.missingName),
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
    // El lugar que se escribe aquí vale para toda la actividad: se limpia el
    // de cada bloque para que la corrección no quede tapada por el del archivo.
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

  /// Crea actividades, lugares y bloques. El color se asigna por orden de
  /// aparición, no al azar, para que dos importaciones del mismo archivo den
  /// el mismo resultado.
  Future<void> confirm() async {
    final s = state;
    if (s is! ImportReview || !s.canConfirm) return;
    state = const ImportSaving();
    try {
      final (subjects, sessions) = await _save(s);
      if (mounted) state = ImportDone(subjects: subjects, sessions: sessions);
    } on Object {
      // La transacción deshace todo y la persona ve qué pasó, en vez de
      // quedarse con media importación y la pantalla girando.
      if (mounted) state = const ImportFailed(ImportFailure.saveFailed);
    }
  }

  /// Nombre y «con quién» aceptan hasta 80 en la base. Lo que venga más largo
  /// del archivo se recorta en vez de hacer fallar el guardado.
  static String _fit(String raw) {
    final t = raw.trim();
    return t.length <= 80 ? t : t.substring(0, 80).trim();
  }

  Future<(int, int)> _save(ImportReview s) async {
    final dao = _ref.read(subjectsDaoProvider);
    final defaultLimit = _ref.read(settingsProvider).valueOrNull?.limiteFaltasPorDefecto ??
        AttendanceCounter.defaultLimit;

    // Todo o nada: si una actividad falla, no se queda la mitad del horario.
    return dao.transaction(() async {
    // Los colores siguen tras las actividades que ya existen, para no repetir
    // el primero de la paleta en cada importación.
    final existing = await dao.watchOverview(includeArchived: true).first;
    var colorCursor = existing.length;

    // Los lugares se comparten entre actividades: se resuelven una sola vez.
    final roomIds = <String, int>{};
    Future<int?> ensureRoom(String? raw) async {
      var codigo = raw?.trim();
      if (codigo == null || codigo.isEmpty) return null;
      // El contrato del lugar es de 80. Un archivo raro no tumba el guardado.
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
      );
      for (final ses in c.sessions) {
        // La misma actividad puede tener lugares distintos según el día.
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

/// Largo máximo del nombre de un lugar. Igual a `Rooms.codigo`.
const int kRoomCodeMax = 80;

final importControllerProvider =
    StateNotifierProvider.autoDispose<ImportController, ImportState>(
  (ref) => ImportController(ref),
);
