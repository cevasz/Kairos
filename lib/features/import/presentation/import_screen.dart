import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/import/parsed_schedule.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/accent_card.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/cascade.dart';
import '../../../theme/layout.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.g.dart';
import '../../../theme/transitions.dart';
import '../../mascot/mascot_loader.dart';
import '../../mascot/mascot_view.dart';
import '../../subjects/presentation/subjects_screen.dart';
import '../application/import_controller.dart';
import 'widgets/parsed_session_sheet.dart';

/// Importar calendario: elegir el .ics → leerlo → revisar, o el error.
///
/// Una sola ruta con cuatro vistas: el estado del controlador decide cuál se
/// ve y el `StateSwitcher` hace el cruce. Así «Probar con otro archivo» o
/// «Cancelar» no apilan pantallas.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);

    // Guardado: se vuelve a la pantalla anterior. Las actividades ya están en
    // la base y la lista las enseña sola.
    //
    // `pop`, no `maybePop`: este aviso llega antes de redibujar, cuando el
    // `PopScope` todavía tiene el `canPop: false` de «guardando». `maybePop` le
    // hacía caso, no cerraba, y la pantalla se quedaba girando con todo ya
    // guardado. Siempre se abre con `openImport`, así que hay a dónde volver.
    ref.listen(importControllerProvider, (_, next) {
      if (next is ImportDone) Navigator.of(context).pop();
    });

    final title = switch (state) {
      ImportReview() => SImportConfirm.title,
      _ => SImportPicker.title,
    };

    return PopScope(
      canPop: state is! ImportParsing && state is! ImportSaving,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ContentWidth(
          child: StateSwitcher(
            rise: MotionOffsets.pdfRowRise,
            child: KeyedSubtree(
              key: ValueKey(state.runtimeType),
              child: switch (state) {
                ImportIdle() => const _PickerView(),
                ImportParsing() => _ParsingView(parsing: state),
                ImportReview() => _ReviewView(review: state),
                ImportSaving() || ImportDone() => const MascotLoader(),
                ImportFailed(:final reason) => _ErrorView(reason: reason),
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openImport(BuildContext context) => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ImportScreen()),
    );

// ─────────────────────────────────────────────────────────────── elegir

class _PickerView extends ConsumerWidget {
  const _PickerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final pick = ref.read(importControllerProvider.notifier).pick;

    return ListView(
      padding: EdgeInsets.all(SpaceTokens.screenMargin),
      children: [
        SizedBox(height: SpaceTokens.l),
        // La «zona de soltar» en móvil es un botón grande: se toca.
        Material(
          color: ColorTokens.surfaceCard.of(b),
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          child: InkWell(
            onTap: pick,
            borderRadius: BorderRadius.circular(RadiusTokens.card),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: SpaceTokens.xxxl,
                horizontal: SpaceTokens.xl,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(RadiusTokens.card),
                border: Border.all(color: ColorTokens.accentPrimary.of(b), width: BorderTokens.hairline),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: IconTokens.sizeXl * 2,
                    color: ColorTokens.accentPrimary.of(b),
                  ),
                  SizedBox(height: SpaceTokens.l),
                  Text(
                    SImportPicker.dropzone,
                    textAlign: TextAlign.center,
                    style: context.type(TypeTokens.titleS),
                  ),
                  SizedBox(height: SpaceTokens.s),
                  Text(
                    SImportPicker.hint,
                    textAlign: TextAlign.center,
                    style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: SpaceTokens.xl),
        FilledButton.icon(
          onPressed: pick,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text(SImportPicker.browse),
        ),
        SizedBox(height: SpaceTokens.xl),
        Text(
          SImportPicker.footer,
          textAlign: TextAlign.center,
          style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────── leer

class _ParsingView extends ConsumerWidget {
  const _ParsingView({required this.parsing});

  final ImportParsing parsing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);
    final p = parsing;
    final found = p.found;
    final progress = SImportParsing.progress(done: p.done, total: p.total);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(SpaceTokens.screenMargin),
            children: [
              SizedBox(height: SpaceTokens.l),
              Row(
                children: [
                  const MascotView(
                    pose: MascotPose.examinando,
                    size: MascotTokens.sizePdfParsing,
                    host: MascotHost.pdfParsing,
                  ),
                  SizedBox(width: SpaceTokens.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RotatingLine(
                          lines: SMascotVoice.parsingVariants,
                          style: context.type(TypeTokens.titleM),
                        ),
                        SizedBox(height: SpaceTokens.xs),
                        Text(
                          progress,
                          style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: SpaceTokens.m),
              LinearProgressIndicator(
                value: p.total == 0 ? null : p.done / p.total,
                minHeight: BorderTokens.tabIndicator,
                backgroundColor: ColorTokens.surfaceRaised.of(b),
                color: ColorTokens.accentPrimary.of(b),
              ),
              SizedBox(height: SpaceTokens.xl),
              // Las filas entran en cascada con el escalonado del importador,
              // el doble de lento que el de la timeline: aquí sí hay tiempo.
              for (var i = 0; i < found.length; i++)
                CascadeIn(
                  key: ValueKey('found-$i'),
                  index: i,
                  guard: guard,
                  step: MotionStagger.pdfRows,
                  rise: MotionOffsets.pdfRowRise,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: SpaceTokens.s),
                    child: _FoundRow(item: found[i], index: i),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(SpaceTokens.screenMargin),
            child: OutlinedButton(
              onPressed: ref.read(importControllerProvider.notifier).cancel,
              child: const Text(SImportParsing.cancel),
            ),
          ),
        ),
      ],
    );
  }
}

/// Una fila detectada, en su versión de solo lectura: nombre, días y horas.
class _FoundRow extends StatelessWidget {
  const _FoundRow({required this.item, required this.index});
  final ParsedClass item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = SubjectPalette.at(index);
    return Container(
      padding: EdgeInsets.all(SpaceTokens.m),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceCard.of(b),
        borderRadius: BorderRadius.circular(RadiusTokens.card),
        border: Border(left: BorderSide(color: accent, width: BorderTokens.subjectAccent)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.nombre.isEmpty ? SImportConfirm.lowConfidenceBadge : item.nombre,
            style: context.type(
              TypeTokens.bodyS,
              color: item.nombre.isEmpty ? ColorTokens.accentAttention.of(b) : null,
            ),
          ),
          SizedBox(height: SpaceTokens.xs / 2),
          Text(
            [
              ...item.sessions.map(sessionLabel),
              if (item.salon != null) item.salon!,
            ].join(' · '),
            style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
          ),
        ],
      ),
    );
  }
}

/// «mar · 10:00–12:00». Un día fuera de 1–7 se enseña con la insignia en vez
/// de reventar el índice.
String sessionLabel(ParsedSession s) {
  final dia = s.diaSemana >= 1 && s.diaSemana <= 7 ? SWeek.days[s.diaSemana - 1] : '?';
  return SSessionForm.summary(dia: dia, inicio: s.inicio.hhmm, fin: s.fin.hhmm);
}

// ─────────────────────────────────────────────────────────────── revisar

class _ReviewView extends ConsumerWidget {
  const _ReviewView({required this.review});
  final ImportReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final ctrl = ref.read(importControllerProvider.notifier);
    final doubts = review.doubtCount;
    final subtitle = switch (doubts) {
      0 => SImportConfirm.subtitleNone,
      1 => SImportConfirm.subtitleOne,
      2 => SImportConfirm.subtitle,
      _ => SImportConfirm.subtitleMany(n: doubts),
    };
    final n = review.sessionCount;
    final confirmLabel = !review.canConfirm && n == 0
        ? SImportConfirm.confirmNone
        : n == 1
            ? SImportConfirm.confirmOne
            : SImportConfirm.confirm(n: n);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(SpaceTokens.screenMargin),
            children: [
              Text(
                subtitle,
                style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
              ),
              SizedBox(height: SpaceTokens.l),
              for (var i = 0; i < review.classes.length; i++) ...[
                _ClassCard(
                  key: ValueKey('import-${review.ids[i]}'),
                  index: i,
                  item: review.classes[i],
                ),
                SizedBox(height: SpaceTokens.cardGap),
              ],
              OutlinedButton.icon(
                onPressed: () => openSubjectForm(context),
                icon: const Icon(Icons.add),
                label: const Text(SImportConfirm.addManual),
              ),
              SizedBox(height: SpaceTokens.xxxl),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(SpaceTokens.screenMargin),
            child: FilledButton(
              onPressed: review.canConfirm ? ctrl.confirm : null,
              child: Text(confirmLabel),
            ),
          ),
        ),
      ],
    );
  }
}

/// Una actividad leída, editable en sitio. Los campos son los del
/// formulario de actividad; el horario se toca por chip.
class _ClassCard extends ConsumerWidget {
  const _ClassCard({required this.index, required this.item, super.key});

  final int index;
  final ParsedClass item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final ctrl = ref.read(importControllerProvider.notifier);
    final accent = SubjectPalette.at(index);
    final attention = ColorTokens.accentAttention.of(b);

    return AccentCard(
      accent: accent,
      color: ColorTokens.surfaceCard.of(b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.isLowConfidence) ...[
            Row(
              children: [
                _Badge(text: SImportConfirm.lowConfidenceBadge, color: attention),
                SizedBox(width: SpaceTokens.s),
                Expanded(
                  child: Text(
                    item.doubts.map(_doubtText).join(' '),
                    style: context.type(TypeTokens.captionS, color: attention),
                  ),
                ),
              ],
            ),
            SizedBox(height: SpaceTokens.m),
          ],
          TextFormField(
            initialValue: item.nombre,
            style: context.type(TypeTokens.bodyL),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: SSubjectForm.fieldNombre,
              hintText: SSubjectForm.hintNombre,
              errorText: item.nombre.trim().isEmpty ? SSubjectForm.errorNombre : null,
            ),
            onChanged: (v) => ctrl.setName(index, v),
          ),
          SizedBox(height: SpaceTokens.m),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.profesor ?? '',
                  style: context.type(TypeTokens.bodyM),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: SImportConfirm.fieldProfesor,
                    hintText: SSubjectForm.hintProfesor,
                  ),
                  onChanged: (v) => ctrl.setProfesor(index, v),
                ),
              ),
              SizedBox(width: SpaceTokens.m),
              Expanded(
                child: TextFormField(
                  initialValue: item.salon ?? '',
                  style: context.type(TypeTokens.bodyM),
                  decoration: const InputDecoration(
                    labelText: SImportConfirm.fieldSalon,
                    hintText: SSessionForm.hintSalon,
                  ),
                  onChanged: (v) => ctrl.setSalon(index, v),
                ),
              ),
            ],
          ),
          SizedBox(height: SpaceTokens.l),
          Text(
            SImportConfirm.fieldDiasHora,
            style: context.type(TypeTokens.label, color: ColorTokens.textTertiary.of(b)),
          ),
          SizedBox(height: SpaceTokens.s),
          Wrap(
            spacing: SpaceTokens.s,
            runSpacing: SpaceTokens.s,
            children: [
              if (item.sessions.isEmpty)
                Text(
                  SImportConfirm.sessionsNone,
                  style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
                ),
              for (var j = 0; j < item.sessions.length; j++)
                _SessionChip(
                  session: item.sessions[j],
                  onTap: () => _editSession(context, ref, j),
                ),
              _AddChip(onTap: () => _editSession(context, ref, item.sessions.length)),
            ],
          ),
          SizedBox(height: SpaceTokens.s),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => ctrl.removeClass(index),
              child: Text(
                SImportConfirm.removeClass,
                style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSession(BuildContext context, WidgetRef ref, int j) async {
    final ctrl = ref.read(importControllerProvider.notifier);
    final existing = j < item.sessions.length ? item.sessions[j] : null;
    final result = await showParsedSessionSheet(context, existing: existing);
    if (result == null) return;
    switch (result) {
      case ParsedSessionSaved(:final session):
        ctrl.setSession(index, j, session);
      case ParsedSessionRemoved():
        if (existing != null) ctrl.removeSession(index, j);
    }
  }

  static String _doubtText(ParseDoubt d) => switch (d) {
        ParseDoubt.missingName => SImportConfirm.doubtName,
        ParseDoubt.missingDays => SImportConfirm.doubtDays,
        ParseDoubt.badRange => SImportConfirm.doubtRange,
      };
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.session, required this.onTap});
  final ParsedSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bad = session.diaSemana < 1 || session.diaSemana > 7 || session.fin <= session.inicio;
    final color = bad ? ColorTokens.accentAttention.of(b) : ColorTokens.textPrimary.of(b);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.control),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ComponentTokens.chipPaddingV,
          horizontal: ComponentTokens.chipPaddingH,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RadiusTokens.control),
          border: Border.all(
            color: bad ? color : ColorTokens.surfaceBorder.of(b),
            width: BorderTokens.hairline,
          ),
        ),
        child: Text(sessionLabel(session), style: context.type(TypeTokens.captionS, color: color)),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final color = ColorTokens.accentPrimary.of(b);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.control),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: ComponentTokens.chipPaddingV,
          horizontal: ComponentTokens.chipPaddingH,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RadiusTokens.control),
          border: Border.all(color: color, width: BorderTokens.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: IconTokens.sizeXs, color: color),
            SizedBox(width: SpaceTokens.xs),
            Text(SImportConfirm.addSession, style: context.type(TypeTokens.captionS, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
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

// ─────────────────────────────────────────────────────────────── error

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.reason});
  final ImportFailure reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final body = switch (reason) {
      ImportFailure.notCalendar => SImportError.bodyNotCalendar,
      ImportFailure.unreadable => SImportError.bodyUnreadable,
      ImportFailure.nothingFound => SImportError.bodyNothingFound,
      ImportFailure.saveFailed => SImportError.bodySaveFailed,
    };

    return ListView(
      padding: EdgeInsets.all(LayoutTokens.screenPaddingHHero),
      children: [
        SizedBox(height: SpaceTokens.xxl),
        const Center(
          child: MascotView(
            pose: MascotPose.confundido,
            size: MascotTokens.sizePdfError,
            host: MascotHost.pdfError,
            // Entra tropezando: algo falló, sin dramatizar.
            beat: MascotBeat.stumble,
          ),
        ),
        SizedBox(height: SpaceTokens.xl),
        Text(
          SImportError.mascotLine,
          textAlign: TextAlign.center,
          style: context.type(TypeTokens.titleM),
        ),
        SizedBox(height: SpaceTokens.s),
        Text(
          body,
          textAlign: TextAlign.center,
          style: context.type(TypeTokens.bodyL, color: ColorTokens.textSecondary.of(b)),
        ),
        SizedBox(height: SpaceTokens.xxl),
        FilledButton(
          onPressed: () async {
            await openSubjectForm(context);
            if (context.mounted) Navigator.of(context).maybePop();
          },
          child: const Text(SImportError.ctaManual),
        ),
        SizedBox(height: SpaceTokens.s),
        OutlinedButton(
          onPressed: ref.read(importControllerProvider.notifier).reset,
          child: const Text(SImportError.ctaRetry),
        ),
        SizedBox(height: SpaceTokens.xl),
        Text(
          SImportError.footer,
          textAlign: TextAlign.center,
          style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
        ),
      ],
    );
  }
}
