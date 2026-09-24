import 'package:drift/drift.dart';

import '../../../domain/departure/departure.dart';
import '../database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

/// La fila única de ajustes. Se lee como stream para que cambiar el buffer en
/// Ajustes mueva la hora de salida de Hoy sin recargar nada.
@DriftAccessor(tables: [UserSettings])
class SettingsDao extends DatabaseAccessor<KairosDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// `onCreate` inserta la fila 1, así que `watchSingle` no debería fallar
  /// nunca. Si alguien la borra a mano, mejor que reviente aquí que pintar
  /// ajustes inventados.
  Stream<UserSetting> watch() =>
      (select(userSettings)..where((t) => t.id.equals(1))).watchSingle();

  Future<UserSetting> get() =>
      (select(userSettings)..where((t) => t.id.equals(1))).getSingle();

  /// Cada campo se escribe por separado: una pantalla de ajustes guarda al
  /// tocar, no con un botón de «Guardar», y no debe pisar lo que no tocó.
  Future<void> setBuffer(int minutos) => _write(
        UserSettingsCompanion(bufferMinutos: Value(minutos)),
      );

  Future<void> setTransport(TransportMode mode) => _write(
        UserSettingsCompanion(modoTransporte: Value(mode)),
      );

  /// Dónde está la casa: el punto desde el que se sale y en el que «seguir
  /// en casa» cuenta como falta. Solo se guarda en el teléfono.
  Future<void> setHome(double lat, double lng) => _write(
        UserSettingsCompanion(homeLat: Value(lat), homeLng: Value(lng)),
      );

  Future<void> setDetectHome(bool on) => _write(UserSettingsCompanion(detectarCasa: Value(on)));

  /// Null vuelve al estimado del modo de transporte.
  Future<void> setTravelMinutes(int? minutos) => _write(
        UserSettingsCompanion(trayectoMinutos: Value(minutos)),
      );

  Future<void> setLearnTravel(bool on) => _write(UserSettingsCompanion(aprenderTrayecto: Value(on)));

  /// Lo que dijo la ruta por calles, en minutos. Null borra el cálculo.
  Future<void> setRouteMinutes({int? walk, int? car}) => _write(
        UserSettingsCompanion(rutaPieMin: Value(walk), rutaCarroMin: Value(car)),
      );

  Future<void> setDefaultAbsenceLimit(int limite) => _write(
        UserSettingsCompanion(limiteFaltasPorDefecto: Value(limite)),
      );

  /// `tema` guarda el índice de `ThemeMode` (0 auto, 1 claro, 2 oscuro). Se
  /// recibe el entero y no el enum porque este archivo no importa Flutter.
  Future<void> setThemeIndex(int index) => _write(
        UserSettingsCompanion(tema: Value(index)),
      );

  /// El tema de color. Para `propio`, [paper] y [accent] son ARGB.
  Future<void> setPalette(String id, {int? paper, int? accent}) => _write(
        UserSettingsCompanion(
          temaPaleta: Value(id),
          temaPapel: Value(paper),
          temaAcento: Value(accent),
        ),
      );

  Future<void> setMascotCorner(bool on) => _write(UserSettingsCompanion(mascotaEsquina: Value(on)));

  Future<void> setWakeAlarm(bool on) => _write(UserSettingsCompanion(alarmaDespertar: Value(on)));

  Future<void> setWakeMinutes(int minutos) =>
      _write(UserSettingsCompanion(alarmaDespertarMin: Value(minutos)));

  Future<void> setLeaveAlarm(bool on) => _write(UserSettingsCompanion(alarmaSalir: Value(on)));

  Future<void> setEvalAlarm(bool on) => _write(UserSettingsCompanion(alarmaEvaluaciones: Value(on)));

  /// Minutos desde medianoche del aviso de la víspera.
  Future<void> setEvalReminderMinute(int minuto) =>
      _write(UserSettingsCompanion(avisoEvaluacionMin: Value(minuto)));

  Future<void> _write(UserSettingsCompanion data) =>
      (update(userSettings)..where((t) => t.id.equals(1))).write(data);
}
