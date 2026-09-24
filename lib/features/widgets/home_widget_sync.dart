import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../core/db/daos/schedule_dao.dart';
import '../../core/providers.dart';
import '../../core/time/minutes_of_day.dart';
import '../../domain/attendance/attendance.dart';
import '../../domain/departure/departure.dart';
import '../../l10n/strings.g.dart';
import '../../theme/tokens.g.dart';
import '../mascot/mascot_view.dart';
import '../tasks/application/tasks_providers.dart';
import '../travel/application/travel_providers.dart';

/// Nombres de las clases Kotlin de los dos widgets.
const List<String> kHomeWidgetProviders = ['NextClassWidgetProvider', 'TodayWidgetProvider', 'PendingWidgetProvider'];

/// El paquete de las clases Kotlin (el `namespace` de Gradle). No es el id de
/// la app: «Kairós Dev» se instala como `com.kairos.app.dev` pero sus
/// widgets siguen en este paquete, así que se nombran completos (§51).
const String kWidgetPackage = 'com.kairos.app';

/// Clave de SharedPreferences que leen los widgets.
const String kHomeWidgetDataKey = 'kairos_upcoming';

/// Cuántos pendientes se les pasan: el widget más grande enseña ocho.
const int kHomeWidgetPending = 12;

/// Poses de Erizógenes que usan los widgets, pintadas una vez por arranque
/// en claro y en oscuro. El widget escoge según el tema del sistema.
const List<MascotPose> kHomeWidgetPoses = [
  MascotPose.reposo,
  MascotPose.rodando,
  MascotPose.dormido,
  MascotPose.satisfecho,
];

/// Días por delante que se les pasan a los widgets. Con una semana, el widget
/// sabe cuál es la próxima clase aunque no abras la app en días.
const int kHomeWidgetDays = 8;

final _upcomingProvider = StreamProvider<List<DayClass>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(scheduleDaoProvider)
      .watchBetween(today, today.add(const Duration(days: kHomeWidgetDays - 1)));
});

/// Mantiene los widgets de la pantalla de inicio al día.
///
/// Los widgets son vistas nativas: no pueden preguntarle nada a Drift. Así que
/// cada vez que cambian las clases de la semana o los ajustes de salida, se
/// les deja un JSON con las clases ya resueltas (nombre, salón, color, hora de
/// salir) y se programan actualizaciones para los momentos en que su
/// contenido cambia solo: la hora de salir, el inicio y el fin de cada clase.
///
/// Se activa con un `ref.watch` en la raíz de la app.
final homeWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;
  Timer? debounce;
  void schedule() {
    debounce?.cancel();
    // Marcar tres clases seguidas no tiene por qué escribir tres veces.
    debounce = Timer(const Duration(milliseconds: 600), () => unawaited(_push(ref)));
  }

  ref.listen(_upcomingProvider, (_, __) => schedule(), fireImmediately: true);
  ref.listen(settingsProvider, (_, __) => schedule());
  ref.listen(recentTripsProvider, (_, __) => schedule());
  ref.listen(pendingProvider, (_, __) => schedule());
  ref.onDispose(() => debounce?.cancel());
});

Future<void> _push(Ref ref) async {
  final classes = ref.read(_upcomingProvider).valueOrNull;
  if (classes == null) return;
  final settings = ref.read(settingsProvider).valueOrNull;
  final buffer = settings?.bufferMinutos ?? DeparturePlanner.defaultBufferMinutes;
  final model = ref.read(travelModelProvider);
  final travel = model.overall.minutes;
  // Cada clase con su trayecto: el aprendido de su día y su franja (§47).
  int travelOf(DayClass c) => model
      .forClass(
        weekday: c.instance.fecha.weekday,
        classStart: MinutesOfDay(c.session.horaInicio),
        buffer: buffer,
      )
      .minutes;
  final today = ref.read(todayProvider);
  final pending = ref.read(pendingProvider).valueOrNull ?? const [];

  final dateKey = DateFormat('yyyy-MM-dd');
  final shortDay = DateFormat('EEE d MMM', 'es_CO');
  String pendingDay(DateTime? f) {
    if (f == null) return '';
    final d = DateTime(f.year, f.month, f.day);
    if (d == today) return SWidgets.pendingToday;
    if (d == today.add(const Duration(days: 1))) return SWidgets.pendingTomorrow;
    return shortDay.format(d);
  }
  // El trayecto de cada clase: sin trayecto solo si la anterior del día está
  // marcada como asistida y el hueco no da para volver a casa (la misma
  // regla que Hoy). Sin marca se asume que sales de casa.
  final tripOf = <int, int>{};
  final lastEndByDay = <DateTime, int>{};
  for (final c in classes) {
    final trip = travelOf(c);
    if (c.status != SessionStatus.asistio && c.status != SessionStatus.pendiente) {
      tripOf[c.instance.id] = trip;
      continue;
    }
    final day = c.instance.fecha;
    final prev = lastEndByDay[day];
    final fromHome = DeparturePlanner.leavesFromHome(
      previousEnd: prev == null ? null : MinutesOfDay(prev),
      start: MinutesOfDay(c.session.horaInicio),
      travelMinutes: trip,
    );
    tripOf[c.instance.id] = fromHome ? trip : 0;
    if (c.status == SessionStatus.asistio) {
      lastEndByDay[day] = c.session.horaFin;
    } else {
      lastEndByDay.remove(day);
    }
  }
  int leaveOf(DayClass c) => MinutesOfDay(c.session.horaInicio).minus((tripOf[c.instance.id] ?? travel) + buffer).raw;

  final items = [
    for (final c in classes)
      {
        'date': dateKey.format(c.instance.fecha),
        'day': SWeek.days[c.instance.fecha.weekday - 1],
        'start': c.session.horaInicio,
        'end': c.session.horaFin,
        'leave': leaveOf(c),
        'travel': tripOf[c.instance.id] ?? travel,
        'startLabel': MinutesOfDay(c.session.horaInicio).hhmm,
        'endLabel': MinutesOfDay(c.session.horaFin).hhmm,
        'leaveLabel': MinutesOfDay(leaveOf(c)).hhmm,
        'name': c.subject.nombre,
        'room': c.room?.codigo,
        'color': c.subject.colorIndex,
        'status': switch (c.status) {
          SessionStatus.canceladaProfe => 'cancelled',
          SessionStatus.asistio => 'attended',
          // Una falta (marcada o detectada) no se persigue, igual que en Hoy.
          SessionStatus.falto || SessionStatus.justificada || SessionStatus.posibleFalta => 'absent',
          SessionStatus.pendiente => 'pending',
        },
      },
  ];

  final payload = jsonEncode({
    'today': dateKey.format(today),
    'todayHeader': SWidgets.todayHeader(
      fecha: DateFormat("EEE d 'de' MMM", 'es_CO').format(today),
    ),
    'strings': {
      'urgent': SWidgets.urgent,
      'leaveLabel': SWidgets.leaveLabel,
      'countdown': SWidgets.countdown,
      'noClassesToday': SWidgets.noClassesToday,
      'noMore': SWidgets.noMore,
      'cancelled': SWidgets.cancelled,
      'attended': SWidgets.attendedShort,
      'more': SWidgets.more(n: '%d'),
      // «Lo próximo: jue 8:00 · Física II», con huecos para Kotlin.
      'nextUpDay': SWidgets.nextUpDay(dia: '%1\$s', hora: '%2\$s', clase: '%3\$s'),
    },
    'classes': items,
    // Llegada estimada: el widget la recalcula con la hora real si ya pasó
    // la de salir («si sales ya, llegas 8:07 · 7 min tarde»).
    'travel': travel,
    'buffer': buffer,
    'tolerance': DeparturePlanner.lateToleranceMinutes,
    'strings2': {
      'tomorrow': SWidgets.tomorrow,
      'onDay': SWidgets.onDay(dia: '%s'),
      'arriveAt': SWidgets.arriveAt(hora: '%s'),
      'arriveEarly': SWidgets.arriveEarly(n: '%d'),
      'arriveOnTime': SWidgets.arriveOnTime,
      'arriveLate': SWidgets.arriveLate(n: '%d'),
      'ifLeaveNow': SWidgets.ifLeaveNow,
      'afterThis': SWidgets.afterThis(clase: '%1\$s', hora: '%2\$s'),
      'pendingHeader': SWidgets.pendingHeader,
      'pendingNone': SWidgets.pendingNone,
      'pendingCount': SWidgets.pendingCount(n: '%d'),
    },
    // Lo que dice Erizógenes en los widgets grandes, por situación. Kotlin
    // escoge una variante según la hora para que no repita siempre la misma.
    'quips': {
      'normal': SMascotVoice.widgetNormal,
      'urgent': SMascotVoice.widgetUrgent,
      'later': SMascotVoice.widgetLater,
      'pendingEmpty': SMascotVoice.widgetPendingEmpty,
    },
    'pending': [
      for (final item in pending.take(kHomeWidgetPending))
        {
          'subject': item.subject.nombre,
          'color': item.subject.colorIndex,
          'title': item.titulo,
          'when': pendingDay(item.fecha),
          'date': item.fecha == null ? null : dateKey.format(item.fecha!),
        },
    ],
    'pendingTotal': pending.length,
  });

  try {
    await _renderMascots();
    await HomeWidget.saveWidgetData<String>(kHomeWidgetDataKey, payload);
    for (final name in kHomeWidgetProviders) {
      await HomeWidget.updateWidget(qualifiedAndroidName: '$kWidgetPackage.$name');
    }
    // El widget cambia solo al llegar la hora de salir, al empezar cada clase,
    // al acabar su tolerancia (ahí pasa a la siguiente), al terminar, y a
    // medianoche.
    final now = DateTime.now();
    final times = <DateTime>{
      DateTime(today.year, today.month, today.day + 1),
      for (final c in classes)
        if (!c.instance.fecha.isAfter(today.add(const Duration(days: 1))))
          for (final m in [
            MinutesOfDay(c.session.horaInicio).minus(travel + buffer).raw,
            c.session.horaInicio,
            c.session.horaInicio + DeparturePlanner.lateToleranceMinutes,
            c.session.horaFin,
          ])
            DateTime(c.instance.fecha.year, c.instance.fecha.month, c.instance.fecha.day)
                .add(Duration(minutes: m)),
    }.where((t) => t.isAfter(now)).toList()
      ..sort();
    // Entre la hora de salir y el inicio de cada clase de hoy, «Próxima clase»
    // se refresca cada minuto: ahí la llegada es «si sales ya, llegas 8:07» y
    // cambia con el reloj. home_widget arma una sola alarma a la vez, así que
    // esta lista no cuesta alarmas de más.
    final perMinute = <DateTime>{
      ...times,
      for (final c in classes)
        if (c.instance.fecha == today)
          for (var m = MinutesOfDay(c.session.horaInicio).minus(travel + buffer).raw;
              m <= c.session.horaInicio + DeparturePlanner.lateToleranceMinutes;
              m++)
            DateTime(today.year, today.month, today.day).add(Duration(minutes: m)),
    }.where((t) => t.isAfter(now)).toList()
      ..sort();
    for (final name in kHomeWidgetProviders) {
      await HomeWidget.scheduleWidgetUpdates(
        name == 'NextClassWidgetProvider' ? perMinute : times,
        qualifiedAndroidName: '$kWidgetPackage.$name',
      );
    }
  } on Object {
    // Sin widgets puestos, o el lanzador no los soporta: no es un error de la
    // app y no hay nada que decirle a la persona.
  }
}

/// Pinta las poses de los widgets una vez por arranque de la app. Cada imagen
/// queda en disco y su ruta en `mascot_<pose>_<dark|light>`, que es lo que
/// lee Kotlin.
bool _mascotsRendered = false;

Future<void> _renderMascots() async {
  if (_mascotsRendered) return;
  final size = MascotTokens.sizeWidgetWide;
  for (final pose in kHomeWidgetPoses) {
    for (final b in Brightness.values) {
      await HomeWidget.renderFlutterWidget(
        MascotStill(pose: pose, size: size, brightness: b),
        key: 'mascot_${pose.name}_${b == Brightness.dark ? 'dark' : 'light'}',
        logicalSize: Size.square(size),
      );
    }
  }
  _mascotsRendered = true;
}
