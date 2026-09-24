import 'package:kairos/features/mascot/mascot_loader.dart';
import 'package:kairos/features/mascot/mascot_view.dart';
import 'package:kairos/l10n/strings.g.dart';
import 'package:kairos/theme/app_theme.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una carga larga no se disimula: pasado `mascotLoaderLong` el erizo se
/// cansa y la frase lo dice.
void main() {
  String line(WidgetTester tester) => tester.widget<Text>(find.byType(Text)).data!;

  testWidgets('pasado mascotLoaderLong se cansa y cambia a las frases largas', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: MascotLoader())));
    await tester.pump();
    expect(SMascotVoice.loadingLines, contains(line(tester)));
    expect(tester.widget<MascotView>(find.byType(MascotView)).weary, isFalse);

    await tester.pump(MotionDurations.mascotLoaderLong);
    await tester.pump(MotionDurations.base);
    expect(tester.widget<MascotView>(find.byType(MascotView)).weary, isTrue);
    expect(SMascotVoice.loadingLongLines, contains(line(tester)));

    // Desmontar cancela los temporizadores: nada queda colgando del test.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
