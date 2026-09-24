import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout.dart';
import '../../../theme/tokens.g.dart';
import '../../mascot/mascot_error.dart';
import '../../mascot/mascot_loader.dart';
import '../../subjects/application/subjects_providers.dart';
import '../../subjects/presentation/subject_actions.dart';
import '../../subjects/presentation/subjects_screen.dart';
import '../application/subject_detail_providers.dart';
import 'widgets/attendance_tab.dart';
import 'widgets/tasks_tab.dart';

/// La pantalla de una actividad: Pendientes e Historial.
///
/// Sin mascota. «detalle de materia» está en la lista de pantallas prohibidas
/// del contrato: aquí se viene a trabajar, y a veces a recibir malas noticias.
///
/// En teléfono son dos pestañas. En tablet, las dos columnas a la vez: «qué
/// me falta» y «cómo voy» caben juntas.
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({
    required this.subjectId,
    this.embedded = false,
    super.key,
  });

  final int subjectId;

  /// `true` cuando vive en el panel derecho de Actividades en tablet: sin
  /// flecha de volver, y si la actividad se borra se limpia la selección en vez de
  /// cerrar una ruta que no existe.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subjectDetailProvider(subjectId));

    return async.when(
      loading: () => const Scaffold(body: MascotLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: MascotError(error: e, onRetry: () => ref.invalidate(subjectDetailProvider(subjectId))),
      ),
      data: (state) {
        // La actividad se borró mientras la pantalla estaba abierta. Se cierra
        // sola en vez de quedarse enseñando datos que ya no existen.
        if (state == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (embedded) {
              ref.read(selectedSubjectProvider.notifier).state = null;
            } else {
              Navigator.of(context).maybePop();
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return _Loaded(state: state, embedded: embedded);
      },
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.state, required this.embedded});

  final SubjectDetailState state;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final subject = state.detail.subject;
    // En pausa, la actividad pierde su color: sigue ahí, pero ya no es tuya
    // esta semana.
    final accent = subject.cancelada ? ColorTokens.surfaceBorder.of(b) : SubjectPalette.at(subject.colorIndex);
    final wide = context.sizeClass.isExpanded;

    final actions = [
      IconButton(
        onPressed: () => openSubjectForm(context, subjectId: subject.id),
        tooltip: SSubjectDetail.edit,
        icon: const Icon(Icons.edit_outlined),
      ),
      PopupMenuButton<void>(
        tooltip: SSubjectCancel.menu,
        itemBuilder: (_) => [
          PopupMenuItem<void>(
            onTap: () => toggleSubjectCancelled(context, ref, subject),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(subject.cancelada ? Icons.undo : Icons.block_outlined),
              title: Text(subject.cancelada ? SSubjectCancel.reactivate : SSubjectCancel.action),
            ),
          ),
        ],
      ),
    ];

    if (wide) {
      return Scaffold(
        appBar: AppBar(
          title: Text(subject.nombre),
          automaticallyImplyLeading: !embedded,
          actions: actions,
        ),
        body: Column(
          children: [
            _Header(state: state, accent: accent),
            // Cada pestaña trae su propio margen de pantalla; sumados en el
            // centro hacen el hueco entre columnas, así que no se añade otro.
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Pane(label: STasks.tab, child: TasksTab(state: state))),
                  Expanded(child: _Pane(label: SAttendance.tab, child: AttendanceTab(state: state))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(subject.nombre),
          automaticallyImplyLeading: !embedded,
          actions: actions,
          bottom: TabBar(
            indicatorColor: accent,
            indicatorWeight: BorderTokens.tabIndicator,
            dividerColor: ColorTokens.surfaceBorder.of(b),
            labelColor: ColorTokens.textPrimary.of(b),
            unselectedLabelColor: ColorTokens.textTertiary.of(b),
            labelStyle: context.type(TypeTokens.bodyS),
            tabs: const [
              Tab(text: STasks.tab),
              Tab(text: SAttendance.tab),
            ],
          ),
        ),
        body: Column(
          children: [
            _Header(state: state, accent: accent),
            Expanded(
              child: TabBarView(
                children: [
                  TasksTab(state: state),
                  AttendanceTab(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una de las dos columnas de tablet, con la etiqueta que en teléfono era la
/// pestaña.
class _Pane extends StatelessWidget {
  const _Pane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: SpaceTokens.l, left: SpaceTokens.screenMargin),
            child: Text(
              label,
              style: context.type(TypeTokens.label, color: context.themed(ColorTokens.textTertiary)),
            ),
          ),
          Expanded(child: child),
        ],
      );
}

/// Con quién y horario. Es lo que se consulta sin pensar: cuándo y con quién.
class _Header extends ConsumerWidget {
  const _Header({required this.state, required this.accent});

  final SubjectDetailState state;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final subject = state.detail.subject;
    final profesor = subject.profesor;
    final hasSessions = state.detail.sessions.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        SpaceTokens.screenMargin,
        SpaceTokens.m,
        SpaceTokens.screenMargin,
        0,
      ),
      padding: EdgeInsets.all(SpaceTokens.cardPadding),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceCard.of(b),
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        border: Border(
          left: BorderSide(
            color: accent,
            width: ComponentTokens.subjectCardAccentBorderLeft,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject.cancelada) ...[
            _CancelledBanner(subject: subject),
            SizedBox(height: SpaceTokens.m),
          ],
          if (profesor != null)
            Text(
              SSubjectDetail.withWhom(nombre: profesor),
              style: context.type(TypeTokens.bodyS),
            ),
          if (hasSessions) ...[
            if (profesor != null) SizedBox(height: SpaceTokens.xs),
            Text(
              state.detail.sessions
                  .map((s) => SSessionForm.summary(
                        dia: SWeek.days[s.session.diaSemana - 1],
                        inicio: MinutesOfDay(s.session.horaInicio).hhmm,
                        fin: MinutesOfDay(s.session.horaFin).hhmm,
                      ))
                  .join('  ·  '),
              style: context.type(
                TypeTokens.captionS,
                color: ColorTokens.textTertiary.of(b),
              ),
            ),
          ],
          if (!hasSessions && profesor == null)
            Text(
              SSubjects.noSchedule,
              style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
            ),
        ],
      ),
    );
  }
}

/// «Esta actividad está en pausa» con la fecha y la salida para reanudarla.
class _CancelledBanner extends ConsumerWidget {
  const _CancelledBanner({required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final when = subject.fechaCancelacion;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(SpaceTokens.m),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceRaised.of(b),
        borderRadius: BorderRadius.circular(RadiusTokens.control),
      ),
      child: Row(
        children: [
          Icon(Icons.block_outlined, size: IconTokens.sizeM, color: ColorTokens.textSecondary.of(b)),
          SizedBox(width: SpaceTokens.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SSubjectCancel.banner, style: context.type(TypeTokens.bodyM)),
                if (when != null)
                  Text(
                    SSubjectCancel.since(fecha: DateFormat("d 'de' MMMM", 'es_CO').format(when)),
                    style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => toggleSubjectCancelled(context, ref, subject),
            child: const Text(SSubjectCancel.reactivate),
          ),
        ],
      ),
    );
  }
}
