import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/db/database.dart';
import '../../../core/format/durations.dart';
import '../../../core/providers.dart';
import '../../../domain/alarms/alarm_planner.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/departure/departure.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/haptics.dart';
import '../../../theme/layout.dart';
import '../../../theme/tokens.g.dart';
import '../../alarms/application/alarms_controller.dart';
import '../../home_check/application/home_check_providers.dart';
import '../../mascot/application/mascot_voice.dart';
import '../../mascot/mascot_error.dart';
import '../../mascot/mascot_loader.dart';
import '../../travel/application/travel_providers.dart';
import '../../../domain/departure/travel_estimator.dart';
import '../../updates/application/update_providers.dart';
import '../../updates/presentation/update_sheet.dart';

/// Ajustes. Se guarda al tocar: no hay botón de guardar porque ningún ajuste
/// es destructivo y todos se ven en vivo en Hoy.
///
/// Sin mascota, salvo si la carga falla (`error de carga`): «ajustes» es una
/// pantalla de trabajo.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(SSettings.title)),
      body: ContentWidth(
        child: settings.when(
          loading: () => const MascotLoader(),
          error: (e, _) => MascotError(error: e, onRetry: () => ref.invalidate(settingsProvider)),
          data: (s) => _Loaded(settings: s),
        ),
      ),
    );
  }
}

Future<void> openSettings(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.settings});

  final UserSetting settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(settingsDaoProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpaceTokens.screenMargin,
        SpaceTokens.m,
        SpaceTokens.screenMargin,
        SpaceTokens.xxxl,
      ),
      children: [
        const _SectionLabel(SSettings.sectionDepartures),
        _Card(
          children: [
            _Row(
              title: SSettings.buffer,
              subtitle: SSettings.bufferHint,
              trailing: Text(
                SSettings.bufferUnit(n: settings.bufferMinutos),
                style: context.type(TypeTokens.titleS),
              ),
            ),
            Slider(
              value: settings.bufferMinutos.toDouble(),
              min: DeparturePlanner.minBufferMinutes.toDouble(),
              max: DeparturePlanner.maxBufferMinutes.toDouble(),
              divisions: DeparturePlanner.maxBufferMinutes -
                  DeparturePlanner.minBufferMinutes,
              onChanged: (v) => dao.setBuffer(v.round()),
            ),
            SizedBox(height: SpaceTokens.s),
            _Row(title: SSettings.transportDefault),
            SizedBox(height: SpaceTokens.s),
            SegmentedButton<TransportMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TransportMode.walk,
                  label: Text(STransport.walk),
                  icon: Icon(Icons.directions_walk),
                ),
                ButtonSegment(
                  value: TransportMode.bus,
                  label: Text(STransport.bus),
                  icon: Icon(Icons.directions_bus_outlined),
                ),
                ButtonSegment(
                  value: TransportMode.car,
                  label: Text(STransport.car),
                  icon: Icon(Icons.directions_car_outlined),
                ),
              ],
              selected: {settings.modoTransporte},
              onSelectionChanged: (set) {
                Haptics.fire('cambioTransporte');
                dao.setTransport(set.single);
              },
            ),
            SizedBox(height: SpaceTokens.l),
            // El trayecto: el número de partida (el que fijaste, la ruta o la
            // tabla) corregido con los viajes medidos (§47).
            _TravelBlock(settings: settings),
          ],
        ),
        SizedBox(height: SpaceTokens.xl),
        const _SectionLabel(SSettings.sectionSubjects),
        _Card(
          children: [
            _Row(
              title: SSettings.absenceLimitDefault,
              subtitle: SSettings.absenceLimitHint,
              trailing: _Stepper(
                value: settings.limiteFaltasPorDefecto,
                min: AttendanceCounter.minLimit,
                max: AttendanceCounter.maxLimit,
                onChanged: dao.setDefaultAbsenceLimit,
              ),
            ),
          ],
        ),
        SizedBox(height: SpaceTokens.xl),
        const _SectionLabel(SAlarms.section),
        _AlarmsCard(settings: settings),
        SizedBox(height: SpaceTokens.xl),
        const _SectionLabel(SHomeCheck.section),
        _HomeCheckCard(settings: settings),
        SizedBox(height: SpaceTokens.xl),
        const _SectionLabel(SUpdates.section),
        const _UpdatesCard(),
        SizedBox(height: SpaceTokens.xl),
        const _SectionLabel(SSettings.sectionAppearance),
        _Card(
          children: [
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system, label: Text(SSettings.themeAuto)),
                ButtonSegment(
                    value: ThemeMode.light, label: Text(SSettings.themeLight)),
                ButtonSegment(
                    value: ThemeMode.dark, label: Text(SSettings.themeDark)),
              ],
              selected: {
                ThemeMode
                    .values[settings.tema.clamp(0, ThemeMode.values.length - 1)]
              },
              onSelectionChanged: (set) => dao.setThemeIndex(set.single.index),
            ),
            SizedBox(height: SpaceTokens.l),
            _Row(
              title: SSettings.mascotCorner,
              subtitle: SSettings.mascotCornerHint,
              trailing: Switch(value: settings.mascotaEsquina, onChanged: dao.setMascotCorner),
            ),
          ],
        ),
      ],
    );
  }
}

/// Alarmas en el Reloj del teléfono y avisos de la víspera de pendientes.
///
/// Las del Reloj se crean al tocar el botón, no solas: el Reloj no deja que
/// otra app borre alarmas, así que crearlas a espaldas de la persona cada vez
/// que cambia el horario llenaría el Reloj de copias.
class _AlarmsCard extends ConsumerStatefulWidget {
  const _AlarmsCard({required this.settings});

  final UserSetting settings;

  @override
  ConsumerState<_AlarmsCard> createState() => _AlarmsCardState();
}

class _AlarmsCardState extends ConsumerState<_AlarmsCard> {
  bool _busy = false;

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final created = await ref.read(createClockAlarmsProvider)();
    if (!mounted) return;
    setState(() => _busy = false);
    final text = switch (created) {
      null => SAlarms.failed,
      0 => SAlarms.none,
      final n => SAlarms.created(n: n),
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
    if (created != null && created > 0) {
      ref.read(mascotCornerProvider.notifier).react(MascotReaction.alarms);
    }
  }

  Future<void> _togglePendingReminders(bool on) async {
    await ref.read(settingsDaoProvider).setEvalAlarm(on);
    if (on) await ref.read(alarmChannelProvider).requestNotifications();
  }

  Future<void> _pickReminderTime() async {
    final m = widget.settings.avisoEvaluacionMin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) {
      await ref.read(settingsDaoProvider).setEvalReminderMinute(picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final dao = ref.read(settingsDaoProvider);
    final b = Theme.of(context).brightness;

    return _Card(
      children: [
        Text(SAlarms.intro, style: context.type(TypeTokens.captionS, color: ColorTokens.textSecondary.of(b))),
        SizedBox(height: SpaceTokens.m),
        _Row(
          title: SAlarms.wake,
          subtitle: SAlarms.wakeDesc(dur: TimeSpans.minutes(s.alarmaDespertarMin)),
          trailing: Switch(value: s.alarmaDespertar, onChanged: dao.setWakeAlarm),
        ),
        if (s.alarmaDespertar)
          Slider(
            value: s.alarmaDespertarMin.toDouble(),
            min: AlarmPlanner.minWakeMinutes.toDouble(),
            max: AlarmPlanner.maxWakeMinutes.toDouble(),
            divisions: (AlarmPlanner.maxWakeMinutes - AlarmPlanner.minWakeMinutes) ~/ AlarmPlanner.wakeStep,
            label: SAlarms.minutes(dur: TimeSpans.minutes(s.alarmaDespertarMin)),
            onChanged: (v) => dao.setWakeMinutes(v.round()),
          ),
        SizedBox(height: SpaceTokens.s),
        _Row(
          title: SAlarms.leave,
          subtitle: SAlarms.leaveDesc,
          trailing: Switch(value: s.alarmaSalir, onChanged: dao.setLeaveAlarm),
        ),
        SizedBox(height: SpaceTokens.m),
        _Row(
          title: SAlarms.pending,
          subtitle: SAlarms.pendingDesc(hora: reminderLabel(s.avisoEvaluacionMin)),
          trailing: Switch(value: s.alarmaEvaluaciones, onChanged: _togglePendingReminders),
        ),
        if (s.alarmaEvaluaciones)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickReminderTime,
              icon: const Icon(Icons.schedule),
              label: Text('${SAlarms.pendingHourLabel}: ${reminderLabel(s.avisoEvaluacionMin)}'),
            ),
          ),
        SizedBox(height: SpaceTokens.l),
        FilledButton.icon(
          onPressed: _busy || !(s.alarmaDespertar || s.alarmaSalir) ? null : _create,
          icon: const Icon(Icons.alarm_add),
          label: const Text(SAlarms.create),
        ),
        SizedBox(height: SpaceTokens.s),
        OutlinedButton.icon(
          onPressed: ref.read(alarmChannelProvider).showAlarms,
          icon: const Icon(Icons.alarm),
          label: const Text(SAlarms.openClock),
        ),
        SizedBox(height: SpaceTokens.s),
        Text(SAlarms.cantDelete, style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b))),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: SpaceTokens.xs, bottom: SpaceTokens.s),
        child: Text(
          text.toUpperCase(),
          style: context.type(TypeTokens.label,
              color: context.themed(ColorTokens.textTertiary)),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(SpaceTokens.cardPadding),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceCard.of(b),
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        border: Border.all(
            color: ColorTokens.surfaceBorder.of(b),
            width: BorderTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.type(TypeTokens.bodyM)),
              if (subtitle != null) ...[
                SizedBox(height: SpaceTokens.xs / 2),
                Text(
                  subtitle!,
                  style: context.type(
                    TypeTokens.captionS,
                    color: ColorTokens.textTertiary.of(b),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: SpaceTokens.m),
          trailing!,
        ],
      ],
    );
  }
}

/// Menos / número / más. Para un entero pequeño es más directo que un campo
/// de texto con teclado: se ve el valor y se toca una vez por paso.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
          iconSize: IconTokens.sizeL,
        ),
        SizedBox(
          width: IconTokens.minTouchTarget,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: context.type(TypeTokens.titleS,
                color: ColorTokens.textPrimary.of(b)),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
          iconSize: IconTokens.sizeL,
        ),
      ],
    );
  }
}

/// Qué versión hay instalada, si hay una nueva y el botón para buscarla o
/// instalarla. Buscar vuelve a leer el `version.json` del último Release.
class _UpdatesCard extends ConsumerWidget {
  const _UpdatesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(updateCheckProvider);
    final installed = check.valueOrNull?.installed;
    final available = check.valueOrNull?.available;

    final subtitle = switch (check) {
      AsyncLoading() => SUpdates.checking,
      AsyncData(:final value) when value.available != null =>
        SUpdates.available(version: value.available!.versionName),
      AsyncData(:final value) when value.reachable => SUpdates.upToDate,
      _ => SUpdates.unreachable,
    };

    return _Card(
      children: [
        _Row(
          title: installed == null ? SUpdates.section : SUpdates.current(version: installed.$2),
          subtitle: subtitle,
          trailing: available != null
              ? FilledButton(
                  onPressed: () => openUpdateSheet(context, available),
                  child: const Text(SUpdates.update),
                )
              : TextButton(
                  onPressed: check.isLoading ? null : () => ref.invalidate(updateCheckProvider),
                  child: const Text(SUpdates.check),
                ),
        ),
      ],
    );
  }
}

/// Dónde está la casa y si Kairós marca «Saltado» cuando sigues en ella
/// pasada la tolerancia. La ubicación de casa solo vive en el teléfono.
class _HomeCheckCard extends ConsumerStatefulWidget {
  const _HomeCheckCard({required this.settings});

  final UserSetting settings;

  @override
  ConsumerState<_HomeCheckCard> createState() => _HomeCheckCardState();
}

class _HomeCheckCardState extends ConsumerState<_HomeCheckCard> {
  bool _locating = false;

  void _say(String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _setHome() async {
    setState(() => _locating = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        _say(SHomeCheck.locationFailed);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await ref.read(settingsDaoProvider).setHome(pos.latitude, pos.longitude);
    } on Object {
      _say(SHomeCheck.locationFailed);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _toggle(bool on) async {
    final dao = ref.read(settingsDaoProvider);
    if (!on) {
      await dao.setDetectHome(false);
      return;
    }
    if (widget.settings.homeLat == null) {
      _say(SHomeCheck.needHome);
      return;
    }
    await dao.setDetectHome(true);
    // La notificación de «Falta anotada» necesita permiso en Android 13+.
    await ref.read(alarmChannelProvider).requestNotifications();
    // Android 11+ no pregunta «todo el tiempo» en un diálogo: hay que ir a
    // los permisos de la app. Primero se pide el de primer plano.
    final p = await Geolocator.requestPermission();
    if (p != LocationPermission.always) ref.invalidate(backgroundLocationProvider);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final hasHome = s.homeLat != null && s.homeLng != null;
    final always = ref.watch(backgroundLocationProvider).valueOrNull ?? false;
    final b = Theme.of(context).brightness;

    return _Card(
      children: [
        _Row(
          title: SHomeCheck.home,
          subtitle: _locating ? SHomeCheck.locating : (hasHome ? SHomeCheck.homeSet : SHomeCheck.homeUnset),
          trailing: TextButton(
            onPressed: _locating ? null : _setHome,
            child: const Text(SHomeCheck.setHome),
          ),
        ),
        SizedBox(height: SpaceTokens.m),
        _Row(
          title: SHomeCheck.detect,
          subtitle: SHomeCheck.detectHint,
          trailing: Switch(value: s.detectarCasa, onChanged: _toggle),
        ),
        if (s.detectarCasa && !always) ...[
          SizedBox(height: SpaceTokens.s),
          Text(
            SHomeCheck.needAlways,
            style: context.type(TypeTokens.captionS, color: ColorTokens.accentAttention.of(b)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: Geolocator.openAppSettings,
              child: const Text(SHomeCheck.openSettings),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tiempo de trayecto: cuánto se usa y de dónde sale, el control para fijarlo
/// a mano, aprender de los viajes y la ruta por calles (§47).
class _TravelBlock extends ConsumerStatefulWidget {
  const _TravelBlock({required this.settings});
  final UserSetting settings;

  @override
  ConsumerState<_TravelBlock> createState() => _TravelBlockState();
}

class _TravelBlockState extends ConsumerState<_TravelBlock> {
  bool _routing = false;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final dao = ref.read(settingsDaoProvider);
    final model = ref.watch(travelModelProvider);
    final estimate = model.overall;
    final source = switch (estimate.source) {
      TravelSource.table => SSettings.travelFromTable,
      TravelSource.route => SSettings.travelFromRoute,
      TravelSource.custom => SSettings.travelFromCustom,
      TravelSource.learned => SSettings.travelLearned(
          n: estimate.samples,
          p: TimeSpans.minutes(estimate.prior),
        ),
    };
    String minutesOrDash(int? m) => m == null ? SSettings.routeUnknown : TimeSpans.minutes(m);
    final hasRoute = settings.rutaPieMin != null || settings.rutaCarroMin != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          title: SSettings.travel,
          subtitle: source,
          trailing: Text(TimeSpans.minutes(estimate.minutes), style: context.type(TypeTokens.titleS)),
        ),
        // El control fija el número de partida; lo aprendido se suma encima.
        Slider(
          value: model.prior
              .clamp(DeparturePlanner.minTravelMinutes, DeparturePlanner.maxTravelMinutes)
              .toDouble(),
          min: DeparturePlanner.minTravelMinutes.toDouble(),
          max: DeparturePlanner.maxTravelMinutes.toDouble(),
          divisions: DeparturePlanner.maxTravelMinutes - DeparturePlanner.minTravelMinutes,
          label: TimeSpans.minutes(model.prior),
          onChanged: (v) => dao.setTravelMinutes(v.round()),
        ),
        if (settings.trayectoMinutos != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => dao.setTravelMinutes(null),
              child: const Text(SSettings.travelUseEstimate),
            ),
          ),
        SizedBox(height: SpaceTokens.s),
        _Row(
          title: SSettings.route,
          subtitle: hasRoute
              ? SSettings.routeResult(
                  walk: minutesOrDash(settings.rutaPieMin),
                  car: minutesOrDash(settings.rutaCarroMin),
                )
              : SSettings.routeHint,
          trailing: _routing
              ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  tooltip: SSettings.route,
                  onPressed: _calculate,
                  icon: const Icon(Icons.route_outlined),
                ),
        ),
        SizedBox(height: SpaceTokens.s),
        _Row(
          title: SSettings.travelLearn,
          subtitle: SSettings.travelLearnHint,
          trailing: Switch(value: settings.aprenderTrayecto, onChanged: dao.setLearnTravel),
        ),
        if (model.trips.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(tripsDaoProvider).forgetAll();
                messenger.showSnackBar(const SnackBar(content: Text(SSettings.travelForgotten)));
              },
              child: const Text(SSettings.travelForget),
            ),
          ),
      ],
    );
  }

  Future<void> _calculate() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _routing = true);
    final result = await ref.read(calculateRouteProvider)();
    if (!mounted) return;
    setState(() => _routing = false);
    messenger.showSnackBar(SnackBar(
      content: Text(switch (result) {
        RouteCalcResult.ok => SSettings.routeDone,
        RouteCalcResult.noHome => SSettings.routeNoHome,
        RouteCalcResult.noCampus => SSettings.routeNoCampus,
        RouteCalcResult.offline => SSettings.routeOffline,
      }),
    ));
  }
}
