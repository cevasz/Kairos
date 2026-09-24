import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/daos/subjects_dao.dart';
import '../../../../core/providers.dart';
import '../../../../core/time/minutes_of_day.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/tokens.g.dart';
import 'session_fields.dart';

/// Alta y edición de una clase recurrente.
///
/// Abrir un sheet no vibra: `aperturaDeSheet` está en la lista `never` del
/// contrato háptico.
Future<void> showSessionFormSheet(
  BuildContext context, {
  required int subjectId,
  SessionWithRoom? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      // El inset del teclado se lee del contexto del sheet, no del de quien lo
      // abre: solo el primero cambia cuando el teclado sube.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _SessionForm(subjectId: subjectId, existing: existing),
    ),
  );
}

class _SessionForm extends ConsumerStatefulWidget {
  const _SessionForm({required this.subjectId, this.existing});

  final int subjectId;
  final SessionWithRoom? existing;

  @override
  ConsumerState<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends ConsumerState<_SessionForm> {
  late int _dia;
  late MinutesOfDay _inicio;
  late MinutesOfDay _fin;
  late final TextEditingController _salon;
  late final TextEditingController _edificio;

  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.existing?.session;
    // Lunes 7:00–9:00 como punto de partida de un alta: es el bloque más común
    // de una jornada universitaria colombiana y se cambia en dos toques.
    _dia = s?.diaSemana ?? DateTime.monday;
    _inicio = MinutesOfDay(s?.horaInicio ?? MinutesOfDay.of(7, 0).raw);
    _fin = MinutesOfDay(s?.horaFin ?? MinutesOfDay.of(9, 0).raw);
    _salon = TextEditingController(text: widget.existing?.room?.codigo ?? '');
    _edificio = TextEditingController(text: widget.existing?.room?.edificio ?? '');
  }

  @override
  void dispose() {
    _salon.dispose();
    _edificio.dispose();
    super.dispose();
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
        // Mover el inicio por delante del fin dejaría una clase de duración
        // negativa. Se arrastra el fin en vez de rechazar el gesto.
        if (_fin <= _inicio) _fin = _inicio.plus(60);
      } else {
        _fin = value;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_fin <= _inicio) {
      setState(() => _error = SSessionForm.errorOrder);
      return;
    }
    final dao = ref.read(subjectsDaoProvider);
    final roomId = await dao.ensureRoom(
      codigo: _salon.text,
      edificio: _edificio.text,
    );
    await dao.saveSession(
      id: widget.existing?.session.id,
      subjectId: widget.subjectId,
      diaSemana: _dia,
      horaInicio: _inicio.raw,
      horaFin: _fin.raw,
      roomId: roomId,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final id = widget.existing?.session.id;
    if (id == null) return;
    await ref.read(subjectsDaoProvider).deleteSession(id);
    if (mounted) Navigator.of(context).pop();
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
              widget.existing == null
                  ? SSessionForm.titleNew
                  : SSessionForm.titleEdit,
              style: context.type(TypeTokens.titleM),
            ),
            SizedBox(height: SpaceTokens.l),

            Text(
              SSessionForm.fieldDia,
              style: context.type(
                TypeTokens.label,
                color: ColorTokens.textTertiary.of(b),
              ),
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
                    onTap: () => setState(() => _dia = d),
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
              SizedBox(height: SpaceTokens.s),
              Text(
                _error!,
                style: context.type(
                  TypeTokens.captionS,
                  color: ColorTokens.accentUrgent.of(b),
                ),
              ),
            ],
            SizedBox(height: SpaceTokens.l),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _salon,
                    decoration: const InputDecoration(
                      labelText: SSessionForm.fieldSalon,
                      hintText: SSessionForm.hintSalon,
                    ),
                  ),
                ),
                SizedBox(width: SpaceTokens.l),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _edificio,
                    decoration: const InputDecoration(
                      labelText: SSessionForm.fieldEdificio,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: SpaceTokens.xl),

            FilledButton(
              onPressed: _save,
              child: const Text(SSessionForm.save),
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
                child: const Text(SSessionForm.remove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
