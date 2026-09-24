import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/database.dart';
import '../../../../core/providers.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../domain/attendance/attendance.dart';
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

/// Pestaña Asistencia: el anillo de faltas y el historial de sesiones.
///
/// El número que manda es «cuántas te quedan», no «cuántas llevas»: es la
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

    // Solo el historial ya ocurrido: una clase futura todavía no es nada.
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

    // Háptica ligera: marcar asistencia y marcar cancelación están las dos en
    // la lista `light` del contrato.
    Haptics.fire(
      status == SessionStatus.canceladaProfe
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

/// La insignia del semáforo: «Mitad del cupo usada», «Una más y pierdes».
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
        (SAttendance.stateCancelled, ColorTokens.textTertiary.of(b)),
      SessionStatus.posibleFalta =>
        (SAttendance.stateAbsent, ColorTokens.accentAttention.of(b)),
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
                // Una cancelada se tacha, no se esconde: sigue siendo una clase
                // que estaba en tu horario. El trazo se dibuja al marcarla.
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
