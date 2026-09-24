import 'package:kairos/features/mascot/mascot_view.dart';
import 'package:kairos/theme/app_theme.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cada pose tiene su propio micro-movimiento y su propio camino en el
/// painter. Se pintan todas, en varios fotogramas, para que un fallo de
/// geometría no espere a que alguien abra justo esa pantalla.
void main() {
  Widget host(MascotPose pose, {bool reduced = false, double size = 118}) => MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: MascotView(pose: pose, size: size, host: MascotHost.milestone),
          ),
        ),
      );

  for (final pose in MascotPose.values) {
    testWidgets('$pose se pinta y anima sin excepciones', (tester) async {
      await tester.pumpWidget(host(pose));
      // Entrada, un ciclo largo del idle y un parpadeo posible.
      await tester.pump(MotionDurations.mascotEnter);
      await tester.pump(MotionDurations.mascotSleep);
      await tester.pump(MascotTokens.blinkMax);
      expect(tester.takeException(), isNull);
      expect(find.byType(MascotView), findsOneWidget);
    });
  }

  testWidgets('a tamaño pequeño usa la variante de púas gordas sin fallar', (tester) async {
    await tester.pumpWidget(host(MascotPose.rodando, size: MascotTokens.sizeWidget4x4));
    await tester.pump(MotionDurations.mascotRun);
    expect(tester.takeException(), isNull);
  });

  MascotPose drawn(WidgetTester tester) =>
      (tester.state(find.byType(MascotView)) as dynamic).debugDrawnPose as MascotPose;

  testWidgets('los toques seguidos del contrato lo marean y se le pasa', (tester) async {
    await tester.pumpWidget(host(MascotPose.reposo));
    await tester.pump(MotionDurations.mascotEnter);

    for (var i = 0; i < MascotTokens.dizzyTaps - 1; i++) {
      await tester.tap(find.byType(MascotView));
      await tester.pump(MotionDurations.mascotHop);
    }
    expect(drawn(tester), MascotPose.reposo, reason: 'uno menos del umbral no marea');

    await tester.tap(find.byType(MascotView));
    await tester.pump();
    expect(drawn(tester), MascotPose.confundido);

    await tester.pump(MotionDurations.mascotDizzy);
    expect(drawn(tester), MascotPose.reposo);
  });

  testWidgets('bajo reduced-motion el toque no salta: no quedan fotogramas', (tester) async {
    await tester.pumpWidget(host(MascotPose.reposo, reduced: true));
    await tester.pump(ReducedMotion.duration);
    await tester.tap(find.byType(MascotView));
    // El toque en sí puede pedir un fotograma; a mitad de lo que duraría el
    // salto ya no debería quedar nada animándose.
    await tester.pump();
    await tester.pump(MotionDurations.mascotHop ~/ 2);
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('mantener pulsado y arrastrar se pintan sin fallar', (tester) async {
    await tester.pumpWidget(host(MascotPose.examinando));
    await tester.pump(MotionDurations.mascotEnter);
    final center = tester.getCenter(find.byType(MascotView));
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + MotionDurations.fast);
    await gesture.up();
    final drag = await tester.startGesture(center);
    await drag.moveBy(const Offset(40, -30));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('corriendo cansado (carga larga) se pinta sin fallar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Center(
          child: MascotView(pose: MascotPose.rodando, size: 118, host: MascotHost.loader, weary: true),
        ),
      ),
    );
    // Un ciclo de mirar atrás entero: pasa por el pico del giro de cabeza.
    for (var i = 0; i < 8; i++) {
      await tester.pump(MotionDurations.mascotLookBack ~/ 8);
    }
    expect(tester.takeException(), isNull);
  });

  dynamic state(WidgetTester tester) => tester.state(find.byType(MascotView));

  Widget beating(MascotBeat? beat, Object? key, {bool reduced = false, MascotPose pose = MascotPose.reposo}) =>
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: MascotView(pose: pose, size: 118, host: MascotHost.corner, beat: beat, beatKey: key),
          ),
        ),
      );

  for (final beat in MascotBeat.values) {
    testWidgets('el gesto $beat se reproduce entero y termina', (tester) async {
      await tester.pumpWidget(beating(null, 0));
      await tester.pump(MotionDurations.mascotEnter);
      await tester.pumpWidget(beating(beat, 1));
      await tester.pump();
      expect(state(tester).debugBeat, beat);
      for (var i = 0; i < 6; i++) {
        await tester.pump(beat.duration ~/ 6);
      }
      await tester.pump(MotionDurations.fast);
      expect(tester.takeException(), isNull);
      expect(state(tester).debugBeat, isNull);
    });
  }

  Widget antics(MascotAntic? antic, Object? key, {bool reduced = false, MascotPose pose = MascotPose.reposo}) =>
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: MascotView(pose: pose, size: 118, host: MascotHost.companion, antic: antic, anticKey: key),
          ),
        ),
      );

  for (final antic in MascotAntic.values) {
    testWidgets('la ocurrencia $antic se reproduce entera y termina', (tester) async {
      await tester.pumpWidget(antics(null, 0));
      await tester.pump(MotionDurations.mascotEnter);
      await tester.pumpWidget(antics(antic, 1));
      await tester.pump();
      expect(state(tester).debugAntic, antic);
      for (var i = 0; i < 10; i++) {
        await tester.pump(MotionDurations.mascotAntic ~/ 10);
      }
      await tester.pump(MotionDurations.fast);
      expect(tester.takeException(), isNull);
      expect(state(tester).debugAntic, isNull);
    });
  }

  testWidgets('sin ocurrencias corriendo ni bajo reduced-motion', (tester) async {
    await tester.pumpWidget(antics(MascotAntic.bowl, 1, pose: MascotPose.rodando));
    await tester.pump();
    expect(state(tester).debugAntic, isNull, reason: 'corriendo está ocupado');

    await tester.pumpWidget(antics(null, 1, reduced: true));
    await tester.pump(ReducedMotion.duration);
    await tester.pumpWidget(antics(MascotAntic.sun, 2, reduced: true));
    await tester.pump();
    expect(state(tester).debugAntic, isNull);
  });

  testWidgets('la misma frase con otra clave repite el gesto', (tester) async {
    await tester.pumpWidget(beating(MascotBeat.hop, 1));
    await tester.pump(MotionDurations.mascotEnter + MotionDurations.mascotHop);
    expect(state(tester).debugBeat, isNull);
    await tester.pumpWidget(beating(MascotBeat.hop, 1));
    await tester.pump();
    expect(state(tester).debugBeat, isNull, reason: 'misma clave: no se repite');
    await tester.pumpWidget(beating(MascotBeat.hop, 2));
    await tester.pump();
    expect(state(tester).debugBeat, MascotBeat.hop);
  });

  testWidgets('cambiar de pose interpola; bajo reduced-motion salta', (tester) async {
    await tester.pumpWidget(beating(null, 0));
    await tester.pump(MotionDurations.mascotEnter);
    await tester.pumpWidget(beating(null, 0, pose: MascotPose.dormido));
    await tester.pump();
    expect(state(tester).debugMorphing, isTrue);
    // pump() sin duración no avanza el reloj: hace falta un poco más que la
    // interpolación para verla terminar.
    await tester.pump(MotionDurations.mascotMorph + MotionDurations.fast);
    expect(state(tester).debugMorphing, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(beating(null, 0, reduced: true, pose: MascotPose.satisfecho));
    await tester.pump();
    expect(state(tester).debugMorphing, isFalse);
  });

  testWidgets('bajo reduced-motion no hay gesto', (tester) async {
    await tester.pumpWidget(beating(null, 0, reduced: true));
    await tester.pump(ReducedMotion.duration);
    await tester.pumpWidget(beating(MascotBeat.celebrate, 1, reduced: true));
    await tester.pump();
    expect(state(tester).debugBeat, isNull);
    // A mitad de lo que duraría el gesto, nada se está moviendo.
    await tester.pump(MotionDurations.mascotCelebrate ~/ 2);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('bajo reduced-motion aparece con fade y se queda quieta', (tester) async {
    await tester.pumpWidget(host(MascotPose.dormido, reduced: true));
    await tester.pump(ReducedMotion.duration);
    await tester.pump(MotionDurations.mascotSleep);
    expect(tester.takeException(), isNull);
    // Sin loops corriendo no hay fotogramas pendientes: el árbol está quieto.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
