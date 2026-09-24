import 'package:kairos/features/mascot/mascot_error.dart';
import 'package:kairos/l10n/strings.g.dart';
import 'package:kairos/theme/app_theme.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El error de carga no enseña la excepción en crudo, dice qué pasó y deja
/// reintentar.
void main() {
  testWidgets('dice qué pasó, reintenta y esconde el detalle hasta que se pide', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MascotError(error: StateError('base cerrada'), onRetry: () => retries++),
        ),
      ),
    );
    await tester.pump(MotionDurations.mascotStumble);

    expect(find.text(SLoadError.body), findsOneWidget);
    expect(find.textContaining('base cerrada'), findsNothing, reason: 'la excepción no va en crudo');

    await tester.tap(find.text(SLoadError.retry));
    expect(retries, 1);

    await tester.tap(find.text(SLoadError.details));
    await tester.pump(MotionDurations.fast);
    await tester.pump(MotionDurations.fast);
    expect(find.textContaining('base cerrada'), findsOneWidget);
    expect(find.text(SLoadError.hideDetails), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
