import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

// SessionStatus y TransportMode los necesita database.g.dart, que es un `part`
// de este archivo y por tanto ve estos imports, no los de tables.dart.
import '../../domain/attendance/attendance.dart';
import '../../domain/departure/departure.dart';
import 'daos/schedule_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/subjects_dao.dart';
import 'daos/tasks_dao.dart';
import 'daos/trips_dao.dart';
import 'schema_versions.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Semesters,
    Subjects,
    Campuses,
    Rooms,
    ClassSessions,
    SessionInstances,
    Evaluations,
    Tasks,
    UserSettings,
    Trips,
  ],
  daos: [ScheduleDao, SubjectsDao, SettingsDao, TasksDao, TripsDao],
)
class KairosDatabase extends _$KairosDatabase {
  KairosDatabase() : super(_open());

  /// Para tests: base en memoria, sin tocar disco ni plugins.
  KairosDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // La fila única de ajustes tiene que existir desde el arranque; si no,
          // toda lectura de ajustes necesitaría un caso nulo.
          await into(userSettings).insert(
            const UserSettingsCompanion(id: Value(1)),
            mode: InsertMode.insertOrIgnore,
          );
        },
        // Cada salto se declara aquí. El esquema de cada versión se exporta a
        // `drift_schemas/` con `dart run drift_dev schema dump`, y
        // `test/core/migration_test.dart` verifica los saltos contra esos
        // volcados.
        onUpgrade: stepByStep(
          // v2: materia cancelada. Dos columnas nuevas con default, así que
          // las materias que ya existen quedan activas sin tocar nada más.
          from1To2: (m, schema) async {
            await m.addColumn(schema.subjects, schema.subjects.cancelada);
            await m.addColumn(schema.subjects, schema.subjects.fechaCancelacion);
          },
          // v3: pendientes por materia, Erizógenes en la esquina y alarmas.
          // Una tabla nueva y columnas con default: nada que ya exista cambia.
          from2To3: (m, schema) async {
            await m.createTable(schema.tasks);
            final s = schema.userSettings;
            await m.addColumn(s, s.mascotaEsquina);
            await m.addColumn(s, s.alarmaDespertar);
            await m.addColumn(s, s.alarmaDespertarMin);
            await m.addColumn(s, s.alarmaSalir);
            await m.addColumn(s, s.alarmaEvaluaciones);
            await m.addColumn(s, s.avisoEvaluacionMin);
          },
          // v4: trayecto medido por la persona. Nulo para todos los que ya
          // tenían la app: siguen con el estimado del modo hasta que lo pongan.
          from3To4: (m, schema) async {
            await m.addColumn(schema.userSettings, schema.userSettings.trayectoMinutos);
          },
          // v5: anotar falta si sigues en casa. Apagado para todos: se activa
          // a mano porque pide ubicación en segundo plano.
          from4To5: (m, schema) async {
            await m.addColumn(schema.userSettings, schema.userSettings.detectarCasa);
          },
          // v6: el trayecto aprende y los temas de color. Viajes medidos, la ruta por calles y el
          // viaje en curso; todo nulo o encendido sin datos, así que la hora
          // de salida de nadie cambia al actualizar.
          from5To6: (m, schema) async {
            await m.createTable(schema.trips);
            final s = schema.userSettings;
            await m.addColumn(s, s.aprenderTrayecto);
            await m.addColumn(s, s.rutaPieMin);
            await m.addColumn(s, s.rutaCarroMin);
            await m.addColumn(s, s.enCaminoDesde);
            await m.addColumn(s, s.enCaminoModo);
            // Y el tema de color: Papiro para todos, que es como se veía.
            await m.addColumn(s, s.temaPaleta);
            await m.addColumn(s, s.temaPapel);
            await m.addColumn(s, s.temaAcento);
          },
        ),
        beforeOpen: (details) async {
          // Las claves foráneas están apagadas por defecto en SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kairos.sqlite'));
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    return NativeDatabase.createInBackground(file);
  });
}
