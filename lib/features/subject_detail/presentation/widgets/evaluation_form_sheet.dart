import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/numbers.dart';
import '../../../../core/providers.dart';
import '../../../../domain/grades/grades.dart' as domain;
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/haptics.dart';
import '../../../../theme/tokens.g.dart';
import '../../../mascot/application/mascot_voice.dart';

/// Alta y edición de una evaluación.
///
/// El porcentaje se escribe como lo dice el profe («30») y se guarda como
/// fracción (0.30): la fracción es lo que la calculadora necesita y evita
/// perder un 12,5 %.
Future<void> showEvaluationFormSheet(
  BuildContext context, {
  required int subjectId,
  domain.Evaluation? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _EvaluationForm(subjectId: subjectId, existing: existing),
    ),
  );
}

class _EvaluationForm extends ConsumerStatefulWidget {
  const _EvaluationForm({required this.subjectId, this.existing});

  final int subjectId;
  final domain.Evaluation? existing;

  @override
  ConsumerState<_EvaluationForm> createState() => _EvaluationFormState();
}

class _EvaluationFormState extends ConsumerState<_EvaluationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _porcentaje;
  late final TextEditingController _nota;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombre = TextEditingController(text: e?.name ?? '');
    _porcentaje =
        TextEditingController(text: e == null ? '' : Numbers.percent(e.weight));
    _nota = TextEditingController(
      text: e?.score == null ? '' : Numbers.grade(e!.score!),
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _porcentaje.dispose();
    _nota.dispose();
    super.dispose();
  }

  /// Acepta coma y punto: en Colombia se escribe «3,5» y el teclado numérico
  /// de Android ofrece punto. Rechazar cualquiera de los dos sería castigar al
  /// usuario por el teclado que le tocó.
  static double? _parse(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(subjectsDaoProvider).saveEvaluation(
          id: widget.existing == null ? null : int.parse(widget.existing!.id),
          subjectId: widget.subjectId,
          nombre: _nombre.text.trim(),
          porcentaje: _parse(_porcentaje.text)! / 100,
          nota: _nota.text.trim().isEmpty ? null : _parse(_nota.text),
        );
    ref.read(mascotCornerProvider.notifier).react(
      _nota.text.trim().isEmpty ? MascotReaction.saved : MascotReaction.grade,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final id = widget.existing?.id;
    if (id == null) return;
    Haptics.fire('confirmarDestructivo');
    await ref.read(subjectsDaoProvider).deleteEvaluation(int.parse(id));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(SpaceTokens.screenMargin),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null
                    ? SEvaluationForm.titleNew
                    : SEvaluationForm.titleEdit,
                style: context.type(TypeTokens.titleM),
              ),
              SizedBox(height: SpaceTokens.l),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: SEvaluationForm.fieldNombre,
                  hintText: SEvaluationForm.hintNombre,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? SEvaluationForm.errorNombre
                    : null,
              ),
              SizedBox(height: SpaceTokens.l),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _porcentaje,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: SEvaluationForm.fieldPorcentaje,
                        suffixText: '%',
                      ),
                      validator: (v) {
                        final n = _parse(v ?? '');
                        return (n == null || n <= 0 || n > 100)
                            ? SEvaluationForm.errorPorcentaje
                            : null;
                      },
                    ),
                  ),
                  SizedBox(width: SpaceTokens.l),
                  Expanded(
                    child: TextFormField(
                      controller: _nota,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: SEvaluationForm.fieldNota,
                      ),
                      validator: (v) {
                        final raw = (v ?? '').trim();
                        if (raw.isEmpty) return null;
                        final n = _parse(raw);
                        return (n == null ||
                                n < domain.kMinGrade ||
                                n > domain.kMaxGrade)
                            ? SEvaluationForm.errorNota
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: SpaceTokens.xs),
              Text(
                SEvaluationForm.hintNota,
                style: context.type(
                  TypeTokens.captionS,
                  color: ColorTokens.textTertiary.of(b),
                ),
              ),
              SizedBox(height: SpaceTokens.xl),
              FilledButton(
                onPressed: _save,
                child: const Text(SEvaluationForm.save),
              ),
              if (widget.existing != null) ...[
                SizedBox(height: SpaceTokens.s),
                OutlinedButton(
                  onPressed: _remove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorTokens.accentUrgent.of(b),
                    side: BorderSide(
                      color: ColorTokens.accentUrgent.of(b),
                      width: BorderTokens.hairline,
                    ),
                  ),
                  child: const Text(SEvaluationForm.remove),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
