import 'package:kairos/core/db/database.dart';
import 'package:kairos/core/providers.dart';
import 'package:kairos/features/shell/presentation/app_shell.dart';
import 'package:kairos/features/shell/presentation/widgets/radial_menu.dart';
import 'package:kairos/features/updates/application/update_providers.dart';
import 'package:kairos/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// El shell entero, con una base en memoria. Existe por un fallo que solo se
/// vio en el teléfono: un `Positioned` dentro de un `AnimatedBuilder` tumba el
/// Stack y en release la app queda en blanco sin ningún error a la vista.
void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  testWidgets('el shell se dibuja y el menú radial abre y lleva a Semana', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = KairosDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        updateCheckProvider.overrideWith((ref) async => const UpdateCheck(installed: null, latest: null)),
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 9, 23, 9))),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const AppShell()),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(RadialHub), findsOneWidget);

    await tester.tap(find.byType(RadialHub));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(RadialMenuLayer), findsOneWidget);

    await tester.tap(find.text('Semana').last, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(RadialMenuLayer), findsNothing);

    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(shellTabProvider), ShellTab.week);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    // Drift cierra con E/S real: fuera del reloj falso del test, o no vuelve.
    await tester.runAsync(db.close);
  });
}
