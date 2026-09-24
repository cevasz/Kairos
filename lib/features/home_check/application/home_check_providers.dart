import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/schedule_dao.dart';
import '../../../core/platform/attendance_channel.dart';
import '../../../core/providers.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/attendance/home_check.dart';
import '../../../l10n/strings.g.dart';
import '../../mascot/application/mascot_voice.dart';

final attendanceChannelProvider = Provider<AttendanceChannel>((ref) => const AttendanceChannel());

/// Las comprobaciones que tocan: una por sesión pendiente cuya tolerancia
/// todavía no acabó. Las canceladas o ya marcadas no se comprueban.
List<HomeCheckItem> homeCheckItems(List<DayClass> classes, DateTime now) => [
      for (final c in classes)
        if (!c.status.isResolved && c.status != SessionStatus.posibleFalta)
          (
            instanceId: c.instance.id,
            at: HomeCheck.checkAt(c.instance.fecha, c.session.horaInicio),
            clase: c.subject.nombre,
          ),
    ].where((i) => i.at.isAfter(now)).toList();

final _checkWindowProvider = StreamProvider<List<DayClass>>((ref) {
  final today = ref.watch(todayProvider);
  // Hoy y mañana: al abrir la app se vuelve a programar, y el rearmado
  // nativo cubre un reinicio entre medias.
  return ref.watch(scheduleDaoProvider).watchBetween(today, today.add(const Duration(days: 1)));
});

/// Mantiene programadas en Android las comprobaciones de «¿sigues en casa?».
/// Apagado, sin casa o sin clases, las cancela.
final homeCheckSyncProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;
  final settings = ref.watch(settingsProvider).valueOrNull;
  final classes = ref.watch(_checkWindowProvider).valueOrNull;
  if (settings == null || classes == null) return;

  final lat = settings.homeLat;
  final lng = settings.homeLng;
  final on = settings.detectarCasa && lat != null && lng != null;
  unawaited(ref.read(attendanceChannelProvider).schedule(
        items: on ? homeCheckItems(classes, DateTime.now()) : const [],
        lat: lat ?? 0,
        lng: lng ?? 0,
        radiusMeters: HomeCheck.radiusMeters,
        maxAccuracyMeters: HomeCheck.maxAccuracyMeters,
        strings: {
          'channel': SHomeCheck.channel,
          // Kotlin pone el nombre de la clase en el hueco.
          'title': SHomeCheck.notifTitle(clase: '%s'),
          'body': SHomeCheck.notifBody,
          'undo': SHomeCheck.undo,
        },
      ));
});

/// Se sube al volver a la app: la vista de permisos lo relee.
final appResumedProvider = StateProvider<int>((ref) => 0);

/// Aplica lo que Android decidió mientras la app estaba cerrada: al abrirla y
/// cada vez que vuelve al frente. Si anotó alguna falta, Erizógenes lo
/// comenta en la esquina.
final homeCheckVerdictsProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;
  Future<void> apply() async {
    final verdicts = await ref.read(attendanceChannelProvider).takeVerdicts();
    if (verdicts.isEmpty) return;
    final dao = ref.read(scheduleDaoProvider);
    var absences = 0;
    for (final (id, verdict) in verdicts) {
      final current = await dao.statusOf(id);
      if (current == null) continue;
      final next = HomeCheck.apply(current: current, verdict: verdict);
      if (next == null || next == current) continue;
      await dao.setStatus(id, next);
      if (next == SessionStatus.falto) absences++;
    }
    if (absences > 0) ref.read(mascotCornerProvider.notifier).react(MascotReaction.absence);
  }

  unawaited(apply());
  final listener = AppLifecycleListener(
    onResume: () {
      unawaited(apply());
      ref.read(appResumedProvider.notifier).state++;
    },
  );
  ref.onDispose(listener.dispose);
});

/// ¿Tiene Kairós la ubicación «todo el tiempo»? Se relee al volver de los
/// ajustes del sistema.
final backgroundLocationProvider = FutureProvider<bool>((ref) {
  ref.watch(appResumedProvider);
  return ref.watch(attendanceChannelProvider).hasBackgroundLocation();
});
