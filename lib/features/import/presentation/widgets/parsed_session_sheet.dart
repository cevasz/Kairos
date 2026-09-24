import 'package:flutter/material.dart';

import '../../../../core/time/minutes_of_day.dart';
import '../../../../domain/import/schedule_parser.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.g.dart';
import '../../../subjects/presentation/widgets/session_fields.dart';

sealed class ParsedSessionResult {
  const ParsedSessionResult();
}

class ParsedSessionSaved extends ParsedSessionResult {
  const ParsedSessionSaved(this.session);
  final ParsedSession session;
}

class ParsedSessionRemoved extends ParsedSessionResult {
  const ParsedSessionRemoved();
}

/// Edita una sesión detectada antes de guardarla. Es el formulario de clase
/// sin base de datos: mismos chips, mismos campos de hora, pero devuelve el
/// valor en vez de escribirlo.
Future<ParsedSessionResult?> showParsedSessionSheet(
  BuildContext context, {
  ParsedSession? existing,
}) {
  return showModalBottomSheet<ParsedSessionResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Sheet(existing: existing),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({this.existing});
  final ParsedSession? existing;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late int _dia;
  late MinutesOfDay _inicio;
  late MinutesOfDay _fin;
  String? _error;

  /// Hora de arranque cuando no hay nada: la primera franja habitual de la
  /// mañana. Es un valor inicial del control, no una regla.
  static final _defaultStart = MinutesOfDay.of(8, 0);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _dia = (e != null && e.diaSemana >= 1 && e.diaSemana <= 7) ? e.diaSemana : 0;
    _inicio = e?.inicio ?? _defaultStart;
    _fin = e?.fin ?? _defaultStart.plus(120);
  }

  Future<void> _pick({required bool start}) async {
    final current = start ? _inicio : _fin;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    setState(() {
      final value = MinutesOfDay.of(picked.hour, picked.minute);
      if (start) {
        _inicio = value;
        if (_fin <= _inicio) _fin = _inicio.plus(60);
      } else {
        _fin = value;
      }
      _error = null;
    });
  }

  void _save() {
    if (_dia == 0) {
      setState(() => _error = SPdfConfirm.doubtDays);
      return;
    }
    if (_fin <= _inicio) {
      setState(() => _error = SSessionForm.errorOrder);
      return;
    }
    Navigator.of(context).pop(
      ParsedSessionSaved(ParsedSession(diaSemana: _dia, inicio: _inicio, fin: _fin)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(SpaceTokens.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? SSessionForm.titleNew : SPdfConfirm.editSession,
              style: context.type(TypeTokens.titleM),
            ),
            SizedBox(height: SpaceTokens.l),
            Text(
              SSessionForm.fieldDia,
              style: context.type(TypeTokens.label, color: ColorTokens.textTertiary.of(b)),
            ),
            SizedBox(height: SpaceTokens.s),
            Wrap(
              spacing: SpaceTokens.s,
              runSpacing: SpaceTokens.s,
              children: [
                for (var d = 1; d <= 7; d++)
                  DayChip(
                    label: SWeek.days[d - 1],
                    selected: d == _dia,
                    onTap: () => setState(() {
                      _dia = d;
                      _error = null;
                    }),
                  ),
              ],
            ),
            SizedBox(height: SpaceTokens.l),
            Row(
              children: [
                Expanded(
                  child: TimeField(
                    label: SSessionForm.fieldInicio,
                    value: _inicio,
                    onTap: () => _pick(start: true),
                  ),
                ),
                SizedBox(width: SpaceTokens.l),
                Expanded(
                  child: TimeField(
                    label: SSessionForm.fieldFin,
                    value: _fin,
                    onTap: () => _pick(start: false),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              SizedBox(height: SpaceTokens.m),
              Text(
                _error!,
                style: context.type(TypeTokens.captionS, color: ColorTokens.accentUrgent.of(b)),
              ),
            ],
            SizedBox(height: SpaceTokens.xl),
            FilledButton(onPressed: _save, child: const Text(SSessionForm.save)),
            if (widget.existing != null) ...[
              SizedBox(height: SpaceTokens.s),
              TextButton(
                onPressed: () => Navigator.of(context).pop(const ParsedSessionRemoved()),
                child: const Text(SPdfConfirm.removeSession),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
