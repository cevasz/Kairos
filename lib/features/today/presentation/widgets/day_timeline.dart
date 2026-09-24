import 'package:flutter/material.dart';

import '../../../../core/format/durations.dart';
import '../../../../core/db/daos/schedule_dao.dart';
import '../../../../core/time/minutes_of_day.dart';
import '../../../../domain/attendance/attendance.dart';
import '../../../../domain/schedule/day_gaps.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/cascade.dart';
import '../../../../theme/micro_animations.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/strike_through.dart';
import '../../../../theme/tokens.g.dart';

/// «El día»: la lista de clases con su hora, su riel y su estado.
///
/// Entra en cascada: 40 ms de escalonado y 12 px de subida, solo en la primera
/// carga del día. Bajo reduced-motion aparece de golpe con un fade conjunto.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    required this.classes,
    required this.highlightId,
    this.gapsAfter = const {},
    this.urgent = false,
    super.key,
  });

  final List<DayClass> classes;

  /// La clase que la card de arriba está anunciando. Se pinta en ámbar.
  final int? highlightId;

  /// Huecos que enseñar tras cada clase, por id de instancia.
  final Map<int, DayGap> gapsAfter;

  /// Si la card de arriba está en «sal ya», la fila resaltada lo dice también.
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);
    final b = Theme.of(context).brightness;

    // Cada fila y cada hueco tienen su propio paso de la cascada.
    final rows = <Widget>[];
    for (final c in classes) {
      final isHighlighted = c.instance.id == highlightId;
      final row = _TimelineRow(
        item: c,
        highlighted: isHighlighted,
        urgent: urgent && isHighlighted,
      );
      // PulseHighlight: cuando la clase pasa a ser la «siguiente» activa,
      // la fila hace un destello suave de fondo (accentPrimary al 15 %).
      rows.add(
        isHighlighted
            ? PulseHighlight(
                highlighted: isHighlighted,
                color: urgent
                    ? ColorTokens.accentUrgent.of(b)
                    : ColorTokens.accentPrimary.of(b),
                child: row,
              )
            : row,
      );
      final gap = gapsAfter[c.instance.id];
      if (gap != null) rows.add(_GapRow(gap: gap));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(SToday.dayLabel, style: context.type(TypeTokens.label, color: context.themed(ColorTokens.textTertiary))),
        SizedBox(height: SpaceTokens.m),
        for (var i = 0; i < rows.length; i++)
          // Los GapRow entran con scale 0.96 para un ligero pop que los
          // distingue visualmente de las filas de clase. Las filas de clase
          // usan scale 1.0 (sin pop): ya tienen el riel y el acento como jerarquía.
          CascadeIn(
            index: i,
            guard: guard,
            scale: rows[i] is _GapRow ? 0.96 : 1.0,
            child: Padding(
              padding: EdgeInsets.only(bottom: SpaceTokens.m),
              child: rows[i],
            ),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.highlighted,
    required this.urgent,
  });

  final DayClass item;
  final bool highlighted;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final cancelled = item.status == SessionStatus.canceladaProfe;
    final past = item.status == SessionStatus.asistio || item.status == SessionStatus.falto;

    final accent = urgent
        ? ColorTokens.accentUrgent.of(b)
        : highlighted
            ? ColorTokens.accentPrimary.of(b)
            : ColorTokens.surfaceBorder.of(b);

    return Opacity(
      // Lo ya resuelto se atenúa; lo cancelado, un poco menos, porque todavía
      // hay que poder leer que estaba cancelado.
      opacity: past ? 0.4 : (cancelled ? 0.6 : 1.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: LayoutTokens.timelineRowTimeColumnWidth,
            child: Text(
              MinutesOfDay(item.session.horaInicio).hhmm,
              textAlign: TextAlign.right,
              style: context.type(
                TypeTokens.caption,
                color: highlighted ? accent : ColorTokens.textSecondary.of(b),
              ),
            ),
          ),
          SizedBox(width: LayoutTokens.timelineRowGap),
          Container(
            width: LayoutTokens.timelineRowRailWidth,
            height: LayoutTokens.timelineRowRailHeight,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(LayoutTokens.timelineRowRailWidth / 2),
            ),
          ),
          SizedBox(width: LayoutTokens.timelineRowGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Title(item: item, cancelled: cancelled),
                SizedBox(height: SpaceTokens.xs / 2),
                Text(
                  _subtitle(item),
                  style: context.type(
                    TypeTokens.captionS,
                    color: ColorTokens.textTertiary.of(b),
                  ),
                ),
              ],
            ),
          ),
          if (highlighted) ...[
            SizedBox(width: LayoutTokens.timelineRowGap),
            Text(
              urgent ? SToday.urgentTimelineLabel : SToday.next,
              style: context.type(TypeTokens.label, color: accent),
            ),
          ],
        ],
      ),
    );
  }

  static String _subtitle(DayClass item) {
    final range = '${MinutesOfDay(item.session.horaInicio).hhmm}–${MinutesOfDay(item.session.horaFin).hhmm}';
    final room = item.room?.codigo;
    final status = switch (item.status) {
      SessionStatus.asistio => SToday.attended.toLowerCase(),
      SessionStatus.canceladaProfe => SCancelled.shortLabel.toLowerCase(),
      SessionStatus.falto => SAttendance.stateAbsent.toLowerCase(),
      _ => null,
    };
    return [range, room, status].whereType<String>().join(' · ');
  }
}

/// Un hueco entre clases. Sin hora a la izquierda: no es un evento, es la
/// ausencia de uno. El riel sigue, más tenue, para que la línea no se corte.
class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap});
  final DayGap gap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: LayoutTokens.timelineRowTimeColumnWidth + LayoutTokens.timelineRowGap),
        Opacity(
          opacity: 0.5,
          child: Container(
            width: LayoutTokens.timelineRowRailWidth,
            height: LayoutTokens.timelineRowRailHeight / 2,
            decoration: BoxDecoration(
              color: ColorTokens.surfaceBorder.of(b),
              borderRadius: BorderRadius.circular(LayoutTokens.timelineRowRailWidth / 2),
            ),
          ),
        ),
        SizedBox(width: LayoutTokens.timelineRowGap),
        Text(
          SToday.gap(d: formatGapDuration(gap)),
          style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
        ),
      ],
    );
  }

}

/// El título de una clase cancelada va tachado, no oculto ni gris a secas.
///
/// El trazo se dibuja: cancelar es algo que acaba de pasar, no un estilo que
/// siempre estuvo ahí.
class _Title extends StatelessWidget {
  const _Title({required this.item, required this.cancelled});

  final DayClass item;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return StrikeThrough(
      struck: cancelled,
      guard: MotionGuard.of(context),
      color: ColorTokens.textPrimary.of(b),
      struckColor: ColorTokens.textSecondary.of(b),
      child: Text(
        item.subject.nombre,
        style: context.type(TypeTokens.bodyS),
      ),
    );
  }
}

/// «45 min», «1 h», «1 h 30». Sin ceros de relleno: es prosa, no un reloj.
/// La usan la timeline y los consejos de Erizógenes.
String formatGapDuration(DayGap gap) => TimeSpans.minutes(gap.minutes);
