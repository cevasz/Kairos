import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/streaks/streaks.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/cascade.dart';
import '../../../theme/layout.dart';
import '../../../theme/micro_animations.dart';
import '../../../theme/motion.dart';
import '../../../theme/strike_through.dart';
import '../../../theme/tokens.g.dart';
import '../../../theme/transitions.dart';
import '../../import/presentation/import_screen.dart';
import '../../mascot/mascot_error.dart';
import '../../mascot/mascot_loader.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../subject_detail/presentation/subject_detail_screen.dart';
import '../application/subjects_providers.dart';
import 'subject_actions.dart';
import 'subject_form_screen.dart';

/// La pestaña Actividades: todo lo que se repite en tu semana, en una lista.
///
/// Cada tarjeta contesta de un vistazo las dos preguntas que importan: cuántos
/// saltos te quedan y cuántas semanas llevas cumpliendo. Sin mascota: la lista
/// de pantallas permitidas del contrato no la incluye, salvo si la carga falla
/// (`error de carga`).
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsOverviewProvider);

    // En tablet la lista es el panel maestro y la actividad se abre al lado,
    // sin salir de la pantalla. Tocar una fila cambia el panel derecho.
    if (context.sizeClass.isExpanded) {
      final list = subjects.valueOrNull ?? const <SubjectCard>[];
      final selected = ref.watch(selectedSubjectProvider);
      final open = list.any((c) => c.subject.id == selected)
          ? selected
          : list.firstOrNull?.subject.id;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: LayoutTokens.masterPaneWidth,
            child: _ListScaffold(subjects: subjects, selectedId: open),
          ),
          const VerticalDivider(),
          Expanded(
            child: StateSwitcher(
              rise: MotionOffsets.pdfRowRise,
              child: open == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : SubjectDetailScreen(
                      key: ValueKey(open),
                      subjectId: open,
                      embedded: true,
                    ),
            ),
          ),
        ],
      );
    }

    return _ListScaffold(subjects: subjects, selectedId: null);
  }
}

/// La lista con su app bar y su FAB. Es la pantalla entera en teléfono y el
/// panel izquierdo en tablet.
class _ListScaffold extends ConsumerWidget {
  const _ListScaffold({required this.subjects, required this.selectedId});

  final AsyncValue<List<SubjectCard>> subjects;

  /// Fila resaltada en tablet. Null en teléfono: ahí no hay selección.
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(SSubjects.title),
        actions: [
          IconButton(
            onPressed: () => openImport(context),
            tooltip: SImportPicker.title,
            icon: const Icon(Icons.event_available_outlined),
          ),
          IconButton(
            onPressed: () => openSettings(context),
            tooltip: SSettings.title,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: subjects.valueOrNull?.isEmpty ?? true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openSubjectForm(context),
              icon: const Icon(Icons.add),
              label: const Text(SSubjects.addSubject),
            ),
      body: subjects.when(
        loading: () => const MascotLoader(),
        error: (e, _) => MascotError(error: e, onRetry: () => ref.invalidate(subjectsOverviewProvider)),
        data: (list) => list.isEmpty
            ? const _Empty()
            : _List(subjects: list, selectedId: selectedId),
      ),
    );
  }
}

/// Abre el formulario de actividad. Se expone como función para que la tarjeta,
/// el FAB y el estado vacío usen exactamente la misma ruta.
Future<void> openSubjectForm(BuildContext context, {int? subjectId}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => SubjectFormScreen(subjectId: subjectId)),
  );
}

class _List extends StatelessWidget {
  const _List({required this.subjects, required this.selectedId});

  final List<SubjectCard> subjects;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final guard = MotionGuard.of(context);
    final b = Theme.of(context).brightness;
    // Las pausadas llegan al final (así las ordena el DAO). El conteo es de
    // las que siguen en tu agenda.
    final active = subjects.where((c) => !c.subject.cancelada).toList();
    final cancelled = subjects.where((c) => c.subject.cancelada).toList();
    final rows = <Object>[...active, if (cancelled.isNotEmpty) _cancelledLabel, ...cancelled];

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        SpaceTokens.screenMargin,
        SpaceTokens.m,
        SpaceTokens.screenMargin,
        // Espacio para que el FAB no tape la última tarjeta.
        SpaceTokens.xxxl * 2,
      ),
      itemCount: rows.length + 1,
      separatorBuilder: (_, __) => SizedBox(height: SpaceTokens.cardGap),
      itemBuilder: (context, i) {
        if (i == 0) {
          // NumberRollIn: el número de actividades anima como odómetro cuando
          // cambia (añadir / borrar una). El texto que lo acompaña es
          // estático: solo el entero salta.
          return Padding(
            padding: EdgeInsets.only(bottom: SpaceTokens.xs),
            child: active.length == 1
                ? Text(
                    SSubjects.countOne,
                    style: context.type(
                      TypeTokens.bodyM,
                      color: ColorTokens.textTertiary.of(b),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NumberRollIn(
                        value: active.length,
                        style: context.type(
                          TypeTokens.bodyM,
                          color: ColorTokens.textTertiary.of(b),
                        ),
                      ),
                      Text(
                        // El string completo es «N actividades»; quitamos el número
                        // del inicio para que NumberRollIn lo anime solo.
                        SSubjects.count(n: active.length)
                            .replaceFirst('${active.length}', ''),
                        style: context.type(
                          TypeTokens.bodyM,
                          color: ColorTokens.textTertiary.of(b),
                        ),
                      ),
                    ],
                  ),
          );
        }
        final row = rows[i - 1];
        if (row is! SubjectCard) {
          return Padding(
            padding: EdgeInsets.only(top: SpaceTokens.l),
            child: Text(
              SSubjectCancel.sectionLabel,
              style: context.type(TypeTokens.label, color: ColorTokens.textTertiary.of(b)),
            ),
          );
        }
        final card = row;
        return CascadeIn(
          index: i - 1,
          guard: guard,
          child: _SubjectTile(card: card, selected: card.subject.id == selectedId),
        );
      },
    );
  }
}

/// Marca de la sección de pausadas dentro de la lista mixta de filas.
const Object _cancelledLabel = 'cancelled-label';

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({required this.card, required this.selected});

  final SubjectCard card;

  /// Solo en tablet: la fila abierta en el panel derecho.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final cancelled = card.subject.cancelada;
    final accent = cancelled ? ColorTokens.surfaceBorder.of(b) : SubjectPalette.at(card.subject.colorIndex);
    final semaphore = cancelled
        ? ColorTokens.textTertiary.of(b)
        : SemaphoreTokens.color[card.tally.state]!.of(b);

    // PressScaleButton con escala 0.97: las filas de lista usan menos compresión
    // que los botones de acción (0.96) para no parecer que «aplastas» la fila.
    return PressScaleButton(
      pressedScale: 0.97,
      child: Material(
        color: selected ? ColorTokens.surfaceRaised.of(b) : ColorTokens.surfaceCard.of(b),
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          onLongPress: () => showSubjectQuickActions(context, ref, card.subject),
          onTap: () {
            if (context.sizeClass.isExpanded) {
              ref.read(selectedSubjectProvider.notifier).state = card.subject.id;
              return;
            }
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SubjectDetailScreen(subjectId: card.subject.id),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(SpaceTokens.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RadiusTokens.card),
              border: Border(
                left: BorderSide(
                  color: accent,
                  width: ComponentTokens.subjectCardAccentBorderLeft,
                ),
                top: BorderSide(
                  color: ColorTokens.surfaceBorder.of(b),
                  width: BorderTokens.hairline,
                ),
                right: BorderSide(
                  color: ColorTokens.surfaceBorder.of(b),
                  width: BorderTokens.hairline,
                ),
                bottom: BorderSide(
                  color: ColorTokens.surfaceBorder.of(b),
                  width: BorderTokens.hairline,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StrikeThrough(
                        struck: cancelled,
                        guard: MotionGuard.of(context),
                        color: ColorTokens.textPrimary.of(b),
                        struckColor: ColorTokens.textSecondary.of(b),
                        child: Text(card.subject.nombre, style: context.type(TypeTokens.titleS)),
                      ),
                    ),
                    if (cancelled) ...[
                      SizedBox(width: SpaceTokens.s),
                      _Badge(text: SSubjectCancel.badge),
                    ],
                  ],
                ),
                SizedBox(height: SpaceTokens.xs),
                Text(
                  [
                    card.subject.profesor,
                    card.weeklyClasses == 0
                        ? SSubjects.noSchedule
                        : card.weeklyClasses == 1
                            ? SSubjects.classesPerWeekOne
                            : SSubjects.classesPerWeek(n: card.weeklyClasses),
                  ].whereType<String>().join(' · '),
                  style: context.type(
                    TypeTokens.captionS,
                    color: ColorTokens.textTertiary.of(b),
                  ),
                ),
                SizedBox(height: SpaceTokens.m),
                Row(
                  children: [
                    _Dot(color: semaphore),
                    SizedBox(width: SpaceTokens.xs + SpaceTokens.xs / 2),
                    Text(
                      SSubjects.absencesShort(
                        used: card.tally.used,
                        limit: card.tally.limit,
                      ),
                      style: context.type(TypeTokens.captionS, color: semaphore),
                    ),
                    const Spacer(),
                    if (!cancelled) _StreakLabel(streak: card.streak),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Racha de 4 semanas», con una llama que solo se enciende si hay racha.
class _StreakLabel extends StatelessWidget {
  const _StreakLabel({required this.streak});
  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final n = streak.current;
    final color = n > 0 ? ColorTokens.textSecondary.of(b) : ColorTokens.textTertiary.of(b);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (n > 0) ...[
          Icon(Icons.local_fire_department_outlined, size: IconTokens.sizeXs, color: ColorTokens.accentAttention.of(b)),
          SizedBox(width: SpaceTokens.xs),
        ],
        Text(
          switch (n) {
            0 => SSubjects.streakShortNone,
            1 => SSubjects.streakShortOne,
            _ => SSubjects.streakShort(n: n),
          },
          style: context.type(TypeTokens.captionS, color: color),
        ),
      ],
    );
  }
}

/// Insignia de estado, en hairline: informa sin gritar.
class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.themed(ColorTokens.textSecondary);
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: SpaceTokens.xs / 2,
        horizontal: SpaceTokens.s,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RadiusTokens.full),
        border: Border.all(color: color, width: BorderTokens.hairline),
      ),
      child: Text(text, style: context.type(TypeTokens.label, color: color)),
    );
  }
}

/// El punto del semáforo. Es el mismo lenguaje que el anillo segmentado de la
/// pantalla de materia, reducido a lo que cabe en una fila.
///
/// Usa [AnimatedContainer] para que el cambio de color (ok → atención → riesgo)
/// transite suavemente con [MotionDurations.fast] en lugar de saltar en un
/// fotograma.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: MotionDurations.fast,
        curve: MotionCurves.easeOutCubic,
        width: LayoutTokens.timelineRowDotSize,
        height: LayoutTokens.timelineRowDotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutTokens.screenPaddingHHero),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              SSubjects.emptyHeadline,
              textAlign: TextAlign.center,
              style: context.type(TypeTokens.titleM),
            ),
            SizedBox(height: SpaceTokens.s),
            Text(
              SSubjects.emptyBody,
              textAlign: TextAlign.center,
              style: context.type(
                TypeTokens.bodyM,
                color: ColorTokens.textSecondary.of(b),
              ),
            ),
            SizedBox(height: SpaceTokens.xl),
            FilledButton(
              onPressed: () => openSubjectForm(context),
              child: const Text(SSubjects.emptyCta),
            ),
            SizedBox(height: SpaceTokens.s),
            OutlinedButton(
              onPressed: () => openImport(context),
              child: const Text(SOnboarding.ctaImport),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un fallo de base de datos se enseña, no se traga. Sin texto inventado: el
/// mensaje del error es el mensaje.
