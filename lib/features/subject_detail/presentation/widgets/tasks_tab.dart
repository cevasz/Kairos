import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/database.dart';
import '../../../../core/providers.dart';
import '../../../../l10n/strings.g.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/haptics.dart';
import '../../../../theme/motion.dart';
import '../../../../theme/strike_through.dart';
import '../../../../theme/tokens.g.dart';
import '../../../mascot/application/mascot_voice.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../application/subject_detail_providers.dart';
import 'check_mark.dart';

/// Pendientes de una actividad: lo que hay que hacer o llevar, con fecha si
/// la tiene. Se tachan al hacerlos.
class TasksTab extends ConsumerWidget {
  const TasksTab({required this.state, super.key});

  final SubjectDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectId = state.detail.subject.id;
    final tasks = ref.watch(subjectTasksProvider(subjectId)).valueOrNull ?? const <Task>[];
    final today = ref.watch(todayProvider);

    final add = FilledButton.icon(
      onPressed: () => showTaskFormSheet(context, subjectId: subjectId),
      icon: const Icon(Icons.add),
      label: const Text(STasks.add),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        SpaceTokens.screenMargin,
        SpaceTokens.l,
        SpaceTokens.screenMargin,
        SpaceTokens.xxxl,
      ),
      children: [
        if (tasks.isEmpty) ...[
          SizedBox(height: SpaceTokens.xl),
          Text(
            STasks.empty,
            textAlign: TextAlign.center,
            style: context.type(TypeTokens.bodyM, color: context.themed(ColorTokens.textSecondary)),
          ),
          SizedBox(height: SpaceTokens.xl),
        ],
        if (tasks.isNotEmpty) ...[
          for (final t in tasks) _TaskRow(key: ValueKey(t.id), task: t, today: today),
          SizedBox(height: SpaceTokens.l),
        ],
        add,
      ],
    );
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// «para hoy», «para mañana», «para el jue 9 oct».
String dueLabel(DateTime due, DateTime today) {
  final d = _day(due);
  if (d == today) return STasks.dueToday;
  if (d == today.add(const Duration(days: 1))) return STasks.dueTomorrow;
  return STasks.due(dia: DateFormat('EEE d MMM', 'es_CO').format(d));
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.today, super.key});

  final Task task;
  final DateTime today;

  Future<void> _toggle(WidgetRef ref) async {
    final done = !task.hecha;
    if (done) Haptics.fire('marcarAsistencia');
    await ref.read(tasksDaoProvider).setDone(task.id, done: done);
    if (done) ref.read(mascotCornerProvider.notifier).react(MascotReaction.taskDone);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(tasksDaoProvider);
    final messenger = ScaffoldMessenger.of(context);
    Haptics.fire('confirmarDestructivo');
    await dao.deleteTask(task.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text(STasks.deleted),
        action: SnackBarAction(label: STasks.undo, onPressed: () => dao.restoreTask(task)),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = Theme.of(context).brightness;
    final due = task.fecha;
    final overdue = !task.hecha && due != null && _day(due).isBefore(today);
    final meta = due == null ? null : (overdue ? STasks.overdue : dueLabel(due, today));

    return InkWell(
      onTap: () => showTaskFormSheet(context, subjectId: task.subjectId, existing: task),
      onLongPress: () => _delete(context, ref),
      borderRadius: BorderRadius.circular(RadiusTokens.control),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpaceTokens.m),
        child: Row(
          children: [
            Semantics(
              checked: task.hecha,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggle(ref),
                child: CheckMark(checked: task.hecha, color: ColorTokens.accentOk.of(b)),
              ),
            ),
            SizedBox(width: SpaceTokens.m),
            Expanded(
              child: StrikeThrough(
                struck: task.hecha,
                guard: MotionGuard.of(context),
                color: ColorTokens.textPrimary.of(b),
                struckColor: ColorTokens.textTertiary.of(b),
                child: Text(task.titulo, style: context.type(TypeTokens.bodyS)),
              ),
            ),
            if (meta != null) ...[
              SizedBox(width: SpaceTokens.s),
              Text(
                meta,
                style: context.type(
                  TypeTokens.captionS,
                  color: overdue ? ColorTokens.accentUrgent.of(b) : ColorTokens.textSecondary.of(b),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── formulario

/// Alta y edición de una tarea. Solo título y, si hay, fecha.
Future<void> showTaskFormSheet(BuildContext context, {required int subjectId, Task? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: _TaskForm(subjectId: subjectId, existing: existing),
    ),
  );
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({required this.subjectId, this.existing});

  final int subjectId;
  final Task? existing;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final _titulo = TextEditingController(text: widget.existing?.titulo ?? '');
  late DateTime? _fecha = widget.existing?.fecha;

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final dao = ref.read(tasksDaoProvider);
    final existing = widget.existing;
    if (existing == null) {
      await dao.addTask(subjectId: widget.subjectId, titulo: _titulo.text, fecha: _fecha);
      ref.read(mascotCornerProvider.notifier).react(MascotReaction.taskAdded);
    } else {
      await dao.updateTask(existing.id, titulo: _titulo.text, fecha: _fecha);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fecha = _fecha;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(SpaceTokens.screenMargin),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titulo,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: STasks.titleLabel,
                  hintText: STasks.titleHint,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? STasks.titleRequired : null,
              ),
              SizedBox(height: SpaceTokens.m),
              Text(STasks.dueLabel, style: context.type(TypeTokens.label, color: ColorTokens.textTertiary.of(b))),
              SizedBox(height: SpaceTokens.xs),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        fecha == null ? STasks.pickDue : DateFormat("EEE d 'de' MMM", 'es_CO').format(fecha),
                      ),
                    ),
                  ),
                  if (fecha != null) ...[
                    SizedBox(width: SpaceTokens.s),
                    IconButton(
                      tooltip: STasks.clearDue,
                      onPressed: () => setState(() => _fecha = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
              SizedBox(height: SpaceTokens.xl),
              FilledButton(onPressed: _save, child: const Text(STasks.save)),
            ],
          ),
        ),
      ),
    );
  }
}
