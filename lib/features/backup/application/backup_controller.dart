import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../data/backup.dart';

enum ExportResult { saved, cancelled, failed }

sealed class ImportResult {
  const ImportResult();
}

class ImportDoneResult extends ImportResult {
  const ImportDoneResult();
}

class ImportCancelled extends ImportResult {
  const ImportCancelled();
}

class ImportRejected extends ImportResult {
  const ImportRejected(this.problem);
  final BackupProblem? problem;
}

final backupControllerProvider = Provider<BackupController>((ref) => BackupController(ref));

/// Exportar y restaurar la copia de seguridad desde Ajustes (§51).
class BackupController {
  BackupController(this._ref);
  final Ref _ref;

  /// Guarda una copia consistente de la base donde la persona elija.
  /// `VACUUM INTO` escribe la base entera a otro archivo sin cerrarla.
  Future<ExportResult> export() async {
    try {
      final db = _ref.read(databaseProvider);
      final tmp = await getTemporaryDirectory();
      final path = '${tmp.path}/export-${DateTime.now().microsecondsSinceEpoch}.sqlite';
      await db.customStatement('VACUUM INTO ?', [path]);
      final file = await File(path).readAsBytes();
      await File(path).delete();
      final uri = await FilePicker.saveFile(
        fileName: Backup.fileName(DateTime.now(), prefix: appFlavor == 'dev' ? 'kairos-dev' : 'kairos'),
        bytes: file,
      );
      return uri == null ? ExportResult.cancelled : ExportResult.saved;
    } on Object {
      return ExportResult.failed;
    }
  }

  /// Elige un archivo, lo valida y reemplaza la base. La base vieja queda al
  /// lado como `.antes-de-restaurar`. Al invalidar el provider de la base, la
  /// app entera vuelve a leer y, si la copia es de una versión anterior, la
  /// migra al abrirla.
  Future<ImportResult> restore() async {
    final Uint8List bytes;
    try {
      final picked = await FilePicker.pickFile(type: FileType.any);
      if (picked == null) return const ImportCancelled();
      bytes = await picked.readAsBytes();
    } on Object {
      return const ImportRejected(null);
    }
    final db = _ref.read(databaseProvider);
    final check = Backup.check(bytes, currentSchema: db.schemaVersion, tmp: await getTemporaryDirectory());
    if (!check.isOk) return ImportRejected(check.problem);
    try {
      await db.close();
      Backup.replace(await databaseFile(), bytes);
    } on Object {
      _ref.invalidate(databaseProvider);
      return const ImportRejected(null);
    }
    _ref.invalidate(databaseProvider);
    return const ImportDoneResult();
  }
}
