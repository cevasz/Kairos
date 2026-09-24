import 'package:flutter/services.dart';

import '../../domain/attendance/attendance.dart';

/// Una comprobación de «¿sigues en casa?» para una sesión concreta.
typedef HomeCheckItem = ({int instanceId, DateTime at, String clase});

/// El puente con `AttendanceChecks.kt`: programa las comprobaciones y
/// recoge los veredictos que dejó Android mientras la app estaba cerrada.
/// Fuera de Android no hace nada.
class AttendanceChannel {
  const AttendanceChannel();

  static const _channel = MethodChannel('kairos/attendance');

  /// Reemplaza todas las comprobaciones. Con [items] vacío, las cancela.
  Future<void> schedule({
    required List<HomeCheckItem> items,
    required double lat,
    required double lng,
    required int radiusMeters,
    required int maxAccuracyMeters,
    required Map<String, String> strings,
  }) async {
    try {
      await _channel.invokeMethod<bool>('schedule', {
        'lat': lat,
        'lng': lng,
        'radius': radiusMeters,
        'maxAccuracy': maxAccuracyMeters,
        'strings': strings,
        'items': [
          for (final i in items) {'id': i.instanceId, 'at': i.at.millisecondsSinceEpoch, 'clase': i.clase},
        ],
      });
    } on PlatformException {
      // Sin el canal no hay comprobaciones; la app sigue igual.
    } on MissingPluginException {
      // Idem fuera de Android.
    }
  }

  /// Lo que Android decidió con la app cerrada, en orden, y ya fuera de la
  /// cola nativa.
  Future<List<(int, SessionStatus)>> takeVerdicts() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('takeVerdicts') ?? const [];
      return [
        for (final v in raw)
          if (v['id'] is int)
            (
              v['id']! as int,
              v['status'] == 'asistio' ? SessionStatus.asistio : SessionStatus.falto,
            ),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<bool> hasBackgroundLocation() async {
    try {
      return await _channel.invokeMethod<bool>('hasBackgroundLocation') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
