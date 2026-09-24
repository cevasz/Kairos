import 'package:flutter/material.dart';

import '../../../../core/format/numbers.dart';
import '../../../../domain/grades/grades.dart' as domain;
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/cascade.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/tokens.g.dart';
import '../../../calculator/presentation/calculator_screen.dart';
import '../../../mascot/mascot_view.dart';
import '../../application/subject_detail_providers.dart';
import 'evaluation_form_sheet.dart';

/// Pestaña Notas: la acumulada, la proyección y las evaluaciones.
///
/// La acumulada es `earned / gradedWeight`, no un promedio simple: con el 70 %
/// calificado, dividir entre el número de notas mentiría.
class GradesTab extends StatelessWidget {
  const GradesTab({required this.state, super.key});

  final SubjectDetailState state;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);

    if (state.evaluations.isEmpty) {
      return _EmptyGrades(subjectId: state.detail.subject.id);
    }

    final summary = state.grades;
    final pending = state.evaluations.where((e) => !e.isGraded).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpaceTokens.screenMargin,
        SpaceTokens.l,
        SpaceTokens.screenMargin,
        SpaceTokens.xxxl,
      ),
      children: [
        Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    state.hasGrades ? Numbers.grade(summary.accumulated) : '—',
                    style: context.type(TypeTokens.displayL),
                  ),
                  SizedBox(width: SpaceTokens.s),
                  Text(
                    SGrades.outOf,
                    style: context.type(
                      TypeTokens.bodyM,
                      color: ColorTokens.textTertiary.of(b),
                    ),
                  ),
                ],
              ),
              SizedBox(height: SpaceTokens.xs),
              Text(
                SGrades.accumulated(pct: Numbers.percent(summary.gradedWeight)),
                style: context.type(
                  TypeTokens.captionS,
                  color: ColorTokens.textTertiary.of(b),
                ),
              ),
              if (state.hasGrades && !summary.isComplete) ...[
                SizedBox(height: SpaceTokens.s),
                Text(
                  '${SGrades.projection} ${Numbers.grade(summary.projection)}',
                  style: context.type(
                    TypeTokens.bodyS,
                    color: ColorTokens.textSecondary.of(b),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (!state.weightsAreComplete) ...[
          SizedBox(height: SpaceTokens.l),
          _WeightsWarning(total: state.totalWeight),
        ],

        SizedBox(height: SpaceTokens.xl),
        Text(
          SGrades.evaluationsLabel,
          style: context.type(
            TypeTokens.label,
            color: ColorTokens.textTertiary.of(b),
          ),
        ),
        SizedBox(height: SpaceTokens.m),
        for (var i = 0; i < state.evaluations.length; i++)
          CascadeIn(
            index: i,
            guard: guard,
            child: _EvaluationRow(
              evaluation: state.evaluations[i],
              onTap: () => showEvaluationFormSheet(
                context,
                subjectId: state.detail.subject.id,
                existing: state.evaluations[i],
              ),
            ),
          ),

        SizedBox(height: SpaceTokens.l),
        OutlinedButton.icon(
          onPressed: () => showEvaluationFormSheet(
            context,
            subjectId: state.detail.subject.id,
          ),
          icon: const Icon(Icons.add),
          label: const Text(SGrades.addEvaluation),
        ),

        if (pending.isNotEmpty) ...[
          SizedBox(height: SpaceTokens.m),
          FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CalculatorScreen(subjectId: state.detail.subject.id),
              ),
            ),
            child: Text(SGrades.openCalculator(evaluacion: pending.last.name)),
          ),
        ],
      ],
    );
  }
}

class _EvaluationRow extends StatelessWidget {
  const _EvaluationRow({required this.evaluation, required this.onTap});

  final domain.Evaluation evaluation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.control),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpaceTokens.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(evaluation.name, style: context.type(TypeTokens.bodyS)),
                  SizedBox(height: SpaceTokens.xs / 2),
                  Text(
                    '${Numbers.percent(evaluation.weight)} %',
                    style: context.type(
                      TypeTokens.captionS,
                      color: ColorTokens.textTertiary.of(b),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              evaluation.isGraded
                  ? Numbers.grade(evaluation.score!)
                  : SGrades.pending,
              style: context.type(
                evaluation.isGraded ? TypeTokens.titleS : TypeTokens.captionS,
                color: evaluation.isGraded
                    ? ColorTokens.textPrimary.of(b)
                    : ColorTokens.textTertiary.of(b),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los porcentajes que no suman 100 % cambian cómo se lee la acumulada, así que
/// se dice en voz alta en vez de dejar que el número mienta en silencio.
class _WeightsWarning extends StatelessWidget {
  const _WeightsWarning({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final over = total > 1.0;
    final pct = Numbers.percent(total);

    return Container(
      padding: EdgeInsets.all(SpaceTokens.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RadiusTokens.control),
        border: Border.all(
          color: ColorTokens.accentAttention.of(b),
          width: BorderTokens.hairline,
        ),
      ),
      child: Text(
        over
            ? SEvaluationForm.weightsOver(pct: pct)
            : SEvaluationForm.weightsIncomplete(pct: pct),
        style: context.type(
          TypeTokens.captionS,
          color: ColorTokens.accentAttention.of(b),
        ),
      ),
    );
  }
}

/// D3 «materia sin notas». Es una de las pantallas donde el contrato permite a
/// Erizógenes aparecer, y a 104 px, que es la medida que el diseño usó.
class _EmptyGrades extends StatelessWidget {
  const _EmptyGrades({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutTokens.screenPaddingHHero),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotView(
              pose: MascotPose.examinando,
              size: MascotTokens.sizeEmptyGrades,
              host: MascotHost.emptyGrades,
            ),
            SizedBox(height: SpaceTokens.l),
            Text(SEmptyGrades.mascotLine, style: context.type(TypeTokens.titleM)),
            SizedBox(height: SpaceTokens.s),
            Text(
              SEmptyGrades.body,
              textAlign: TextAlign.center,
              style: context.type(
                TypeTokens.bodyM,
                color: ColorTokens.textSecondary.of(b),
              ),
            ),
            SizedBox(height: SpaceTokens.xl),
            FilledButton(
              onPressed: () => showEvaluationFormSheet(context, subjectId: subjectId),
              child: const Text(SEmptyGrades.cta),
            ),
          ],
        ),
      ),
    );
  }
}
