import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/haptics.dart';
import '../../../theme/tokens.g.dart';
import 'subjects_screen.dart';

/// Cancelar o reactivar una materia, con la misma conversación desde donde se
/// pida: la lista, su pantalla o el menú de una tarjeta.
///
/// Cancelar pregunta antes, porque la materia desaparece de Hoy y la persona
/// tiene que saber que sus notas no se pierden. Reactivar no pregunta: no
/// destruye nada. Las dos dejan un «Deshacer» en la barra de abajo.
Future<void> toggleSubjectCancelled(BuildContext context, WidgetRef ref, Subject subject) async {
  final dao = ref.read(subjectsDaoProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final cancelling = !subject.cancelada;

  if (cancelling) {
    final ok = await _confirm(context, subject);
    if (ok != true) return;
    unawaited(Haptics.fire('cancelarMateria'));
  }

  await dao.setCancelled(subject.id, cancelled: cancelling);

  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(cancelling ? SSubjectCancel.done : SSubjectCancel.undone),
        action: SnackBarAction(
          label: SSubjectCancel.undo,
          onPressed: () => dao.setCancelled(
            subject.id,
            cancelled: !cancelling,
            at: subject.fechaCancelacion,
          ),
        ),
      ),
    );
}

Future<bool?> _confirm(BuildContext context, Subject subject) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final b = Theme.of(context).brightness;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            SpaceTokens.screenMargin,
            0,
            SpaceTokens.screenMargin,
            SpaceTokens.screenMargin,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                SSubjectCancel.confirmTitle(nombre: subject.nombre),
                style: context.type(TypeTokens.titleM),
              ),
              SizedBox(height: SpaceTokens.s),
              Text(
                SSubjectCancel.confirmBody,
                style: context.type(TypeTokens.bodyL, color: ColorTokens.textSecondary.of(b)),
              ),
              SizedBox(height: SpaceTokens.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ColorTokens.accentUrgent.of(b),
                  foregroundColor: ColorTokens.textOnUrgent.of(b),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(SSubjectCancel.confirmCta),
              ),
              SizedBox(height: SpaceTokens.s),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(SSubjectCancel.keep),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Menú rápido de una tarjeta de materia (mantener pulsada): editar y
/// cancelar o reactivar, sin tener que entrar.
Future<void> showSubjectQuickActions(BuildContext context, WidgetRef ref, Subject subject) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final b = Theme.of(sheetContext).brightness;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: SpaceTokens.screenMargin),
              child: Text(subject.nombre, style: sheetContext.type(TypeTokens.titleS)),
            ),
            SizedBox(height: SpaceTokens.s),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(SSubjectDetail.edit),
              onTap: () {
                Navigator.of(sheetContext).pop();
                openSubjectForm(context, subjectId: subject.id);
              },
            ),
            ListTile(
              leading: Icon(
                subject.cancelada ? Icons.undo : Icons.block_outlined,
                color: subject.cancelada ? null : ColorTokens.accentUrgent.of(b),
              ),
              title: Text(
                subject.cancelada ? SSubjectCancel.reactivate : SSubjectCancel.action,
                style: subject.cancelada
                    ? null
                    : sheetContext.type(TypeTokens.bodyL, color: ColorTokens.accentUrgent.of(b)),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                toggleSubjectCancelled(context, ref, subject);
              },
            ),
            SizedBox(height: SpaceTokens.s),
          ],
        ),
      );
    },
  );
}
