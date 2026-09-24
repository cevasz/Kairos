import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/import/schedule_parser.dart';
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
import '../data/claude_schedule_parser.dart';
import 'widgets/parsed_session_sheet.dart';

/// Importar horario: A2 selector → A3 parseo → A4 confirmación, o A5 error.
///
/// Una sola ruta con cuatro vistas: el estado del controlador decide cuál se
/// ve y el `StateSwitcher` hace el cruce. Así «Probar con otro archivo» o
/// «Cancelar» no apilan pantallas.
class ImportPdfScreen extends ConsumerWidget {
  const ImportPdfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);

    // Guardado: se vuelve a la pantalla anterior. Las materias ya están en la
    // base y la lista las enseña sola.
    //
    // `pop`, no `maybePop`: este aviso llega antes de redibujar, cuando el
    // `PopScope` todavía tiene el `canPop: false` de «guardando». `maybePop` le
    // hacía caso, no cerraba, y la pantalla se quedaba girando con todo ya
    // guardado. Siempre se abre con `openImportPdf`, así que hay a dónde volver.
    ref.listen(importControllerProvider, (_, next) {
      if (next is ImportDone) Navigator.of(context).pop();
    });

    final title = switch (state) {
      ImportReview() => SPdfConfirm.title,
      _ => SPdfPicker.title,
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
                ImportExtracting(:final fileName) => _ParsingView(fileName: fileName),
                ImportParsing() => _ParsingView(fileName: state.fileName, parsing: state),
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

Future<void> openImportPdf(BuildContext context) => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ImportPdfScreen()),
    );

// ─────────────────────────────────────────────────────────────── A2

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
                    Icons.picture_as_pdf_outlined,
                    size: IconTokens.sizeXl * 2,
                    color: ColorTokens.accentPrimary.of(b),
                  ),
                  SizedBox(height: SpaceTokens.l),
                  Text(
                    SPdfPicker.dropzone,
                    textAlign: TextAlign.center,
                    style: context.type(TypeTokens.titleS),
                  ),
                  SizedBox(height: SpaceTokens.s),
                  Text(
                    SPdfPicker.hint,
                    textAlign: TextAlign.center,
                    style: context.type(TypeTokens.bodyM, color: ColorTokens.textSecondary.of(b)),
                  ),
                  SizedBox(height: SpaceTokens.xs),
                  Text(
                    SPdfPicker.otherFormats,
                    textAlign: TextAlign.center,
                    style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
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
          label: const Text(SPdfPicker.browse),
        ),
        SizedBox(height: SpaceTokens.xl),
        Text(
          // El pie dice la verdad según haya clave o no: sin clave nada sale
          // del teléfono; con clave, el texto va a la API y el archivo no.
          ClaudeScheduleParser.isConfigured ? SPdfPicker.footerApi : SPdfPicker.footer,
          textAlign: TextAlign.center,
          style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────── A3

class _ParsingView extends ConsumerWidget {
  const _ParsingView({required this.fileName, this.parsing});

  final String fileName;
  final ImportParsing? parsing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);
    final p = parsing;
    final found = p?.found ?? const <ParsedClass>[];

    final progress = p == null
        ? fileName
        : p.refining
            ? SPdfParsing.refining
            : SPdfParsing.progress(done: p.done, total: p.total);

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
                value: p == null || p.refining || p.total == 0 ? null : p.done / p.total,
                minHeight: BorderTokens.tabIndicator,
                backgroundColor: ColorTokens.surfaceRaised.of(b),
                color: ColorTokens.accentPrimary.of(b),
              ),
              SizedBox(height: SpaceTokens.xl),
              // Las filas entran en cascada con el escalonado del PDF, que es
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: ref.read(importControllerProvider.notifier).cancel,
                    child: const Text(SPdfParsing.cancel),
                  ),
                ),
                // Mientras Claude ordena, lo encontrado ya se puede revisar:
                // nadie tiene que quedarse mirando una barra indeterminada.
                if (p != null && p.refining) ...[
                  SizedBox(width: SpaceTokens.m),
                  Expanded(
                    child: FilledButton(
                      onPressed: ref.read(importControllerProvider.notifier).skipRefining,
                      child: const Text(SPdfParsing.skipRefine),
                    ),
                  ),
                ],
              ],
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
            item.nombre.isEmpty ? SPdfConfirm.lowConfidenceBadge : item.nombre,
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

// ─────────────────────────────────────────────────────────────── A4

class _ReviewView extends ConsumerWidget {
  const _ReviewView({required this.review});
  final ImportReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final ctrl = ref.read(importControllerProvider.notifier);
    final doubts = review.doubtCount;
    final subtitle = switch (doubts) {
      0 => SPdfConfirm.subtitleNone,
      1 => SPdfConfirm.subtitleOne,
      2 => SPdfConfirm.subtitle,
      _ => SPdfConfirm.subtitleMany(n: doubts),
    };
    final n = review.sessionCount;
    final confirmLabel = !review.canConfirm && n == 0
        ? SPdfConfirm.confirmNone
        : n == 1
            ? SPdfConfirm.confirmOne
            : SPdfConfirm.confirm(n: n);

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
                label: const Text(SPdfConfirm.addManual),
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

/// Una materia detectada, editable en sitio. Los campos son los del
/// formulario de materia; el horario se toca por chip.
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
                _Badge(text: SPdfConfirm.lowConfidenceBadge, color: attention),
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
                    labelText: SPdfConfirm.fieldProfesor,
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
                    labelText: SPdfConfirm.fieldSalon,
                    hintText: SSessionForm.hintSalon,
                  ),
                  onChanged: (v) => ctrl.setSalon(index, v),
                ),
              ),
            ],
          ),
          SizedBox(height: SpaceTokens.l),
          Text(
            SPdfConfirm.fieldDiasHora,
            style: context.type(TypeTokens.label, color: ColorTokens.textTertiary.of(b)),
          ),
          SizedBox(height: SpaceTokens.s),
          Wrap(
            spacing: SpaceTokens.s,
            runSpacing: SpaceTokens.s,
            children: [
              if (item.sessions.isEmpty)
                Text(
                  SPdfConfirm.sessionsNone,
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
                SPdfConfirm.removeClass,
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
        ParseDoubt.missingName => SPdfConfirm.doubtName,
        ParseDoubt.missingDays => SPdfConfirm.doubtDays,
        ParseDoubt.badRange => SPdfConfirm.doubtRange,
        ParseDoubt.nameFromPreviousLine => SPdfConfirm.doubtNamePrev,
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
            Text(SPdfConfirm.addSession, style: context.type(TypeTokens.captionS, color: color)),
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

// ─────────────────────────────────────────────────────────────── A5

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.reason});
  final ImportFailure reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final body = switch (reason) {
      ImportFailure.noText => SPdfError.body,
      ImportFailure.unreadable => SPdfError.bodyUnreadable,
      ImportFailure.nothingFound => SPdfError.bodyNothingFound,
      ImportFailure.saveFailed => SPdfError.bodySaveFailed,
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
          SPdfError.mascotLine,
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
          child: const Text(SPdfError.ctaManual),
        ),
        SizedBox(height: SpaceTokens.s),
        OutlinedButton(
          onPressed: ref.read(importControllerProvider.notifier).reset,
          child: const Text(SPdfError.ctaRetry),
        ),
        SizedBox(height: SpaceTokens.xl),
        Text(
          SPdfError.footer,
          textAlign: TextAlign.center,
          style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
        ),
      ],
    );
  }
}
