import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/daos/subjects_dao.dart';
import '../../../core/providers.dart';
import '../../../core/time/minutes_of_day.dart';
import '../../../domain/attendance/attendance.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/haptics.dart';
import '../../../theme/layout.dart';
import '../../../theme/tokens.g.dart';
import '../../mascot/application/mascot_voice.dart';
import '../../subject_detail/application/subject_detail_providers.dart';
import 'widgets/session_form_sheet.dart';
import 'widgets/subject_color_picker.dart';

/// Alta y edición de una actividad, con su horario.
///
/// El prototipo ofrece «Entrar los datos a mano» pero no dibuja el formulario.
/// El layout se arma con los componentes que el contrato sí especifica
/// (`component.input`, `component.button`, `component.chip`). Ver
/// DESIGN_DECISIONS.md §9.
class SubjectFormScreen extends ConsumerStatefulWidget {
  const SubjectFormScreen({this.subjectId, super.key});

  /// Null en alta. En edición, la actividad que se está tocando.
  final int? subjectId;

  @override
  ConsumerState<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends ConsumerState<SubjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _profesor = TextEditingController();
  final _limite = TextEditingController();

  int _colorIndex = 0;

  /// Se rellena al guardar por primera vez. A partir de ahí el formulario está
  /// en modo edición aunque se haya abierto en alta: hace falta un id real
  /// antes de poder colgarle bloques.
  int? _subjectId;

  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.subjectId;
    if (_subjectId == null) {
      // El límite por defecto sale de Ajustes; el del dominio solo si la fila
      // de ajustes aún no llegó, que en la práctica no pasa.
      _limite.text =
          (ref.read(settingsProvider).valueOrNull?.limiteFaltasPorDefecto ??
                  AttendanceCounter.defaultLimit)
              .toString();
      // El color no se sortea: en alta empieza en el primero de la paleta y lo
      // escoge la persona.
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _profesor.dispose();
    _limite.dispose();
    super.dispose();
  }

  void _hydrate(SubjectDetail detail) {
    if (_loaded) return;
    _loaded = true;
    _nombre.text = detail.subject.nombre;
    _profesor.text = detail.subject.profesor ?? '';
    _limite.text = detail.subject.limiteFaltas.toString();
    _colorIndex = detail.subject.colorIndex;
  }

  /// Guarda y devuelve el id. Crear la actividad antes de añadirle bloques es
  /// lo que permite que «Agregar un bloque» funcione en un alta recién empezada.
  Future<int?> _persist() async {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final dao = ref.read(subjectsDaoProvider);

    final nombre = _nombre.text.trim();
    final profesor = _profesor.text.trim();
    final limite =
        int.tryParse(_limite.text.trim()) ?? AttendanceCounter.defaultLimit;

    if (_subjectId == null) {
      final id = await dao.createSubject(
        nombre: nombre,
        colorIndex: _colorIndex,
        limiteFaltas: limite,
        profesor: profesor.isEmpty ? null : profesor,
      );
      setState(() => _subjectId = id);
      return id;
    }

    await dao.updateSubject(
      id: _subjectId!,
      nombre: nombre,
      colorIndex: _colorIndex,
      limiteFaltas: limite,
      profesor: profesor.isEmpty ? null : profesor,
    );
    return _subjectId;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final id = await _persist();
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      ref.read(mascotCornerProvider.notifier).react(MascotReaction.saved);
      Navigator.of(context).pop();
    }
  }

  Future<void> _addSession() async {
    final id = await _persist();
    if (id == null || !mounted) return;
    await showSessionFormSheet(context, subjectId: id);
  }

  Future<void> _confirmDelete() async {
    final id = _subjectId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(SSubjectForm.deleteTitle(nombre: _nombre.text.trim())),
        content: const Text(SSubjectForm.deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(SSubjectForm.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(SSubjectForm.deleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Háptica media: el contrato la reserva para confirmaciones destructivas.
    Haptics.fire('confirmarDestructivo');
    await ref.read(subjectsDaoProvider).deleteSubject(id);
    if (!mounted) return;
    // Dos pops: el formulario y, si venía de ahí, el detalle de la actividad que
    // acaba de dejar de existir.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final id = _subjectId;

    final detail = id == null
        ? null
        : ref.watch(subjectDetailProvider(id)).valueOrNull?.detail;
    if (detail != null) _hydrate(detail);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subjectId == null
              ? SSubjectForm.titleNew
              : SSubjectForm.titleEdit,
        ),
      ),
      body: ContentWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              SpaceTokens.screenMargin,
              SpaceTokens.m,
              SpaceTokens.screenMargin,
              SpaceTokens.xxxl,
            ),
            children: [
              _Field(
                label: SSubjectForm.fieldNombre,
                child: TextFormField(
                  controller: _nombre,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(hintText: SSubjectForm.hintNombre),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? SSubjectForm.errorNombre
                      : null,
                ),
              ),
              _Field(
                label: SSubjectForm.fieldProfesor,
                child: TextFormField(
                  controller: _profesor,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: SSubjectForm.hintProfesor),
                ),
              ),
              _Field(
                label: SSubjectForm.fieldLimiteFaltas,
                hint: SSubjectForm.hintLimiteFaltas,
                child: TextFormField(
                  controller: _limite,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n < 1)
                        ? SSubjectForm.errorLimite
                        : null;
                  },
                ),
              ),
              _Field(
                label: SSubjectForm.fieldColor,
                hint: SSubjectForm.hintColor,
                child: SubjectColorPicker(
                  selected: _colorIndex,
                  onChanged: (i) => setState(() => _colorIndex = i),
                ),
              ),
              SizedBox(height: SpaceTokens.l),
              Text(
                SSubjectForm.sectionSchedule,
                style: context.type(
                  TypeTokens.label,
                  color: ColorTokens.textTertiary.of(b),
                ),
              ),
              SizedBox(height: SpaceTokens.m),
              if (detail == null || detail.sessions.isEmpty)
                Text(
                  SSubjectForm.noSessions,
                  style: context.type(
                    TypeTokens.bodyS,
                    color: ColorTokens.textSecondary.of(b),
                  ),
                )
              else
                for (final s in detail.sessions)
                  _SessionRow(
                    session: s,
                    onTap: () => showSessionFormSheet(
                      context,
                      subjectId: id!,
                      existing: s,
                    ),
                  ),
              SizedBox(height: SpaceTokens.m),
              OutlinedButton.icon(
                onPressed: _addSession,
                icon: const Icon(Icons.add),
                label: const Text(SSubjectForm.addSession),
              ),
              SizedBox(height: SpaceTokens.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text(SSubjectForm.save),
              ),
              if (widget.subjectId != null) ...[
                SizedBox(height: SpaceTokens.m),
                OutlinedButton(
                  onPressed: _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorTokens.accentUrgent.of(b),
                    side: BorderSide(
                      color: ColorTokens.accentUrgent.of(b),
                      width: BorderTokens.hairline,
                    ),
                  ),
                  child: const Text(SSubjectForm.delete),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta + campo + ayuda opcional. Todo el espaciado sale del contrato.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: EdgeInsets.only(bottom: SpaceTokens.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.type(
              TypeTokens.label,
              color: ColorTokens.textTertiary.of(b),
            ),
          ),
          SizedBox(height: SpaceTokens.s),
          child,
          if (hint != null) ...[
            SizedBox(height: SpaceTokens.xs),
            Text(
              hint!,
              style: context.type(
                TypeTokens.captionS,
                color: ColorTokens.textTertiary.of(b),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final SessionWithRoom session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final s = session.session;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.control),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpaceTokens.m),
        child: Row(
          children: [
            Expanded(
              child: Text(
                SSessionForm.summary(
                  dia: SWeek.days[s.diaSemana - 1],
                  inicio: MinutesOfDay(s.horaInicio).hhmm,
                  fin: MinutesOfDay(s.horaFin).hhmm,
                ),
                style: context.type(TypeTokens.bodyS),
              ),
            ),
            if (session.room != null)
              Text(
                session.room!.codigo,
                style: context.type(
                  TypeTokens.captionS,
                  color: ColorTokens.textTertiary.of(b),
                ),
              ),
            SizedBox(width: SpaceTokens.s),
            Icon(
              Icons.chevron_right,
              size: IconTokens.sizeL,
              color: ColorTokens.textTertiary.of(b),
            ),
          ],
        ),
      ),
    );
  }
}
