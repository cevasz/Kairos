import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/alarms/alarm_planner.dart';

/// El puente con `MainActivity`: alarmas en el Reloj del teléfono y avisos de
/// evaluación como notificaciones de Kairós. Fuera de Android nada de esto
/// existe y todo devuelve `false`.
class AlarmChannel {
  const AlarmChannel();

  static const _channel = MethodChannel('kairos/alarms');

  /// El Reloj procesa cada intent en su propia actividad. Disparar varios a
  /// la vez hace que alguno se pierda en algunos teléfonos; con esta pausa
  /// entre uno y otro llegan todos.
  static const Duration _gap = Duration(milliseconds: 350);

  Future<bool> canSetAlarms() async => await _call<bool>('canSetAlarms') ?? false;

  /// Crea las alarmas una por una. Devuelve cuántas aceptó el Reloj.
  Future<int> setAlarms(List<(PlannedAlarm, String)> alarms) async {
    var ok = 0;
    for (final (alarm, label) in alarms) {
      final accepted = await _call<bool>('setAlarm', {
        'hour': alarm.hour,
        'minute': alarm.minuteOfHour,
        'days': alarm.weekdays,
        'label': label,
      });
      if (accepted ?? false) ok++;
      await Future<void>.delayed(_gap);
    }
    return ok;
  }

  Future<bool> showAlarms() async => await _call<bool>('showAlarms') ?? false;

  /// Pide el permiso de notificaciones (Android 13+). `true` si ya lo tenía.
  Future<bool> requestNotifications() async => await _call<bool>('requestNotifications') ?? false;

  /// Reemplaza todos los avisos programados por estos.
  Future<void> scheduleReminders({
    required String channelName,
    required List<({int id, DateTime at, String title, String body})> items,
  }) =>
      _call<bool>('scheduleReminders', {
        'channel': channelName,
        'items': [
          for (final i in items)
            {'id': i.id, 'at': i.at.millisecondsSinceEpoch, 'title': i.title, 'body': i.body},
        ],
      });

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
