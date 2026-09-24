import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/daos/schedule_dao.dart';
import '../../../../core/db/daos/tasks_dao.dart';
import '../../../../core/providers.dart';
import '../../../../domain/attendance/attendance.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/haptics.dart';
import '../../../../theme/tokens.g.dart';
import '../../../mascot/application/mascot_voice.dart';
import '../../../subject_detail/presentation/subject_detail_screen.dart';
import '../../../subjects/application/subjects_providers.dart';
import '../../../tasks/application/tasks_providers.dart';

/// Destino del hero desde el bloque semanal. Sin mascota: es pantalla de
/// trabajo, y la lista de prohibidas la incluye explícitamente.
///
/// Además de las acciones, contesta tres preguntas: cuántos saltos llevas,
/// cuántas semanas vas cumpliendo y qué tienes pendiente.
class SubjectSheet extends ConsumerWidget {
  const SubjectSheet({required this.item, this.heroTag, super.key});

  final DayClass item;

  /// Null bajo reduced-motion: el sheet entra con fade y sin vuelo.
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final accent = SubjectPalette.at(item.subject.colorIndex);
    final card = ref.watch(subjectsOverviewProvider).valueOrNull?.where(
          (c) => c.subject.id == item.subject.id,
        ).firstOrNull;
    final resolved = item.status != SessionStatus.pendiente;

    final header = Container(
      width: double.infinity,
      padding: EdgeInsets.all(SpaceTokens.cardPadding),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceCard.of(b),
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        border: Border(
          left: BorderSide(color: accent, width: BorderTokens.subjectAccent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.subject.nombre, style: context.type(TypeTokens.titleM)),
          SizedBox(height: SpaceTokens.xs),
          Text(
            [item.subject.profesor, item.room?.codigo]
                .whereType<String>()
                .join(' · '),
            style: context.type(
              TypeTokens.bodyM,
              color: ColorTokens.textSecondary.of(b),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.all(SpaceTokens.screenMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heroTag != null) Hero(tag: heroTag!, child: header) else header,
          if (card != null) ...[
            SizedBox(height: SpaceTokens.l),
            _Stats(card: card),
          ],
          SizedBox(height: SpaceTokens.l),
          if (resolved)
            OutlinedButton(
              onPressed: () => _undo(context, ref),
              child: Text('${_statusLabel(item.status)} · ${SSubjectDetail.undo}'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _mark(context, ref, SessionStatus.canceladaProfe),
                    child: const Text(SSubjectSheet.markCancelled),
                  ),
                ),
                SizedBox(width: SpaceTokens.s),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _mark(context, ref, SessionStatus.falto),
                    child: const Text(SSubjectSheet.markAbsence),
                  ),
                ),
              ],
            ),
          SizedBox(height: SpaceTokens.s),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      SubjectDetailScreen(subjectId: item.subject.id),
                ),
              );
            },
            child: const Text(SSubjectSheet.openSubject),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(SessionStatus s) => switch (s) {
        SessionStatus.asistio => SAttendance.stateAttended,
        SessionStatus.falto => SAttendance.stateAbsent,
        SessionStatus.canceladaProfe => SAttendance.stateCancelled,
        SessionStatus.justificada => SAttendance.stateJustified,
        SessionStatus.posibleFalta => SAttendance.stateMaybeAbsent,
        SessionStatus.pendiente => SAttendance.stateAttended,
      };

  /// Marcar cancelación y marcar falta comparten la háptica ligera del
  /// contrato; ninguna de las dos es destructiva, las dos son reversibles desde
  /// el historial de la actividad.
  Future<void> _mark(
    BuildContext context,
    WidgetRef ref,
    SessionStatus status,
  ) async {
    unawaited(Haptics.fire(
      status == SessionStatus.canceladaProfe
          ? 'marcarCancelacion'
          : 'marcarAsistencia',
    ));
    await ref.read(scheduleDaoProvider).setStatus(item.instance.id, status);
    ref.read(mascotCornerProvider.notifier).react(reactionForStatus(status));
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    await ref.read(scheduleDaoProvider).clearStatus(item.instance.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Tres cifras en fila: saltos, racha y el próximo pendiente. Es la misma
/// información que la tarjeta de Actividades, con el pendiente añadido porque
/// desde el horario la pregunta suele ser «¿qué tengo que llevar?».
class _Stats extends ConsumerWidget {
  const _Stats({required this.card});
  final SubjectCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final semaphore = SemaphoreTokens.color[card.tally.state]!.of(b);
    // El DAO ya los ordena por fecha: el primero de esta actividad es el que
    // viene.
    final next = (ref.watch(pendingProvider).valueOrNull ?? const <PendingItem>[])
        .where((p) => p.subject.id == card.subject.id)
        .firstOrNull;
    final streak = card.streak.current;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Stat(
            label: SSubjectSheet.absences,
            value: '${card.tally.used}',
            detail: SSubjectSheet.ofLimit(n: card.tally.limit),
            color: semaphore,
          ),
        ),
        Expanded(
          child: _Stat(
            label: SSubjectSheet.streak,
            value: '$streak',
            detail: streak == 1 ? SSubjectSheet.streakWeek : SSubjectSheet.streakWeeks,
            color: ColorTokens.textPrimary.of(b),
          ),
        ),
        Expanded(
          child: _Stat(
            label: SSubjectSheet.nextTask,
            value: next?.titulo ?? SSubjectSheet.nextTaskNone,
            detail: next == null
                ? ''
                : next.fecha == null
                    ? STasks.noDue
                    : DateFormat('d MMM', 'es_CO').format(next.fecha!).replaceAll('.', ''),
            color: ColorTokens.textPrimary.of(b),
            valueStyle: TypeTokens.bodyS,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    this.valueStyle = TypeTokens.titleM,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;
  final TypeToken valueStyle;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.type(TypeTokens.label, color: ColorTokens.textTertiary.of(b))),
        SizedBox(height: SpaceTokens.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type(valueStyle, color: color),
        ),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type(TypeTokens.captionS, color: ColorTokens.textSecondary.of(b)),
        ),
      ],
    );
  }
}
