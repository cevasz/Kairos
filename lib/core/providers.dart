import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/palette.dart';
import '../theme/tokens.g.dart';
import 'db/daos/schedule_dao.dart';
import 'db/daos/settings_dao.dart';
import 'db/daos/subjects_dao.dart';
import 'db/daos/tasks_dao.dart';
import 'db/daos/trips_dao.dart';
import 'db/database.dart';

/// Instancia única de la base. Se cierra con el ciclo de vida del ProviderScope.
final databaseProvider = Provider<KairosDatabase>((ref) {
  final db = KairosDatabase();
  ref.onDispose(db.close);
  return db;
});

final scheduleDaoProvider = Provider<ScheduleDao>(
  (ref) => ref.watch(databaseProvider).scheduleDao,
);

final subjectsDaoProvider = Provider<SubjectsDao>(
  (ref) => ref.watch(databaseProvider).subjectsDao,
);

final tasksDaoProvider = Provider<TasksDao>(
  (ref) => ref.watch(databaseProvider).tasksDao,
);

final tripsDaoProvider = Provider<TripsDao>(
  (ref) => ref.watch(databaseProvider).tripsDao,
);

final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(databaseProvider).settingsDao,
);

/// Los ajustes de la persona, en vivo. Hoy los lee para el buffer y el modo de
/// transporte; el formulario de materia para el límite de faltas por defecto.
final settingsProvider = StreamProvider<UserSetting>(
  (ref) => ref.watch(settingsDaoProvider).watch(),
);

/// El día que la app considera «hoy».
///
/// Es un provider y no `DateTime.now()` suelto para poder moverlo en tests y
/// para que el cambio de medianoche invalide las vistas que dependen de él.
final todayProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// Reloj de minuto. El anillo, el odómetro y la hora de salida se recalculan
/// con esto; nadie llama a DateTime.now() dentro de un build.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(MotionDurations.clockTick, (_) => DateTime.now());
});

/// El tema sale de la fila de ajustes: `tema` guarda el índice de `ThemeMode`.
/// Mientras la base abre se usa el del sistema, que es también el default de
/// la columna, así que no hay parpadeo al cargar.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final index = ref.watch(settingsProvider).valueOrNull?.tema;
  if (index == null || index < 0 || index >= ThemeMode.values.length) {
    return ThemeMode.system;
  }
  return ThemeMode.values[index];
});

/// El tema de color activo. Null: Papiro, el contrato tal cual.
final paletteProvider = Provider<AppPalette?>((ref) {
  final s = ref.watch(settingsProvider).valueOrNull;
  if (s == null) return null;
  return Palettes.resolve(s.temaPaleta, paper: s.temaPapel, accent: s.temaAcento);
});

/// Pestaña activa del shell. Es un provider y no estado local del shell para
/// que «Ver la semana», en el día vacío, pueda cambiar de pestaña sin que la
/// pantalla Hoy conozca al shell.
final shellTabProvider = StateProvider<int>((ref) => 0);
