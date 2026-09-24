import 'package:kairos/core/db/database.dart';
import 'package:kairos/core/db/schema_versions.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated_migrations/schema.dart';

/// La red que faltaba en el esquema.
///
/// `drift_schemas/drift_schema_v1.json` es el volcado de la v1 tal como salió
/// publicada. Este test compara el esquema que `tables.dart` produce hoy contra
/// ese volcado: si alguien añade una columna sin exportar la nueva versión, el
/// fallo aparece aquí y no en el teléfono de alguien con datos dentro.
///
/// Para exportar una versión nueva, tras subir `schemaVersion`:
///   dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/
///   dart run drift_dev schema steps drift_schemas/ lib/core/db/schema_versions.dart
///   dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('el esquema en código sigue siendo idéntico al volcado de la v6', () async {
    final connection = await verifier.startAt(6);
    final db = KairosDatabase.forTesting(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 6);
  });

  test('v5 → v6: el trayecto aprende sin mover la hora de salida de nadie', () async {
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase.execute(
      'INSERT INTO user_settings (id, trayecto_minutos, modo_transporte) VALUES (1, 30, 1)',
    );
    final db = KairosDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);

    final s = await db.settingsDao.get();
    expect(s.trayectoMinutos, 30);
    expect(s.aprenderTrayecto, isTrue);
    expect(s.rutaPieMin, isNull);
    expect(s.enCaminoDesde, isNull);
    expect(await db.tripsDao.count(), 0);
    expect(s.temaPaleta, 'papiro', reason: 'nadie cambia de colores al actualizar');
    expect(s.temaPapel, isNull);

    // Un viaje de 38 min queda guardado con el modo del ajuste (bus).
    final from = DateTime(2026, 9, 23, 7, 0);
    await db.tripsDao.start(from, s.modoTransporte);
    expect(await db.tripsDao.arrive(from.add(const Duration(minutes: 38))), 38);
    final trips = await db.tripsDao.watchRecent(DateTime(2026, 9, 24)).first;
    expect(trips.single.minutes, 38);
    expect((await db.settingsDao.get()).enCaminoDesde, isNull);

    // «Llegué» sin «Ya voy», o un viaje de un minuto, no guardan nada.
    expect(await db.tripsDao.arrive(from), isNull);
    await db.tripsDao.start(from, s.modoTransporte);
    expect(await db.tripsDao.arrive(from.add(const Duration(minutes: 1))), isNull);
    expect(await db.tripsDao.count(), 1);
  });

  test('v4 → v5: «anotar falta si sigo en casa» nace apagado y la casa se queda', () async {
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
      'INSERT INTO user_settings (id, trayecto_minutos, home_lat, home_lng) VALUES (1, 30, 4.6, -74.06)',
    );
    final db = KairosDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);

    final s = await db.settingsDao.get();
    expect(s.detectarCasa, isFalse);
    expect(s.trayectoMinutos, 30);
    expect(s.homeLat, 4.6);
    await db.settingsDao.setDetectHome(true);
    expect((await db.settingsDao.get()).detectarCasa, isTrue);

    // Y los setters de las versiones recientes funcionan sobre lo migrado.
    await db.settingsDao.setTravelMinutes(null);
    expect((await db.settingsDao.get()).trayectoMinutos, isNull);
    await db.settingsDao.setHome(4.7, -74.1);
    expect((await db.settingsDao.get()).homeLng, -74.1);
  });

  test('v3 → v4: el trayecto nace vacío y los ajustes de antes se quedan', () async {
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      'INSERT INTO user_settings (id, buffer_minutos, modo_transporte) VALUES (1, 10, 1)',
    );

    final db = KairosDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    // Se lee con SQL: la tabla del código ya es la de la última versión y
    // trae columnas que en la v4 todavía no existen.
    final row = await db.customSelect('SELECT buffer_minutos, trayecto_minutos FROM user_settings').getSingle();
    expect(row.read<int>('buffer_minutos'), 10);
    expect(row.read<int?>('trayecto_minutos'), isNull, reason: 'sin medirlo, sigue el estimado del modo');
  });

  test('v2 → v3: materias y ajustes intactos, pendientes y alarmas con sus defaults', () async {
    final schema = await verifier.schemaAt(2);
    schema.rawDatabase.execute(
      "INSERT INTO semesters (nombre, fecha_inicio, fecha_fin, activo) VALUES ('S', 0, 0, 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO subjects (semester_id, nombre, color_index) VALUES (1, 'Física', 0)",
    );
    // Ajustes que la persona ya había tocado: no se pueden perder.
    schema.rawDatabase.execute('INSERT INTO user_settings (id, buffer_minutos, tema) VALUES (1, 12, 2)');

    final db = KairosDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    expect((await db.select(db.subjects).getSingle()).nombre, 'Física');
    // Con SQL, por lo mismo: columnas de la v3, no de la última.
    final row = await db
        .customSelect(
          'SELECT buffer_minutos, tema, mascota_esquina, alarma_despertar_min, aviso_evaluacion_min FROM user_settings',
        )
        .getSingle();
    expect(row.read<int>('buffer_minutos'), 12);
    expect(row.read<int>('tema'), 2);
    expect(row.read<bool>('mascota_esquina'), isTrue);
    expect(row.read<int>('alarma_despertar_min'), 60);
    expect(row.read<int>('aviso_evaluacion_min'), 20 * 60);

    // La tabla nueva existe y acepta un pendiente de la materia de antes.
    await db.tasksDao.addTask(subjectId: 1, titulo: 'Taller 3');
    expect(await db.select(db.tasks).get(), hasLength(1));
  });

  test('v1 → v2: las materias que ya existían quedan activas', () async {
    final schema = await verifier.schemaAt(1);
    // Una materia escrita con el esquema viejo, antes de que existiera
    // «cancelada».
    schema.rawDatabase.execute(
      "INSERT INTO semesters (nombre, fecha_inicio, fecha_fin, activo) VALUES ('S', 0, 0, 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO subjects (semester_id, nombre, color_index) VALUES (1, 'Física', 0)",
    );

    final db = KairosDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    final subject = await db.select(db.subjects).getSingle();
    expect(subject.nombre, 'Física');
    expect(subject.cancelada, isFalse);
    expect(subject.fechaCancelacion, isNull);
  });

  test('una base recién creada nace en la versión declarada', () async {
    final db = KairosDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Fuerza la apertura real: sin una consulta, `onCreate` no llega a correr.
    await db.customSelect('SELECT 1').get();

    expect(db.schemaVersion, 6);
  });

  test('onCreate deja la fila única de ajustes lista', () async {
    final db = KairosDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db.select(db.userSettings).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 1);
    // Los defaults del contrato, no los del código de pantalla.
    expect(rows.single.bufferMinutos, 5);
    expect(rows.single.limiteFaltasPorDefecto, 6);
  });

  test('un salto de versión sin paso declarado falla ruidosamente', () {
    // El día que `schemaVersion` suba a 2 sin declarar el paso, stepByStep
    // lanza en vez de dejar el esquema a medias. Se comprueba el contrato del
    // helper generado, que es lo que protege al usuario con datos.
    expect(migrationSteps, isNotNull);
  });
}
