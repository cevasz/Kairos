import 'package:kairos/features/mascot/mascot_view.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El dibujo de Erizógenes, congelado.
///
/// `MascotStill` es lo que se rasteriza para los widgets de Android y el
/// fotograma 0 de cada pose en la app. Un cambio en el pintor que mueva la
/// silueta sin querer rompe estas imágenes antes de llegar al teléfono.
/// Si el cambio es a propósito: `flutter test --update-goldens` y revisar el
/// PNG en el diff.
void main() {
  for (final brightness in Brightness.values) {
    final name = brightness == Brightness.dark ? 'dark' : 'light';
    final bg = ColorTokens.surfaceBase.of(brightness);

    testWidgets('las seis poses y el tamaño pequeño en $name', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              child: ColoredBox(
                color: bg,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final pose in MascotPose.values)
                      MascotStill(pose: pose, size: MascotTokens.sizeEmptyDay, brightness: brightness),
                    MascotStill(pose: MascotPose.reposo, size: MascotTokens.sizeCorner, brightness: brightness),
                    MascotStill(pose: MascotPose.reposo, size: MascotTokens.sizeWidgetSmall, brightness: brightness),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/mascot_still_$name.png'));
    });
  }
}
