import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/numbers.dart';
import '../../../domain/grades/grades.dart' as domain;
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.g.dart';
import '../../subject_detail/application/subject_detail_providers.dart';

/// La calculadora inversa: «¿qué necesito en lo que falta para cerrar en 3,5?».
///
/// `necesito = (meta − puntos_asegurados) / peso_pendiente`. El prototipo
/// enseña cifras escogidas a mano que no salen de esta fórmula; se implementa
/// la fórmula. Ver DESIGN_DECISIONS.md, «Los números de la calculadora del
/// prototipo no son consistentes».
///
/// Sin mascota, en ningún estado. Cuando la calculadora dice que no da, un
/// erizo simpático se lee como burla.
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({required this.subjectId, super.key});

  final int subjectId;

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  /// Empieza en 3,0: pasar es la pregunta que se hace primero.
  double _target = domain.TargetCalculator.presetTargets.first;

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(subjectDetailProvider(widget.subjectId)).valueOrNull;
    if (state == null) {
      return Scaffold(appBar: AppBar(title: const Text(SCalculator.title)));
    }

    final result = domain.TargetCalculator.required(
      evaluations: state.evaluations,
      target: _target,
    );

    return Scaffold(
      appBar: AppBar(title: const Text(SCalculator.title)),
      body: ContentWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            SpaceTokens.screenMargin,
            SpaceTokens.l,
            SpaceTokens.screenMargin,
            SpaceTokens.xxxl,
          ),
          children: [
            _TargetPicker(
              selected: _target,
              onChanged: (v) => setState(() => _target = v),
            ),
            SizedBox(height: SpaceTokens.xl),
            _Pending(result: result),
            SizedBox(height: SpaceTokens.l),
            _Result(result: result, evaluations: state.evaluations),
            SizedBox(height: SpaceTokens.xl),
            _OtherTargets(
              evaluations: state.evaluations,
              current: _target,
              onPick: (v) => setState(() => _target = v),
            ),
            SizedBox(height: SpaceTokens.xl),
            _Current(state: state),
            if (state.detail.subject.fechaLimiteCancelacion != null) ...[
              SizedBox(height: SpaceTokens.l),
              _WithdrawDeadline(
                  date: state.detail.subject.fechaLimiteCancelacion!),
            ],
            SizedBox(height: SpaceTokens.xl),
            Text(
              SCalculator.editAdvice,
              style: context.type(
                TypeTokens.captionS,
                color: context.themed(ColorTokens.textTertiary),
              ),
            ),
            SizedBox(height: SpaceTokens.m),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(SCalculator.backToSubject),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetPicker extends StatelessWidget {
  const _TargetPicker({required this.selected, required this.onChanged});

  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SCalculator.targetLabel,
          style: context.type(
            TypeTokens.label,
            color: ColorTokens.textTertiary.of(b),
          ),
        ),
        SizedBox(height: SpaceTokens.m),
        Wrap(
          spacing: SpaceTokens.s,
          children: [
            for (final t in domain.TargetCalculator.presetTargets)
              _TargetChip(
                label: Numbers.grade(t),
                selected: (t - selected).abs() < 0.001,
                onTap: () => onChanged(t),
              ),
            _TargetChip(
              label: SCalculator.targetOther,
              selected: !domain.TargetCalculator.presetTargets
                  .any((t) => (t - selected).abs() < 0.001),
              onTap: () => _askCustom(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _askCustom(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(SCalculator.targetLabel),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(SSubjectForm.cancel),
          ),
          TextButton(
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.of(context).pop(parsed);
            },
            child: const Text(SSubjectForm.save),
          ),
        ],
      ),
    );
    if (value != null &&
        value >= domain.kMinGrade &&
        value <= domain.kMaxGrade) {
      onChanged(value);
    }
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final color = selected
        ? ColorTokens.accentPrimary.of(b)
        : ColorTokens.textTertiary.of(b);

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
            color: selected ? color : ColorTokens.surfaceBorder.of(b),
            width: BorderTokens.hairline,
          ),
        ),
        child:
            Text(label, style: context.type(TypeTokens.captionS, color: color)),
      ),
    );
  }
}

/// «Te falta el Parcial 2 con 30 %.» El prototipo distingue el caso de una sola
/// evaluación pendiente del resto, así que aquí también.
class _Pending extends StatelessWidget {
  const _Pending({required this.result});

  final domain.RequiredGrade result;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (result.pendingNames.isEmpty) return const SizedBox.shrink();

    final text = result.pendingNames.length == 1
        ? SCalculator.remainingOne(
            nombre: result.pendingNames.single,
            pct: Numbers.percent(result.remainingWeight),
          )
        : SCalculator.remainingNamed(
            nombre: result.pendingNames.join(', '),
            pct: Numbers.percent(result.remainingWeight),
          );

    return Text(
      text,
      style: context.type(
        TypeTokens.bodyM,
        color: ColorTokens.textSecondary.of(b),
      ),
    );
  }
}

/// El número grande. Cambia de color a urgente en 600 ms cuando la meta deja de
/// ser alcanzable: es la misma transición que el anillo de la cuenta regresiva.
class _Result extends StatelessWidget {
  const _Result({required this.result, required this.evaluations});

  final domain.RequiredGrade result;
  final List<domain.Evaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final guard = MotionGuard.of(context);
    final impossible = result.verdict == domain.TargetVerdict.impossible;

    final color = impossible
        ? ColorTokens.accentUrgent.of(b)
        : ColorTokens.textPrimary.of(b);

    if (result.verdict == domain.TargetVerdict.nothingLeft) {
      return Text(
        SCalculator.scaleNote(pct: Numbers.percent(1 - result.remainingWeight)),
        style: context.type(
          TypeTokens.bodyM,
          color: ColorTokens.textSecondary.of(b),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedDefaultTextStyle(
              duration: guard.duration(MotionDurations.urgentShift),
              curve: guard.curve(MotionCurves.easeOutCubic),
              style: context.type(TypeTokens.displayL, color: color),
              child: AnimatedSwitcher(
                duration: guard.duration(MotionDurations.base),
                child: Text(
                  impossible
                      ? SCalculator.impossibleShort
                      : Numbers.grade(result.needed),
                  key: ValueKey('${result.target}-$impossible'),
                ),
              ),
            ),
            SizedBox(width: SpaceTokens.m),
            Expanded(
              child: Text(
                impossible
                    ? SCalculator.impossibleTail
                    : SCalculator.resultLead,
                style: context.type(
                  TypeTokens.bodyM,
                  color: ColorTokens.textSecondary.of(b),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: SpaceTokens.s),
        if (!impossible)
          Text(
            SCalculator.resultTail(meta: Numbers.grade(result.target)),
            style: context.type(
              TypeTokens.bodyM,
              color: ColorTokens.textSecondary.of(b),
            ),
          ),
        SizedBox(height: SpaceTokens.m),
        if (impossible)
          // Sin mascota y sin adornos: el consejo es hablar con el profe.
          Text(
            SCalculator.impossibleAdvice,
            style: context.type(
              TypeTokens.bodyM,
              color: ColorTokens.accentUrgent.of(b),
            ),
          )
        // «Aprieta» y «no da» son dos estados distintos con dos mensajes
        // distintos: el primero es posible, el segundo no. El veredicto ya los
        // separa, así que la pantalla no vuelve a decidirlo.
        else if (result.verdict == domain.TargetVerdict.demanding)
          Text(
            SCalculator.demanding,
            style: context.type(
              TypeTokens.bodyM,
              color: ColorTokens.accentAttention.of(b),
            ),
          )
        else if (result.verdict == domain.TargetVerdict.alreadySecured ||
            domain.TargetCalculator.isWithinPastPerformance(
              evaluations: evaluations,
              needed: result.needed,
            ))
          Text(
            SCalculator.reachable,
            style: context.type(
              TypeTokens.bodyM,
              color: ColorTokens.accentOk.of(b),
            ),
          ),
      ],
    );
  }
}

class _OtherTargets extends StatelessWidget {
  const _OtherTargets({
    required this.evaluations,
    required this.current,
    required this.onPick,
  });

  final List<domain.Evaluation> evaluations;
  final double current;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final others = domain.TargetCalculator.presetTargets
        .where((t) => (t - current).abs() >= 0.001)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SCalculator.otherTargetsLabel,
          style: context.type(
            TypeTokens.label,
            color: ColorTokens.textTertiary.of(b),
          ),
        ),
        SizedBox(height: SpaceTokens.m),
        for (final t in others)
          _OtherTargetRow(
            target: t,
            result: domain.TargetCalculator.required(
              evaluations: evaluations,
              target: t,
            ),
            onTap: () => onPick(t),
          ),
      ],
    );
  }
}

class _OtherTargetRow extends StatelessWidget {
  const _OtherTargetRow({
    required this.target,
    required this.result,
    required this.onTap,
  });

  final double target;
  final domain.RequiredGrade result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final impossible = result.verdict == domain.TargetVerdict.impossible;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.control),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpaceTokens.m),
        child: Row(
          children: [
            Expanded(
              child: Text(
                SCalculator.targetRow(meta: Numbers.grade(target)),
                style: context.type(TypeTokens.bodyS),
              ),
            ),
            // En esta fila el número es la información, así que una meta
            // exigente lo conserva y dice su estado con color. Solo la
            // imposible lo reemplaza, porque ahí el número ya no significa
            // nada alcanzable.
            Text(
              impossible
                  ? SCalculator.impossibleShort
                  : Numbers.grade(result.needed),
              style: context.type(
                TypeTokens.bodyS,
                color: switch (result.verdict) {
                  domain.TargetVerdict.impossible =>
                    ColorTokens.accentUrgent.of(b),
                  domain.TargetVerdict.demanding =>
                    ColorTokens.accentAttention.of(b),
                  _ => ColorTokens.textPrimary.of(b),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Lo que hay hasta ahora»: las notas ya puestas, para poder revisarlas sin
/// salir de la calculadora.
class _Current extends StatelessWidget {
  const _Current({required this.state});

  final SubjectDetailState state;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final graded = state.evaluations.where((e) => e.isGraded).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SCalculator.currentLabel,
          style: context.type(
            TypeTokens.label,
            color: ColorTokens.textTertiary.of(b),
          ),
        ),
        SizedBox(height: SpaceTokens.m),
        for (final e in graded)
          Padding(
            padding: EdgeInsets.only(bottom: SpaceTokens.s),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${e.name} · ${Numbers.percent(e.weight)} %',
                    style: context.type(
                      TypeTokens.captionS,
                      color: ColorTokens.textSecondary.of(b),
                    ),
                  ),
                ),
                Text(
                  Numbers.grade(e.score!),
                  style: context.type(TypeTokens.bodyS),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La fecha límite para cancelar la materia. Es un dato con caducidad: enseñarlo
/// tarde no sirve de nada, y esta pantalla es justo donde la decisión se toma.
class _WithdrawDeadline extends StatelessWidget {
  const _WithdrawDeadline({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Text(
        SCalculator.withdrawDeadline(
          fecha: DateFormat("d 'de' MMMM", 'es_CO').format(date),
        ),
        style: context.type(
          TypeTokens.captionS,
          color: context.themed(ColorTokens.accentAttention),
        ),
      );
}
