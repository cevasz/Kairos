import 'dart:async';

import 'package:kairos/features/import/application/import_controller.dart';
import 'package:kairos/features/import/presentation/import_pdf_screen.dart';
import 'package:kairos/features/mascot/mascot_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda cuando el test lo suelta: así se controla el frame en «guardando»,
/// que ahora enseña a Erizógenes rodando en vez de un spinner.
class _GatedSave extends ImportController {
  _GatedSave(super.ref);

  final gate = Completer<void>();

  @override
  Future<void> confirm() async {
    state = const ImportSaving();
    await gate.future;
    if (mounted) state = const ImportDone(subjects: 7, sessions: 18);
  }
}

/// El bug que se reportó: «pese a que cargó completamente, aparece aún
/// cargando». El guardado terminaba bien, pero el aviso de `ImportDone` llega
/// antes de redibujar, cuando el `PopScope` todavía tiene `canPop: false` del
/// estado «guardando»: `maybePop` se negaba y la pantalla se quedaba en el
/// spinner para siempre, con las materias ya en la base.
void main() {
  testWidgets('al terminar de guardar, la pantalla de importar se cierra', (tester) async {
    late _GatedSave ctrl;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [importControllerProvider.overrideWith((ref) => ctrl = _GatedSave(ref))],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openImportPdf(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportPdfScreen), findsOneWidget);

    // En el teléfono el guardado dura varios frames: la pantalla alcanza a
    // pintarse en «guardando» antes de que llegue `ImportDone`.
    unawaited(ctrl.confirm());
    await tester.pump();
    expect(find.byType(MascotLoader), findsOneWidget);

    ctrl.gate.complete();
    // No `pumpAndSettle`: con el bug, el spinner gira para siempre y nunca se
    // asienta. Dos segundos sobran para la transición de salida.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(ImportPdfScreen), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
