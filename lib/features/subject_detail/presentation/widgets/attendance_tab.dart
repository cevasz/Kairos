import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/database.dart';
import '../../../../core/providers.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../domain/attendance/attendance.dart';
import '../../../../domain/streaks/streaks.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/cascade.dart';
import '../../../../theme/haptics.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/strike_through.dart';
import '../../../../theme/tokens.g.dart';
import '../../../mascot/application/mascot_voice.dart';
import '../../application/subject_detail_providers.dart';
import 'absence_ring.dart';
import 'check_mark.dart';

/// Pestaña Historial: el anillo de saltos, la racha y las sesiones pasadas.
///
/// El número que manda es «cuántos te quedan», no «cuántos llevas»: es la
/// pregunta que la persona se hace de verdad.
class AttendanceTab extends ConsumerWidget {
  const AttendanceTab({required this.state, super.key});

  final SubjectDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);
    final tally = state.tally;
    final semaphore = SemaphoreTokens.color[tally.state]!.of(b);
    final badge = SemaphoreTokens.badge[tally.state];

    // La hora la reparte el reloj de la app, no `DateTime.now()` dentro del
    // build: así el historial se recorta contra el mismo instante que usa el
    // resto de la pantalla.
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    // Solo el historial ya ocurrido: un bloque futuro todavía no es nada.
    final history = state.detail.instances
        .where((i) =>
            i.estado != SessionStatus.pendiente || !isFutureDay(i.fecha, now: now))
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpaceTokens.screenMargin,
        SpaceTokens.l,
        SpaceTokens.screenMargin,
        SpaceTokens.xxxl,
      ),
      children: [
        Center(child: AbsenceRing(tally: tally)),
        SizedBox(height: SpaceTokens.l),
        Center(
          child: Text(
            SemaphoreTokens.copy(tally.state, tally.remaining),
            style: context.type(TypeTokens.titleS, color: semaphore),
          ),
        ),
        if (badge != null) ...[
          SizedBox(height: SpaceTokens.s),
          Center(child: _Badge(text: badge, color: semaphore)),
        ],
        SizedBox(height: SpaceTokens.m),
        Center(
          child: Text(
            SAttendance.limitExplainer(n: tally.limit),
            textAlign: TextAlign.center,
            style: context.type(
              TypeTokens.captionS,
              color: ColorTokens.textTertiary.of(b),
            ),
          ),
        ),
        SizedBox(height: SpaceTokens.xl),
        _StreakCard(streak: state.streak),
        SizedBox(height: SpaceTokens.xl),
        Text(
          SAttendance.historyLabel,
          style: context.type(
            TypeTokens.label,
            color: ColorTokens.textTertiary.of(b),
          ),
        ),
        SizedBox(height: SpaceTokens.m),
        for (var i = 0; i < history.length; i++)
          CascadeIn(
            index: i,
            guard: guard,
            child: _HistoryRow(
              instance: history[i],
              onTap: () => _pickStatus(context, ref, history[i]),
            ),
          ),
      ],
    );
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    SessionInstance instance,
  ) async {
    // `null` es «cerró el sheet sin elegir». Deshacer tiene su propio valor:
    // si los dos fueran null, tocar fuera del sheet borraría la marca.
    final choice = await showModalBottomSheet<_StatusChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              (SessionStatus.asistio, SAttendance.stateAttended),
              (SessionStatus.falto, SAttendance.stateAbsent),
              (SessionStatus.canceladaProfe, SAttendance.stateCancelled),
              (SessionStatus.justificada, SAttendance.stateJustified),
            ])
              ListTile(
                title: Text(option.$2),
                onTap: () =>
                    Navigator.of(context).pop(_StatusChoice.set(option.$1)),
              ),
            if (instance.estado != SessionStatus.pendiente)
              ListTile(
                title: const Text(SSubjectDetail.undo),
                onTap: () => Navigator.of(context).pop(const _StatusChoice.undo()),
              ),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;
    final dao = ref.read(scheduleDaoProvider);

    final status = choice.status;
    if (status == null) {
      await dao.clearStatus(instance.id);
      return;
    }

    // Háptica ligera: marcar hecho y marcar cancelado están los dos en la
    // lista `light` del contrato.
    Haptics.fire(
      status == SessionStatus.canceladaProfe || status == SessionStatus.justificada
          ? 'marcarCancelacion'
          : 'marcarAsistencia',
    );
    await dao.setStatus(instance.id, status);
    ref.read(mascotCornerProvider.notifier).react(reactionForStatus(status));
  }
}

/// Lo que el sheet de estado devuelve. `status` en null significa deshacer;
/// que el sheet devuelva null significa que no se eligió nada.
class _StatusChoice {
  const _StatusChoice.set(this.status);
  const _StatusChoice.undo() : status = null;

  final SessionStatus? status;
}

/// La insignia del semáforo: «Mitad de los saltos usada», «Uno más y te pasas».
///
/// Usa [AnimatedContainer] para que el borde de color transite suavemente
/// cuando el estado del semáforo cambia, en lugar de saltar en un fotograma.
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: MotionDurations.fast,
        curve: MotionCurves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: ComponentTokens.chipPaddingV,
          horizontal: ComponentTokens.chipPaddingH,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RadiusTokens.control),
          border: Border.all(color: color, width: BorderTokens.hairline),
        ),
        child: Text(text, style: context.type(TypeTokens.captionS, color: color)),
      );
}

/// La racha: cuántas semanas seguidas llevas cumpliendo y tu mejor marca.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final n = streak.current;
    final lit = n > 0;
    final title = switch (n) {
      0 => SAttendance.streakNone,
      1 => SAttendance.streakCurrentOne,
      _ => SAttendance.streakCurrent(n: n),
    };
    final best = streak.best;

    return Container(
      padding: EdgeInsets.all(SpaceTokens.cardPadding),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceCard.of(b),
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        border: Border.all(color: ColorTokens.surfaceBorder.of(b), width: BorderTokens.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            lit ? Icons.local_fire_department : Icons.local_fire_department_outlined,
            size: IconTokens.sizeXl,
            color: lit ? ColorTokens.accentAttention.of(b) : ColorTokens.textTertiary.of(b),
          ),
          SizedBox(width: SpaceTokens.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type(TypeTokens.titleS)),
                if (best > n) ...[
                  SizedBox(height: SpaceTokens.xs / 2),
                  Text(
                    best == 1 ? SAttendance.streakBestOne : SAttendance.streakBest(n: best),
                    style: context.type(TypeTokens.bodyS, color: ColorTokens.textSecondary.of(b)),
                  ),
                ],
                SizedBox(height: SpaceTokens.xs),
                Text(
                  SAttendance.streakExplainer,
                  style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({required this.instance, required this.onTap});

  final SessionInstance instance;
  final VoidCallback onTap;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  /// Controla el destello de fondo: true durante los primeros 400 ms tras el
  /// toque, luego vuelve a false. Lo gestiona [_flashTap].
  bool _flashing = false;

  Future<void> _flashTap() async {
    if (!mounted) return;
    // El destello solo corre si la animación está permitida.
    final guard = MotionGuard.of(context);
    if (!guard.reduced) {
      setState(() => _flashing = true);
      // [MotionDurations.strike] = 400 ms: el mismo token que el trazo de
      // cancelación, apropiado para un feedback visual de un toque.
      await Future<void>.delayed(MotionDurations.strike);
    }
    if (!mounted) return;
    setState(() => _flashing = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final cancelled = widget.instance.estado == SessionStatus.canceladaProfe;

    final (label, color) = switch (widget.instance.estado) {
      SessionStatus.asistio => (SAttendance.stateAttended, ColorTokens.accentOk.of(b)),
      SessionStatus.falto => (SAttendance.stateAbsent, ColorTokens.accentUrgent.of(b)),
      SessionStatus.canceladaProfe =>
        (SAttendance.stateCancelled, ColorTokens.textTertiary.of(b)),
      SessionStatus.justificada =>
        (SAttendance.stateJustified, ColorTokens.textTertiary.of(b)),
      SessionStatus.posibleFalta =>
        (SAttendance.stateMaybeAbsent, ColorTokens.accentAttention.of(b)),
      SessionStatus.pendiente => ('', ColorTokens.textTertiary.of(b)),
    };

    // AnimatedContainer con destello: fondo transparente → accentOk al 15 %
    // → transparente, en [MotionDurations.strike] (400 ms). Sin animación bajo
    // reduced-motion: el guard ya desactiva el flash antes de este punto.
    return AnimatedContainer(
      duration: MotionDurations.strike,
      curve: MotionCurves.easeOutCubic,
      decoration: BoxDecoration(
        color: _flashing
            ? ColorTokens.accentOk.of(b).withAlpha(0x15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(RadiusTokens.control),
      ),
      child: InkWell(
        onTap: _flashTap,
        borderRadius: BorderRadius.circular(RadiusTokens.control),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: SpaceTokens.m),
          child: Row(
            children: [
              CheckMark(
                checked: widget.instance.estado == SessionStatus.asistio,
                color: ColorTokens.accentOk.of(b),
              ),
              SizedBox(width: SpaceTokens.m),
              Expanded(
                // Un cancelado se tacha, no se esconde: sigue siendo un bloque
                // que estaba en tu horario. El trazo se dibuja al marcarlo.
                child: StrikeThrough(
                  struck: cancelled,
                  guard: MotionGuard.of(context),
                  color: ColorTokens.textPrimary.of(b),
                  struckColor: ColorTokens.textTertiary.of(b),
                  child: Text(
                    DateFormat('EEE d MMM', 'es_CO').format(widget.instance.fecha),
                    style: context.type(TypeTokens.bodyS),
                  ),
                ),
              ),
              Text(label, style: context.type(TypeTokens.captionS, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
