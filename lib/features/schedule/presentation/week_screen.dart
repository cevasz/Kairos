import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/daos/schedule_dao.dart';
import '../../../core/providers.dart';
import '../../../core/time/calendar_day.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../theme/strike_through.dart';
import '../../../theme/tokens.g.dart';
import '../../mascot/mascot_error.dart';
import '../../mascot/mascot_loader.dart';
import '../application/week_providers.dart';
import 'widgets/subject_sheet.dart';

/// Horario semanal con scroll horizontal. Cada bloque es el origen de un hero
/// hacia el detalle de materia.
///
/// Sin mascota: «horario semanal» está en la lista de pantallas prohibidas.
class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekProvider);
    final monday = ref.watch(weekMondayProvider);
    final today = ref.watch(todayProvider);
    final b = Theme.of(context).brightness;

    return Scaffold(
      body: SafeArea(
        child: week.when(
          loading: () => const MascotLoader(),
          error: (e, _) => MascotError(error: e, onRetry: () => ref.invalidate(weekProvider)),
          data: (byDay) => LayoutBuilder(builder: (context, constraints) {
            final total = byDay.values.fold<int>(0, (n, l) => n + l.length);
            // Ancho de columna: el del contrato como mínimo; en tablet las
            // siete se reparten el ancho y desaparece el scroll horizontal.
            final available = constraints.maxWidth - SpaceTokens.screenMargin * 2;
            final columnWidth = math.max(
              LayoutTokens.weekColumnWidth,
              (available - SpaceTokens.s * 6) / 7,
            );
            final fits = columnWidth > LayoutTokens.weekColumnWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    SpaceTokens.screenMargin,
                    SpaceTokens.l,
                    SpaceTokens.s,
                    SpaceTokens.m,
                  ),
                  child: _Header(monday: monday, today: today, total: total),
                ),
                Expanded(
                  child: _WeekStrip(
                    monday: monday,
                    today: today,
                    byDay: byDay,
                    columnWidth: columnWidth,
                  ),
                ),
                if (!fits)
                  Padding(
                    padding: EdgeInsets.all(SpaceTokens.l),
                    child: Text(
                      SWeek.swipeHint,
                      style: context.type(
                        TypeTokens.captionS,
                        color: ColorTokens.textTertiary.of(b),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Título, rango de fechas con el conteo, y las flechas para moverse de
/// semana. Tocar el rango vuelve a la semana de hoy.
class _Header extends ConsumerWidget {
  const _Header({required this.monday, required this.today, required this.total});

  final DateTime monday;
  final DateTime today;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final sunday = monday.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM', 'es_CO');
    final anchor = ref.read(weekAnchorProvider.notifier);
    final isThisWeek = !startOfDay(today).isBefore(monday) && !startOfDay(today).isAfter(sunday);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(SWeek.title, style: context.type(TypeTokens.titleL)),
              SizedBox(height: SpaceTokens.xs),
              GestureDetector(
                onTap: isThisWeek ? null : () => anchor.state = today,
                child: Text(
                  SWeek.range(
                    desde: fmt.format(monday).replaceAll('.', ''),
                    hasta: fmt.format(sunday).replaceAll('.', ''),
                    n: total,
                  ),
                  style: context.type(
                    TypeTokens.bodyM,
                    color: isThisWeek
                        ? ColorTokens.textSecondary.of(b)
                        : ColorTokens.accentPrimary.of(b),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => anchor.state = monday.subtract(const Duration(days: 7)),
          icon: const Icon(Icons.chevron_left),
          iconSize: IconTokens.sizeXl,
          color: ColorTokens.textSecondary.of(b),
        ),
        IconButton(
          onPressed: () => anchor.state = monday.add(const Duration(days: 7)),
          icon: const Icon(Icons.chevron_right),
          iconSize: IconTokens.sizeXl,
          color: ColorTokens.textSecondary.of(b),
        ),
      ],
    );
  }
}

/// Las siete columnas. Arranca desplazada a la columna de hoy: lo que se
/// consulta es «qué tengo hoy y mañana», no el lunes.
class _WeekStrip extends StatefulWidget {
  const _WeekStrip({
    required this.monday,
    required this.today,
    required this.byDay,
    required this.columnWidth,
  });

  final DateTime monday;
  final DateTime today;
  final Map<int, List<DayClass>> byDay;
  final double columnWidth;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  late final ScrollController _controller;

  double get _stride => widget.columnWidth + SpaceTokens.s;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(initialScrollOffset: _offsetFor(widget.today));
  }

  @override
  void didUpdateWidget(covariant _WeekStrip old) {
    super.didUpdateWidget(old);
    // Al cambiar de semana se vuelve al principio; si es la de hoy, a hoy.
    if (old.monday != widget.monday && _controller.hasClients) {
      _controller.jumpTo(_offsetFor(widget.today).clamp(0, _controller.position.maxScrollExtent));
    }
  }

  double _offsetFor(DateTime day) {
    final inWeek = !startOfDay(day).isBefore(widget.monday) &&
        startOfDay(day).difference(widget.monday).inDays < 7;
    if (!inWeek) return 0;
    return (day.weekday - 1) * _stride;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: SpaceTokens.screenMargin),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var d = 1; d <= 7; d++)
            _DayColumn(
              date: widget.monday.add(Duration(days: d - 1)),
              today: widget.today,
              label: SWeek.days[d - 1],
              classes: widget.byDay[d] ?? const [],
              width: widget.columnWidth,
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.today,
    required this.label,
    required this.classes,
    required this.width,
  });

  final DateTime date;
  final DateTime today;
  final String label;
  final List<DayClass> classes;
  final double width;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isToday = startOfDay(date) == startOfDay(today);
    final isPast = startOfDay(date).isBefore(startOfDay(today));

    return Container(
      width: width,
      margin: EdgeInsets.only(right: SpaceTokens.s),
      padding: EdgeInsets.all(SpaceTokens.xs),
      decoration: isToday
          ? BoxDecoration(
              color: ColorTokens.surfaceRaised.of(b),
              borderRadius: BorderRadius.circular(RadiusTokens.card),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: SpaceTokens.xs),
            child: Row(
              children: [
                Text(
                  label,
                  style: context.type(
                    TypeTokens.label,
                    color: isToday
                        ? ColorTokens.accentPrimary.of(b)
                        : ColorTokens.textSecondary.of(b),
                  ),
                ),
                SizedBox(width: SpaceTokens.xs),
                Text(
                  '${date.day}',
                  style: context.type(
                    TypeTokens.label,
                    color: isToday
                        ? ColorTokens.accentPrimary.of(b)
                        : ColorTokens.textTertiary.of(b),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: SpaceTokens.s),
          for (final c in classes)
            Padding(
              padding: EdgeInsets.only(bottom: SpaceTokens.s),
              child: _WeekBlock(item: c, dimmed: isPast),
            ),
        ],
      ),
    );
  }
}

/// El bloque del horario. Al tocarlo hace hero hacia el bottom sheet de la
/// materia: viajan posición, tamaño, radio y color.
class _WeekBlock extends StatelessWidget {
  const _WeekBlock({required this.item, required this.dimmed});

  final DayClass item;

  /// Un día ya pasado se atenúa: sigue ahí para consultar, pero no compite
  /// con lo que viene.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);
    final accent = SubjectPalette.at(item.subject.colorIndex);
    final tag = 'subject-${item.subject.id}-${item.instance.id}';
    final cancelled = item.status == SessionStatus.canceladaProfe;

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        // Bajo reduced-motion el hero se desactiva y el sheet entra con fade.
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => SubjectSheet(item: item, heroTag: guard.allows('heroTransition') ? tag : null),
      ),
      child: Opacity(
        opacity: dimmed || cancelled ? 0.6 : 1.0,
        child: Hero(
          tag: tag,
          // El hero no debe arrastrar el Material del bloque: se reconstruye plano.
          flightShuttleBuilder: (_, __, ___, ____, toContext) =>
              (toContext.widget as Hero).child,
          child: Container(
            padding: EdgeInsets.all(SpaceTokens.m),
            decoration: BoxDecoration(
              color: ColorTokens.surfaceCard.of(b),
              borderRadius: BorderRadius.circular(RadiusTokens.card),
              border: Border(
                left: BorderSide(
                  color: cancelled ? ColorTokens.surfaceBorder.of(b) : accent,
                  width: BorderTokens.subjectAccent,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StrikeThrough(
                  struck: cancelled,
                  guard: guard,
                  color: ColorTokens.textPrimary.of(b),
                  struckColor: ColorTokens.textSecondary.of(b),
                  child: Text(
                    item.subject.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type(TypeTokens.captionS),
                  ),
                ),
                SizedBox(height: SpaceTokens.xs),
                Text(
                  '${MinutesOfDay(item.session.horaInicio).hhmm}–${MinutesOfDay(item.session.horaFin).hhmm}',
                  style: context.type(
                    TypeTokens.label,
                    color: ColorTokens.textTertiary.of(b),
                  ),
                ),
                if (item.room != null)
                  Text(
                    item.room!.codigo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type(
                      TypeTokens.label,
                      color: ColorTokens.textTertiary.of(b),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
