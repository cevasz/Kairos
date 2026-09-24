import 'dart:io';
import 'dart:typed_data';

import 'package:kairos/core/db/database.dart';
import 'package:kairos/features/backup/data/backup.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('backup_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Una base real en disco con una materia, exportada con VACUUM INTO.
  Future<(Uint8List, int)> exported() async {
    final db = KairosDatabase.forTesting(NativeDatabase(File('${tmp.path}/app.sqlite')));
    await db.subjectsDao.createSubject(nombre: 'Física', colorIndex: 2, limiteFaltas: 4);
    final out = '${tmp.path}/copia.sqlite';
    await db.customStatement('VACUUM INTO ?', [out]);
    final version = db.schemaVersion;
    await db.close();
    return (File(out).readAsBytesSync(), version);
  }

  test('una copia exportada se valida y trae sus datos', () async {
    final (bytes, version) = await exported();
    final check = Backup.check(bytes, currentSchema: version, tmp: tmp);
    expect(check.isOk, isTrue);
    expect(check.schemaVersion, version);

    // Restaurada sobre otra base, la materia está.
    final target = File('${tmp.path}/otra.sqlite')..writeAsStringSync('vieja');
    Backup.replace(target, bytes);
    expect(File('${target.path}.antes-de-restaurar').readAsStringSync(), 'vieja');
    final db = KairosDatabase.forTesting(NativeDatabase(target));
    final names = (await db.select(db.subjects).get()).map((s) => s.nombre);
    expect(names, ['Física']);
    await db.close();
  });

  test('un archivo cualquiera no es una copia', () {
    final junk = Uint8List.fromList(List.filled(500, 7));
    expect(Backup.check(junk, currentSchema: 6, tmp: tmp).problem, BackupProblem.notADatabase);
    expect(Backup.check(Uint8List(0), currentSchema: 6, tmp: tmp).problem, BackupProblem.notADatabase);
  });

  test('otra base SQLite no es de Kairós', () {
    final path = '${tmp.path}/ajena.sqlite';
    sql.sqlite3.open(path)
      ..execute('CREATE TABLE fotos (id INTEGER)')
      ..close();
    expect(Backup.check(File(path).readAsBytesSync(), currentSchema: 6, tmp: tmp).problem, BackupProblem.foreign);
  });

  test('una copia de una versión más nueva se rechaza', () async {
    final (bytes, version) = await exported();
    final path = '${tmp.path}/nueva.sqlite';
    File(path).writeAsBytesSync(bytes);
    sql.sqlite3.open(path)
      ..execute('PRAGMA user_version = ${version + 1}')
      ..close();
    expect(
      Backup.check(File(path).readAsBytesSync(), currentSchema: version, tmp: tmp).problem,
      BackupProblem.tooNew,
    );
  });

  test('el nombre del archivo lleva la fecha', () {
    expect(Backup.fileName(DateTime(2026, 9, 4)), 'kairos-2026-09-04.kairos');
    expect(Backup.fileName(DateTime(2026, 9, 4), prefix: 'kairos-dev'), 'kairos-dev-2026-09-04.kairos');
  });
}
