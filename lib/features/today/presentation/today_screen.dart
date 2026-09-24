import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/durations.dart';
import '../../../core/db/daos/schedule_dao.dart';
import '../../../core/providers.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../domain/departure/departure.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/accent_card.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/haptics.dart';
import '../../../theme/layout.dart';
import '../../../theme/micro_animations.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.g.dart';
import '../../../theme/transitions.dart';
import '../../mascot/application/mascot_voice.dart';
import '../../mascot/mascot_companion.dart';
import '../../mascot/mascot_loader.dart';
import '../../mascot/mascot_error.dart';
import '../../mascot/mascot_view.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shell/presentation/app_shell.dart';
import '../application/today_providers.dart';
import 'widgets/trip_strip.dart';
import 'widgets/countdown_ring.dart';
import 'widgets/day_timeline.dart';
import 'widgets/odometer_minutes.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// La háptica pesada del «sal ya» va una vez por alerta, no una por rebuild.
  bool _urgentHapticFired = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayStateProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => Padding(
            padding: EdgeInsets.symmetric(horizontal: SpaceTokens.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SpaceTokens.l),
                // En lugar de la cabecera, Erizógenes rodando: la espera tiene cara.
                const MascotLoader(inline: true),
                SizedBox(height: SpaceTokens.xl),
                // Skeleton de la card: imita el anillo (104×104) + texto a la derecha.
                Container(
                  padding: EdgeInsets.all(SpaceTokens.cardPadding),
                  decoration: BoxDecoration(
                    color: ColorTokens.surfaceCard.of(Theme.of(context).brightness),
                    borderRadius: BorderRadius.circular(RadiusTokens.card),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bloque que imita el anillo de cuenta regresiva.
                      ShimmerLoading(
                        width: RingTokens.countdownDiameter,
                        height: RingTokens.countdownDiameter,
                        borderRadius: RingTokens.countdownDiameter / 2,
                      ),
                      SizedBox(width: SpaceTokens.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: SpaceTokens.s),
                            ShimmerLoading(
                              width: double.infinity,
                              height: 20,
                              borderRadius: RadiusTokens.control,
                            ),
                            SizedBox(height: SpaceTokens.s),
                            ShimmerLoading(
                              width: 120,
                              height: 16,
                              borderRadius: RadiusTokens.control,
                            ),
                            SizedBox(height: SpaceTokens.s),
                            ShimmerLoading(
                              width: 90,
                              height: 13,
                              borderRadius: RadiusTokens.control,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          error: (e, _) => MascotError(error: e, onRetry: () => ref.invalidate(todayStateProvider)),
          data: (s) {
            _syncUrgentHaptic(s.isUrgent);
            final header = _Header(day: today);
            final cards = _CardStack(state: s);
            // El compañero no compite con la card de «sal ya», que ya trae su
            // propio erizo, ni con el día vacío, donde el erizo es el héroe.
            final companion = s.isEmpty || s.isUrgent
                ? null
                : Padding(
                    padding: EdgeInsets.only(top: SpaceTokens.l),
                    child: const MascotCompanion.compact(),
                  );

            // En tablet, las cards a la izquierda y el día a la derecha: las
            // dos cosas que se consultan caben sin scroll y sin competir.
            if (context.sizeClass.isExpanded && !s.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: SpaceTokens.screenMargin),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: LayoutTokens.todayLeftPaneWidth,
                      child: ListView(
                        children: [
                          SizedBox(height: SpaceTokens.l),
                          header,
                          if (companion != null) companion,
                          SizedBox(height: SpaceTokens.xl),
                          const TripStrip(),
                          cards,
                          SizedBox(height: SpaceTokens.xxl),
                        ],
                      ),
                    ),
                    SizedBox(width: LayoutTokens.paneGap),
                    Expanded(
                      child: ListView(
                        children: [
                          SizedBox(height: SpaceTokens.l),
                          _Card(
                            accent: ColorTokens.surfaceBorder.of(Theme.of(context).brightness),
                            child: DayTimeline(
                              classes: s.classes,
                              highlightId: s.next?.instance.id,
                              gapsAfter: s.gapsAfter,
                              urgent: s.isUrgent,
                            ),
                          ),
                          SizedBox(height: SpaceTokens.xxl),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ContentWidth(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: SpaceTokens.screenMargin),
                children: [
                  SizedBox(height: SpaceTokens.l),
                  header,
                  if (companion != null) companion,
                  SizedBox(height: SpaceTokens.xl),
                  const TripStrip(),
                  cards,
                  if (!s.isEmpty) ...[
                    SizedBox(height: SpaceTokens.xl),
                    DayTimeline(
                      classes: s.classes,
                      highlightId: s.next?.instance.id,
                      gapsAfter: s.gapsAfter,
                      urgent: s.isUrgent,
                    ),
                  ],
                  SizedBox(height: SpaceTokens.xxl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _syncUrgentHaptic(bool urgent) {
    if (!urgent) {
      _urgentHapticFired = false;
      return;
    }
    if (_urgentHapticFired) return;
    _urgentHapticFired = true;
    unawaited(Haptics.enteredUrgent(alreadyFired: false));
  }
}

/// Las cards de arriba: cancelada, próxima o «nada más», según el estado.
///
/// Van dentro de un `StateSwitcher` con una clave que resume el estado: cuando
/// cambia, el bloque saliente se retira hacia arriba y el entrante sube. Sin
/// esto la card salta de «sal en 18 min» a «cancelada» en un fotograma.
class _CardStack extends StatelessWidget {
  const _CardStack({required this.state});
  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final signature =
        s.isEmpty ? 'empty' : 'c${s.cancelled?.instance.id}-n${s.next?.instance.id}-u${s.isUrgent}';

    return StateSwitcher(
      child: KeyedSubtree(
        key: ValueKey(signature),
        child: s.isEmpty
            ? const _EmptyDay()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.cancelled != null) ...[
                    _CancelledCard(state: s),
                    SizedBox(height: SpaceTokens.l),
                  ],
                  if (s.next != null) ...[
                    if (s.cancelled != null) ...[
                      const _Eyebrow(SCancelled.nextLabel),
                      SizedBox(height: SpaceTokens.s),
                    ],
                    _NextClassCard(state: s),
                  ] else
                    const _DoneCard(),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(SToday.title, style: context.type(TypeTokens.titleL)),
              SizedBox(height: SpaceTokens.xs),
              Text(
                // «Martes 1 de septiembre», con la primera en mayúscula.
                capitalize(DateFormat("EEEE d 'de' MMMM", 'es_CO').format(day)),
                style: context.type(
                  TypeTokens.bodyM,
                  color: ColorTokens.textSecondary.of(b),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => openSettings(context),
          tooltip: SSettings.title,
          icon: const Icon(Icons.tune),
          iconSize: IconTokens.sizeXl,
          color: ColorTokens.textSecondary.of(b),
        ),
      ],
    );
  }
}

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Etiqueta pequeña sobre una card, como «Lo siguiente».
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.type(TypeTokens.label, color: context.themed(ColorTokens.textTertiary)),
      );
}

/// El marco de card que comparten las tres cards de Hoy: borde izquierdo con
/// el acento que toque, hairline alrededor y la sombra del contrato.
class _Card extends StatelessWidget {
  const _Card({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return AccentCard(
      accent: accent,
      color: ColorTokens.surfaceCard.of(b),
      shadow: ElevationTokens.card(b),
      child: child,
    );
  }
}

/// La card de próxima clase con su anillo. Los estados del prototipo (normal,
/// sal ya) se distinguen por color y peso, no por layouts distintos.
class _NextClassCard extends ConsumerWidget {
  const _NextClassCard({required this.state});
  final TodayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final plan = state.plan!;
    final next = state.next!;
    final urgent = plan.isUrgent;

    final accent = urgent ? ColorTokens.accentUrgent.of(b) : SubjectPalette.at(next.subject.colorIndex);

    return _Card(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CountdownRing(
                    progress: _progress(plan),
                    urgent: urgent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OdometerMinutes(
                          minutes: plan.minutesUntilLeave,
                          color: urgent ? ColorTokens.accentUrgent.of(b) : ColorTokens.textPrimary.of(b),
                        ),
                        Text(
                          // «min» debajo de los minutos; «h» cuando ya son horas.
                          TimeSpans.compact(plan.minutesUntilLeave).unit,
                          style: context.type(
                            TypeTokens.captionS,
                            color: ColorTokens.textSecondary.of(b),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Erizógenes entra pequeño y rodando en la esquina, solo en urgente.
                  if (urgent)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: MascotView(
                        pose: MascotPose.rodando,
                        size: MascotTokens.sizeUrgentCorner,
                        host: MascotHost.urgentCorner,
                        // Aquí lo único que importa es salir: no se juega.
                        interactive: false,
                      ),
                    ),
                ],
              ),
              SizedBox(width: SpaceTokens.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urgent ? SToday.urgentHeadline : SToday.leaveIn(dur: TimeSpans.minutes(plan.minutesUntilLeave)),
                      style: context.type(
                        TypeTokens.titleM,
                        color: urgent ? ColorTokens.accentUrgent.of(b) : ColorTokens.textPrimary.of(b),
                      ),
                    ),
                    SizedBox(height: SpaceTokens.xs),
                    Text(next.subject.nombre, style: context.type(TypeTokens.titleS)),
                    SizedBox(height: SpaceTokens.s),
                    Text(
                      _roomLine(next.room?.codigo, next.session.horaInicio),
                      style: context.type(
                        TypeTokens.bodyM,
                        color: ColorTokens.textSecondary.of(b),
                      ),
                    ),
                    Text(
                      _etaLine(plan, MinutesOfDay.of(state.now.hour, state.now.minute)),
                      style: context.type(
                        TypeTokens.bodyM,
                        color: ColorTokens.textSecondary.of(b),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: SpaceTokens.m),
          Row(
            children: [
              // PressScaleButton: micro-feedback visual al presionar «Cancelar».
              PressScaleButton(
                child: TextButton(
                  onPressed: () => _mark(ref, next, SessionStatus.canceladaProfe),
                  child: const Text(SToday.cancelAction),
                ),
              ),
              const Spacer(),
              // PressScaleButton: micro-feedback visual al presionar «Ya voy».
              PressScaleButton(
                child: FilledButton(
                  onPressed: () {
                    // Saliendo de casa, «Ya voy» también empieza a medir el
                    // viaje: «Llegué» lo cierra y el trayecto aprende (§47).
                    if (plan.fromHome) {
                      unawaited(ref.read(tripsDaoProvider).start(state.now, plan.mode));
                    }
                    _mark(ref, next, SessionStatus.asistio);
                  },
                  // El tema da a los botones el ancho entero (`Size.fromHeight`);
                  // en una fila con Spacer eso es un ancho infinito y el botón
                  // no se dibuja. Aquí el mínimo es el del área táctil.
                  style: FilledButton.styleFrom(
                    minimumSize: Size.square(ComponentTokens.buttonMinTouchTarget),
                    backgroundColor: urgent ? ColorTokens.accentUrgent.of(b) : null,
                    foregroundColor: urgent ? ColorTokens.textOnUrgent.of(b) : null,
                  ),
                  child: const Text(SToday.onMyWay),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// «Ya voy» marca asistencia y «Cancelar» marca cancelada por el profe. Las
  /// dos son reversibles desde la timeline y desde el historial de la materia.
  Future<void> _mark(WidgetRef ref, DayClass item, SessionStatus status) async {
    unawaited(Haptics.fire(
      status == SessionStatus.canceladaProfe ? 'marcarCancelacion' : 'marcarAsistencia',
    ));
    await ref.read(scheduleDaoProvider).setStatus(item.instance.id, status);
    ref.read(mascotCornerProvider.notifier).react(reactionForStatus(status));
  }

  static String _roomLine(String? code, int startMinutes) {
    final hora = MinutesOfDay(startMinutes).hhmm;
    return code == null ? hora : SToday.roomLine(code: code, hora: hora);
  }

  /// Cómo llegas y a qué hora. Saliendo a tiempo: «35 min en bus · llegas
  /// 7:55, 5 min antes». Pasada la hora de salir, la cuenta es desde ahora:
  /// «Si sales ya, llegas 8:07 · 7 min tarde», la misma de los widgets. Desde
  /// la U, solo el margen. Pasado el inicio, hasta cuándo te dejan entrar.
  static String _etaLine(DeparturePlan plan, MinutesOfDay now) {
    if (now >= plan.classStart) return SToday.lateWithinTolerance(hora: plan.toleranceEnd.hhmm);
    final hora = plan.estimatedArrival.hhmm;
    final margin = plan.arrivalMargin;
    final m = TimeSpans.minutes(margin.abs());
    if (!plan.fromHome) {
      return margin > 0 ? SToday.fromCampus(m: m) : SToday.fromCampusTight;
    }
    if (plan.leavingLate || margin <= 0) {
      if (margin > 0) return SToday.ifLeaveNowEarly(hora: hora, m: m);
      if (margin == 0) return SToday.ifLeaveNowOnTime(hora: hora);
      return SToday.ifLeaveNowLate(hora: hora, m: m);
    }
    final modo = switch (plan.mode) {
      TransportMode.walk => SToday.byWalk,
      TransportMode.bus => SToday.byBus,
      TransportMode.car => SToday.byCar,
    };
    return SToday.walkEta(dur: TimeSpans.minutes(plan.travelMinutes), modo: modo, hora: hora, m: m);
  }

  /// El anillo se vacía a medida que se consume el margen. La ventana sale del
  /// contrato y el cálculo del dominio; aquí solo se conectan.
  static double _progress(DeparturePlan plan) => DeparturePlanner.ringProgress(
        plan,
        windowMinutes: RingTokens.countdownProgressWindowMinutes.round(),
      );
}

/// Pantalla B3: la clase se canceló hace un momento. Se queda a la vista con
/// su «Deshacer» hasta que pase la hora a la que habría terminado.
class _CancelledCard extends ConsumerWidget {
  const _CancelledCard({required this.state});
  final TodayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final item = state.cancelled!;
    final ago = state.minutesSinceCancelled;

    return _Card(
      accent: ColorTokens.surfaceBorder.of(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SCancelled.headline,
            style: context.type(TypeTokens.titleM, color: ColorTokens.textSecondary.of(b)),
          ),
          SizedBox(height: SpaceTokens.xs),
          Text(
            item.subject.nombre,
            style: context.type(TypeTokens.titleS, color: ColorTokens.textSecondary.of(b)),
          ),
          SizedBox(height: SpaceTokens.s),
          Text(
            SCancelled.note,
            style: context.type(TypeTokens.bodyM, color: ColorTokens.textTertiary.of(b)),
          ),
          SizedBox(height: SpaceTokens.s),
          Row(
            children: [
              if (ago != null)
                Text(
                  SCancelled.markedAgo(dur: TimeSpans.minutes(ago)),
                  style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(scheduleDaoProvider).clearStatus(item.instance.id),
                child: const Text(SCancelled.undo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ya no queda nada por delante hoy. Dice qué sigue, si hay algo.
class _DoneCard extends ConsumerWidget {
  const _DoneCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final upcoming = ref.watch(nextAfterTodayProvider).valueOrNull;
    final guard = MotionGuard.of(context);

    return _Card(
      accent: ColorTokens.surfaceBorder.of(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spring-enter: el título entra con scale 0.9→1.0 y easeOutBackBounce,
          // produciendo un efecto elástico suave. Bajo reduced-motion solo fade.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: guard.duration(MotionDurations.ring),
            curve: guard.curve(MotionCurves.easeOutBackBounce),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: guard.reduced ? 1.0 : (0.9 + 0.1 * t),
                child: child,
              ),
            ),
            child: Text(SToday.nothingElse, style: context.type(TypeTokens.titleM)),
          ),
          if (upcoming != null) ...[
            SizedBox(height: SpaceTokens.s),
            _NextUpLine(item: upcoming),
          ],
        ],
      ),
    );
  }
}

/// «Lo próximo: jue 8:00 · Física II». El texto es el del widget 4x4 del
/// prototipo, que es el único que nombra una clase de otro día.
class _NextUpLine extends StatelessWidget {
  const _NextUpLine({required this.item});
  final DayClass item;

  @override
  Widget build(BuildContext context) => Text(
        SWidgets.nextUpDay(
          dia: SWeek.days[item.instance.fecha.weekday - 1],
          hora: MinutesOfDay(item.session.horaInicio).hhmm,
          clase: item.subject.nombre,
        ),
        style: context.type(TypeTokens.bodyM, color: context.themed(ColorTokens.textSecondary)),
      );
}

/// Estado vacío. Es una de las pantallas donde Erizógenes sí puede aparecer.
class _EmptyDay extends ConsumerWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(nextAfterTodayProvider).valueOrNull;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: SpaceTokens.xxxl),
          child: Column(
            children: [
              // Erizógenes duerme, pero si lo tocas se despierta lo justo para
              // decir algo útil: un pendiente que vence, una actividad en riesgo.
              MascotCompanion.hero(
                fallback: SEmptyDay.mascotLine,
                heroPose: MascotPose.dormido,
                // El headline entra con scale 0.95→1.0 complementando el fade del
                // padre. Bajo reduced-motion solo hay fade.
                heroTitle: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: MotionGuard.of(context).duration(MotionDurations.base),
                  curve: MotionGuard.of(context).curve(MotionCurves.easeOutCubic),
                  builder: (context, t, child) => Transform.scale(
                    scale: MotionGuard.of(context).reduced ? 1.0 : (0.95 + 0.05 * t),
                    child: child,
                  ),
                  child: Text(SEmptyDay.headline, style: context.type(TypeTokens.titleM)),
                ),
              ),
              if (upcoming != null) ...[
                SizedBox(height: SpaceTokens.l),
                _NextUpLine(item: upcoming),
              ],
              SizedBox(height: SpaceTokens.xl),
              OutlinedButton(
                onPressed: () => ref.read(shellTabProvider.notifier).state = ShellTab.week,
                child: const Text(SEmptyDay.cta),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
