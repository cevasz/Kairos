import 'dart:math' as math;

import 'package:kairos/domain/attendance/attendance.dart';
import 'package:kairos/features/mascot/application/mascot_voice.dart';
import 'package:kairos/features/mascot/mascot_view.dart';
import 'package:kairos/l10n/strings.g.dart';
import 'package:kairos/theme/tokens.g.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VariantPicker', () {
    test('nunca repite la misma frase dos veces seguidas', () {
      final picker = VariantPicker(math.Random(7));
      final lines = SMascotVoice.aphorisms;
      var previous = picker.pick(lines);
      for (var i = 0; i < 200; i++) {
        final next = picker.pick(lines);
        expect(next, isNot(previous));
        previous = next;
      }
    });

    test('con una sola variante la devuelve siempre, y con ninguna, vacío', () {
      final picker = VariantPicker();
      expect(picker.pick(['una']), 'una');
      expect(picker.pick(['una']), 'una');
      expect(picker.pick(const []), isEmpty);
    });
  });

  test('las variantes con huecos salen llenas, sin llaves sueltas', () {
    final lines = SMascotVoice.nextClassVariants(clase: 'Física', hora: '8:00', salon: '302E', salida: '7:35');
    expect(lines, hasLength(greaterThan(1)));
    for (final l in lines) {
      expect(l, contains('Física'));
      expect(l, isNot(contains('{')));
    }
  });

  test('una de cada anticEveryTaps sentencias es una ocurrencia, con su frase', () {
    fakeAsync((async) {
      final c = MascotCornerController(anticSource: () => MascotAntic.chicken);
      for (var i = 1; i < MascotTokens.anticEveryTaps; i++) {
        c.muse();
        expect(c.state?.antic, isNull);
      }
      c.muse();
      expect(c.state?.antic, MascotAntic.chicken);
      expect(SMascotVoice.anticChicken, contains(c.state?.text));
      c.dispose();
    });
  });

  test('tras mascotAnticIdle en silencio hace una por su cuenta; hablar reinicia la cuenta', () {
    fakeAsync((async) {
      final c = MascotCornerController(anticSource: () => MascotAntic.jar);
      async.elapse(MotionDurations.mascotAnticIdle - MotionDurations.mascotLine);
      c.react(MascotReaction.saved);
      async.elapse(MotionDurations.mascotLine * 2);
      expect(c.state, isNull, reason: 'la frase ya se fue y la cuenta volvió a empezar');
      // La cuenta empezó al hablar: salta al cumplirse desde ahí, no desde el
      // principio.
      async.elapse(MotionDurations.mascotAnticIdle - MotionDurations.mascotLine * 2 + MotionDurations.fast);
      expect(c.state?.antic, MascotAntic.jar);
      c.dispose();
    });
  });

  test('sin fuente de contexto no hay ocurrencias por silencio', () {
    fakeAsync((async) {
      final c = MascotCornerController();
      async.elapse(MotionDurations.mascotAnticIdle * 2);
      expect(c.state, isNull);
      c.dispose();
    });
  });

  test('cada reacción lleva su gesto, y la esquina lo transporta', () {
    // Solo terminar una tarea se celebra; una falta suspira; cancelada, nada.
    expect(MascotReaction.taskDone.beat, MascotBeat.celebrate);
    expect(MascotReaction.absence.beat, MascotBeat.sigh);
    expect(MascotReaction.cancelled.beat, isNull);
    expect(
      MascotReaction.values.where((r) => r.beat == MascotBeat.celebrate),
      [MascotReaction.taskDone],
      reason: 'celebrar es escaso a propósito',
    );

    fakeAsync((async) {
      final c = MascotCornerController(picker: VariantPicker(math.Random(1)));
      c.react(MascotReaction.taskDone);
      expect(c.state?.beat, MascotBeat.celebrate);
      c.muse();
      expect(c.state?.beat, isNull, reason: 'una sentencia suelta no lleva gesto');
      c.dispose();
    });
  });

  test('marcar una clase se comenta; justificada y posible falta, no', () {
    expect(reactionForStatus(SessionStatus.asistio), MascotReaction.attended);
    expect(reactionForStatus(SessionStatus.falto), MascotReaction.absence);
    expect(reactionForStatus(SessionStatus.canceladaProfe), MascotReaction.cancelled);
    expect(reactionForStatus(SessionStatus.justificada), isNull);
    expect(reactionForStatus(SessionStatus.posibleFalta), isNull);
  });

  test('la esquina dice la frase y se calla sola', () {
    fakeAsync((async) {
      final c = MascotCornerController(picker: VariantPicker(math.Random(1)));
      c.react(MascotReaction.taskDone);
      expect(SMascotVoice.reactTaskDone, contains(c.state!.text));
      expect(c.state!.pose, MascotPose.satisfecho);

      async.elapse(kMascotLineDuration - const Duration(milliseconds: 1));
      expect(c.state, isNotNull);
      async.elapse(const Duration(milliseconds: 2));
      expect(c.state, isNull);
      c.dispose();
    });
  });

  test('una frase nueva reinicia el tiempo y sube el número de serie', () {
    fakeAsync((async) {
      final c = MascotCornerController();
      c.react(MascotReaction.grade);
      final first = c.state!.serial;
      async.elapse(kMascotLineDuration ~/ 2);
      c.muse();
      expect(c.state!.serial, first + 1);
      async.elapse(kMascotLineDuration ~/ 2 + const Duration(milliseconds: 10));
      expect(c.state, isNotNull, reason: 'la segunda frase tiene su propio tiempo');
      c.dispose();
    });
  });
}
