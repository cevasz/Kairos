import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/alarm_channel.dart';
import '../../../core/providers.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../domain/alarms/alarm_planner.dart';
import '../../../l10n/strings.g.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../travel/application/travel_providers.dart';

final alarmChannelProvider = Provider<AlarmChannel>((ref) => const AlarmChannel());

/// Minutos entre inicio de clase y hora de salir: trayecto + buffer, igual
/// que Hoy y los widgets. El trayecto es el general del modelo (§47): una
/// alarma semanal no cambia de hora según el día.
int leaveOffsetOf(TravelModel model, int buffer) => model.overall.minutes + buffer;

/// Qué alarmas saldrían hoy con el horario y los ajustes actuales.
Future<List<(PlannedAlarm, String)>> plannedClockAlarms(Ref ref) async {
  final settings = await ref.read(settingsDaoProvider).get();
  final sessions = await ref.read(scheduleDaoProvider).watchLiveSessions().first;
  final alarms = AlarmPlanner.weekly(
    classes: [
      for (final (session, subject, _) in sessions)
        WeeklyClass(
          subject: subject.nombre,
          weekday: session.diaSemana,
          start: session.horaInicio,
          end: session.horaFin,
        ),
    ],
    leaveOffset: leaveOffsetOf(
      TravelModel.from(settings, await ref.read(recentTripsProvider.future), ref.read(todayProvider)),
      settings.bufferMinutos,
    ),
    wake: settings.alarmaDespertar,
    wakeMinutes: settings.alarmaDespertarMin,
    // Sin `travelMinutes`: una alarma semanal no sabe si ese día fuiste a la
    // clase anterior, así que hay «Salir» para todas. Perder un aviso por
    // saltarte la primera clase sería peor que uno de más.
    leave: settings.alarmaSalir,
  );
  return [
    for (final a in alarms)
      (a, a.kind == AlarmKind.wake ? SAlarms.wakeLabel : SAlarms.leaveLabel(clase: a.subject!)),
  ];
}

/// Crea las alarmas en el Reloj. Devuelve cuántas creó, o null si el teléfono
/// no tiene una app de reloj que las acepte.
final createClockAlarmsProvider = Provider<Future<int?> Function()>((ref) {
  return () async {
    final channel = ref.read(alarmChannelProvider);
    if (!await channel.canSetAlarms()) return null;
    return channel.setAlarms(await plannedClockAlarms(ref));
  };
});

/// Mantiene programados los avisos de la víspera de cada pendiente con
/// fecha. Se activa con un `ref.watch` en la raíz de la app, igual que los
/// widgets. El ajuste sigue en la columna `alarmaEvaluaciones` (herencia).
final pendingRemindersSyncProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;
  final settings = ref.watch(settingsProvider).valueOrNull;
  final pending = ref.watch(pendingProvider).valueOrNull;
  if (settings == null || pending == null) return;

  final dated = settings.alarmaEvaluaciones
      ? [
          for (final p in pending)
            if (p.fecha != null)
              DatedPending(
                id: p.task.id,
                name: p.titulo,
                subject: p.subject.nombre,
                date: p.fecha!,
              ),
        ]
      : const <DatedPending>[];

  final reminders = AlarmPlanner.pendingReminders(
    pending: dated,
    reminderMinute: settings.avisoEvaluacionMin,
    now: DateTime.now(),
  );
  unawaited(ref.read(alarmChannelProvider).scheduleReminders(
        channelName: SAlarms.pending,
        items: [
          for (final r in reminders)
            (
              id: r.pending.id,
              at: r.at,
              title: SAlarms.pendingTitle(pendiente: r.pending.name),
              body: SAlarms.pendingBody(actividad: r.pending.subject),
            ),
        ],
      ));
});

/// «20:00», para el ajuste de la hora del aviso.
String reminderLabel(int minute) => MinutesOfDay(minute).hhmm;
