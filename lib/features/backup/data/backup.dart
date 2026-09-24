import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart' as sql;

/// Por qué no se puede restaurar un archivo.
enum BackupProblem {
  /// No es una base SQLite (otro archivo, uno dañado o vacío).
  notADatabase,

  /// Es SQLite pero no de esta app: no tiene sus tablas.
  foreign,

  /// Viene de una versión más nueva de la app: esta no sabe leerla.
  tooNew,
}

class BackupCheck {
  const BackupCheck.ok(this.schemaVersion) : problem = null;
  const BackupCheck.bad(this.problem) : schemaVersion = null;

  final BackupProblem? problem;
  final int? schemaVersion;

  bool get isOk => problem == null;
}

/// La copia de seguridad es la base misma: un archivo SQLite con todo
/// (materias, horario, faltas, notas, pendientes, viajes y ajustes). Sirve
/// para pasar los datos entre «Kairós» y «Kairós Dev», a otro teléfono o
/// guardarlos por si acaso (§51).
///
/// Dart puro sobre `sqlite3`: se prueba sin Flutter.
abstract final class Backup {
  /// Extensión de los archivos. Es una base SQLite normal con otro nombre.
  static const String extension = 'kairos';

  static final List<int> _magic = 'SQLite format 3\u0000'.codeUnits;

  /// Revisa [bytes] antes de restaurar. [currentSchema] es el `schemaVersion`
  /// de la app: una copia más vieja se migra al abrir; una más nueva no.
  static BackupCheck check(Uint8List bytes, {required int currentSchema, required Directory tmp}) {
    if (bytes.length < 100) return const BackupCheck.bad(BackupProblem.notADatabase);
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return const BackupCheck.bad(BackupProblem.notADatabase);
    }
    final file = File('${tmp.path}/check-${DateTime.now().microsecondsSinceEpoch}.sqlite');
    file.writeAsBytesSync(bytes, flush: true);
    try {
      final db = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
      try {
        final tables = db
            .select("SELECT name FROM sqlite_master WHERE type = 'table'")
            .map((r) => r['name'] as String)
            .toSet();
        if (!tables.containsAll(const {'user_settings', 'subjects', 'class_sessions', 'session_instances'})) {
          return const BackupCheck.bad(BackupProblem.foreign);
        }
        final version = db.select('PRAGMA user_version').first.values.first as int;
        if (version > currentSchema) return const BackupCheck.bad(BackupProblem.tooNew);
        return BackupCheck.ok(version);
      } finally {
        db.close();
      }
    } on Object {
      return const BackupCheck.bad(BackupProblem.notADatabase);
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// Nombre del archivo exportado: `kairos-2026-09-24.kairos`.
  static String fileName(DateTime now, {String prefix = 'kairos'}) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '$prefix-${now.year}-${two(now.month)}-${two(now.day)}.$extension';
  }

  /// Reemplaza la base en [target] por [bytes]. La de antes queda como
  /// `<nombre>.antes-de-restaurar` por si hay que volver atrás, y se borran
  /// los archivos del journal (-wal, -shm) de la vieja. La base tiene que
  /// estar cerrada.
  static void replace(File target, Uint8List bytes) {
    if (target.existsSync()) target.copySync('${target.path}.antes-de-restaurar');
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final f = File('${target.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    target.writeAsBytesSync(bytes, flush: true);
  }
}
