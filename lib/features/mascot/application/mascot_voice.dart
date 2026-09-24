import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/attendance/attendance.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/tokens.g.dart';
import '../mascot_view.dart';
import 'mascot_tips.dart';

/// Qué acaba de pasar en la app, para que Erizógenes lo comente.
enum MascotReaction {
  attended,
  absence,
  cancelled,
  grade,
  taskAdded,
  taskDone,
  saved,
  alarms;

  List<String> get lines => switch (this) {
        attended => SMascotVoice.reactAttended,
        absence => SMascotVoice.reactAbsence,
        cancelled => SMascotVoice.reactCancelled,
        grade => SMascotVoice.reactGrade,
        taskAdded => SMascotVoice.reactTaskAdded,
        taskDone => SMascotVoice.reactTaskDone,
        saved => SMascotVoice.reactSaved,
        alarms => SMascotVoice.reactAlarms,
      };

  MascotPose get pose => switch (this) {
        absence => MascotPose.examinando,
        cancelled => MascotPose.dormido,
        _ => MascotPose.satisfecho,
      };

  /// Con qué gesto lo acompaña. Contenido a propósito: solo terminar una
  /// tarea merece el saltito de «se da cuenta y celebra»; una falta es un
  /// suspiro, no un drama; una cancelación ni se comenta con el cuerpo.
  MascotBeat? get beat => switch (this) {
        taskDone => MascotBeat.celebrate,
        absence => MascotBeat.sigh,
        cancelled => null,
        grade || taskAdded => MascotBeat.notice,
        attended || saved || alarms => MascotBeat.hop,
      };
}

/// Qué comenta el erizo cuando marcas un bloque. Justificado y «posible
/// salto» no merecen comentario: la primera es burocracia, la segunda aún no
/// es un hecho.
MascotReaction? reactionForStatus(SessionStatus status) => switch (status) {
      SessionStatus.asistio => MascotReaction.attended,
      SessionStatus.falto => MascotReaction.absence,
      SessionStatus.canceladaProfe => MascotReaction.cancelled,
      _ => null,
    };

/// Una frase que Erizógenes está diciendo ahora mismo en la esquina.
class MascotLine {
  const MascotLine(this.text, this.pose, this.serial, {this.beat, this.antic});

  final String text;
  final MascotPose pose;

  /// El gesto que acompaña a la frase, si lo hay.
  final MascotBeat? beat;

  /// La ocurrencia que acompaña a la frase, si la hay.
  final MascotAntic? antic;

  /// Sube con cada frase: dos frases iguales seguidas también se animan.
  final int serial;
}

/// Escoge variantes sin repetir la última que salió de la misma lista.
///
/// Diógenes no se repetía; su erizo tampoco. Con una sola variante devuelve
/// esa, y con una lista vacía, cadena vacía.
class VariantPicker {
  VariantPicker([math.Random? random]) : _random = random ?? math.Random();

  final math.Random _random;
  final Map<int, int> _last = {};

  String pick(List<String> options) {
    if (options.isEmpty) return '';
    if (options.length == 1) return options.single;
    final key = Object.hashAll(options);
    var i = _random.nextInt(options.length);
    if (i == _last[key]) i = (i + 1) % options.length;
    _last[key] = i;
    return options[i];
  }
}

/// Cuánto se queda una frase en la esquina antes de que el erizo se esconda.
/// Dura más que una ocurrencia (`mascotAntic`): el erizo no se esconde a
/// mitad de la suya.
const Duration kMascotLineDuration = MotionDurations.mascotLine;

/// La esquina de Erizógenes: lo que dice ahora, o nada.
///
/// Cualquier pantalla puede pedirle que reaccione con [MascotCornerController.react];
/// la frase se va sola a los pocos segundos.
final mascotCornerProvider = StateNotifierProvider<MascotCornerController, MascotLine?>(
  (ref) => MascotCornerController(anticSource: () => ref.read(mascotAnticProvider)),
);

class MascotCornerController extends StateNotifier<MascotLine?> {
  /// [anticSource] elige la ocurrencia según el contexto. Sin ella (en los
  /// tests, por ejemplo) no hay ocurrencias por silencio.
  MascotCornerController({VariantPicker? picker, MascotAntic Function()? anticSource})
      : _picker = picker ?? VariantPicker(),
        _anticSource = anticSource,
        super(null) {
    _armIdle();
  }

  final VariantPicker _picker;
  final MascotAntic Function()? _anticSource;
  Timer? _hide;
  Timer? _idle;
  int _serial = 0;
  int _muses = 0;

  /// Tras [MotionDurations.mascotAnticIdle] sin decir nada, hace una
  /// ocurrencia por su cuenta. Cualquier frase reinicia la cuenta: nunca se
  /// junta con otra.
  void _armIdle() {
    _idle?.cancel();
    final source = _anticSource;
    if (source == null) return;
    _idle = Timer(MotionDurations.mascotAnticIdle, () {
      if (state == null) perform(source());
    });
  }

  /// Una ocurrencia con su frase. Descansa en reposo: la ocurrencia ya pone
  /// la cara.
  void perform(MascotAntic antic) =>
      say(_picker.pick(antic.lines), MascotPose.reposo, antic: antic);

  void react(MascotReaction? reaction) {
    if (reaction != null) say(_picker.pick(reaction.lines), reaction.pose, beat: reaction.beat);
  }

  /// Una frase suelta, sin dato detrás: una sentencia o una queja por el
  /// toque. Una de cada [MascotTokens.anticEveryTaps] es una ocurrencia.
  void muse() {
    _muses++;
    final source = _anticSource;
    if (source != null && _muses % MascotTokens.anticEveryTaps == 0) {
      perform(source());
      return;
    }
    say(_picker.pick([...SMascotVoice.aphorisms, ...SMascotVoice.petLines]), MascotPose.reposo);
  }

  void say(String text, MascotPose pose, {MascotBeat? beat, MascotAntic? antic}) {
    if (text.isEmpty) return;
    _hide?.cancel();
    _armIdle();
    state = MascotLine(text, pose, ++_serial, beat: beat, antic: antic);
    _hide = Timer(kMascotLineDuration, dismiss);
  }

  void dismiss() {
    _hide?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _hide?.cancel();
    _idle?.cancel();
    super.dispose();
  }
}
