// ─────────────────────────────────────────────────────────────────────────────
// ERIZÓGENES MORADO · erizo de mar cínico, con monóculo
//
// Se consume SOLO vía `MascotView(pose:, size:, host:)`. Ningún otro feature
// importa la geometría ni los colores de este módulo directamente.
//
// EL DIBUJO (Kairós, docs/decisiones/01-mascota.md; Cátedra §37, `b416a89`)
//   Erizo de mar violeta ciruela: cúpula con volumen y tubérculos, agujas en
//   tres tonos con la punta lila (más claras en tema oscuro, con luz de borde,
//   para no perder la silueta), pies tubulares y sombra. Lleva un monóculo de
//   latón con su cadena: el brillo del cristal dice cómo está (vivo en
//   reposo, encendido al examinar, apagado dormido o caído) y en «confundido»
//   se le cae y cuelga de la cadena. La cara es el personaje: un párpado
//   escéptico, cejas, media sonrisa y barba de tres púas. Cada pose es una
//   combinación de cara, púas y monóculo; no hay un dibujo distinto por pose.
//
// DÓNDE PUEDE APARECER
//   Lo decide `mascot.allowedScreens` en el contrato; [MascotHost] lo refleja.
//   Nunca junto a una mala noticia de verdad: ahí una cara burlona se lee
//   como burla. Solo tipografía.
//
// El parpadeo aleatorio (cada 4–7 s) lo maneja este módulo con su propio Timer.
// El feature que lo consume no sabe nada de eso.
//
// MICRO-MOVIMIENTOS (todos en loop, todos del contrato, con easeInOutSine
// salvo la fase de la carrera, que es lineal)
//   reposo / satisfecho    respira 1 → 1,02 desde las patas
//   rodando                corre: bob, zancada alterna, agujas barridas que
//                          aletean, la cadena bota y el cristal destella a
//                          cada zancada. Con `weary` (carga larga) se cansa
//                          y cada tanto mira hacia atrás
//   dormido                respiración de sueño 1 → 0,985 y tres «z» que suben
//   examinando             la mirada barre ±1,2 px tras el monóculo, que
//                          destella una vez por barrido
//   confundido             el monóculo, caído, se mece ±4° colgado de la cadena
//   entrada (todas)        una vez: escala 0,6 → 1 con easeOutBackBounce
//
// TACTO (solo si `interactive`, que es el default)
//   toque                  salta, abre los ojos, eriza las púas; la sombra se
//                          encoge y el monóculo salta del ojo
//   N toques seguidos      se marea: pose confundido (mascot.dizzyTaps en
//                          mascot.pokeWindowMs, durante mascotDizzy)
//   mantener pulsado       entrecierra los ojos y se sonroja; no lo admitirá
//   arrastrar el dedo      la mirada sigue al dedo
//   Quien lo usa recibe `onTap` / `onLongPress` para decir algo útil.
//
// CAMBIOS Y GESTOS (§40)
//   cambio de pose         cuerpo, cara, púas y monóculo se interpolan
//                          (mascotMorph); lo discreto cambia a mitad
//   `beat` + `beatKey`     un gesto de una vez: notice, celebrate, hop, sigh,
//                          stumble. Quien lo pone dice qué pasó; el erizo
//                          decide cómo se mueve
//   `antic` + `anticKey`   una ocurrencia de Diógenes (cuenco, lista, reloj
//                          de arena, gallo, tinaja, sol)
//
// Bajo reduced-motion las poses se congelan en su primer fotograma. No se
// ocultan: la mascota sigue ahí, quieta.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/strings.g.dart';
import '../../theme/haptics.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.g.dart';

export '../../theme/tokens.g.dart' show MascotPose;

/// Pantallas con permiso. En debug, instanciar `MascotView` desde otro sitio
/// revienta con un mensaje claro: la regla de diseño es también de código.
enum MascotHost {
  splash('A1 splash'),
  loadError('error de carga'),
  pdfParsing('A3 procesando PDF'),
  pdfError('A5 error de PDF'),
  urgentCorner('B2 sal ya (esquina)'),
  emptyDay('B4 sin clases hoy'),
  emptyGrades('D3 materia sin notas'),
  milestone('hitos'),
  companion('B1 compañero'),
  widget4x4('widget 4x4'),
  loader('carga'),
  corner('esquina global'),
  homeWidget('widgets');

  const MascotHost(this.contractName);

  /// Nombre tal como aparece en `mascot.allowedScreens` de tokens.json.
  final String contractName;
}

/// Gestos de una sola vez con los que reacciona a lo que pasa. Son pocos y
/// secos: la personalidad está en cuánto se contiene.
enum MascotBeat {
  /// Salta una vez, como al tocarlo.
  hop,

  /// Se da cuenta: abre los ojos, sube las cejas, se eriza un poco.
  notice,

  /// Se da cuenta y da un saltito. Para lo que de verdad merece algo.
  celebrate,

  /// Suspira: párpados abajo, púas caídas, se hunde un poco.
  sigh,

  /// Tropieza de lado y se le desordenan las púas. Para los errores.
  stumble;

  Duration get duration => switch (this) {
        hop => MotionDurations.mascotHop,
        notice => MotionDurations.mascotNotice,
        celebrate => MotionDurations.mascotCelebrate,
        sigh => MotionDurations.mascotSigh,
        stumble => MotionDurations.mascotStumble,
      };
}

/// Ocurrencias de Diógenes: saca algo de su vida, lo usa y lo guarda. El
/// monóculo no se lo quita. Son raras a propósito y cada una tiene su frase.
enum MascotAntic {
  /// Tira el cuenco: vio a un niño beber con las manos.
  bowl,

  /// Repasa la lista de pendientes, en rollo. Para cuando alguno vence pronto.
  scroll,

  /// Da la vuelta al reloj de arena. Para cuando se acerca la hora de salir.
  hourglass,

  /// Alza un gallo desplumado: «¡He aquí el hombre de Platón!».
  chicken,

  /// Se mete en la tinaja donde vivía y asoma.
  jar,

  /// Se tumba al sol. Que nadie se lo tape.
  sun;

  List<String> get lines => switch (this) {
        bowl => SMascotVoice.anticBowl,
        scroll => SMascotVoice.anticScroll,
        hourglass => SMascotVoice.anticHourglass,
        chicken => SMascotVoice.anticChicken,
        jar => SMascotVoice.anticJar,
        sun => SMascotVoice.anticSun,
      };
}

class MascotView extends StatefulWidget {
  const MascotView({
    required this.pose,
    required this.size,
    required this.host,
    this.interactive = true,
    this.onTap,
    this.onLongPress,
    this.semanticHint,
    this.weary = false,
    this.beat,
    this.beatKey,
    this.antic,
    this.anticKey,
    super.key,
  });

  final MascotPose pose;
  final double size;

  /// Obliga a declarar desde dónde se llama. No hay valor por defecto a
  /// propósito: si no sabes en qué pantalla estás, no deberías poner la mascota.
  final MascotHost host;

  /// Reacciona al tacto. Apagado solo donde un toque se confundiría con otro
  /// control, como la esquina del «sal ya».
  final bool interactive;

  /// Se llama después de la reacción. El erizo reacciona siempre; qué dice es
  /// cosa de quien lo pone.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Qué hace tocarlo, para el lector de pantalla. Por defecto, el consejo
  /// siguiente de Hoy; la esquina dice que suelta una sentencia.
  final String? semanticHint;

  /// Solo cuenta rodando: una carga larga lo cansa. La mueve `MascotLoader`
  /// pasado `mascotLoaderLong`, no la pantalla.
  final bool weary;

  /// Un gesto de una sola vez. Suena al montarse si viene puesto y cada vez
  /// que cambia [beatKey]: quien lo pone solo dice qué pasó, no anima nada.
  final MascotBeat? beat;

  /// Cambiarla vuelve a reproducir [beat], aunque sea el mismo gesto.
  final Object? beatKey;

  /// Una ocurrencia de una vez, con la misma regla que [beat]: suena al
  /// montarse si viene puesta y cada vez que cambia [anticKey]. Corriendo no
  /// hay ocurrencias: está ocupado.
  final MascotAntic? antic;
  final Object? anticKey;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> with TickerProviderStateMixin {
  late final AnimationController _idle; // respiración, sueño o rodada
  late final AnimationController _aux; // squash, z, mirada o bamboleo
  late final AnimationController _enter; // una vez, al aparecer
  late final AnimationController _blink;
  late final AnimationController _poke; // salto al tocarlo
  late final AnimationController _morph; // de una pose a la siguiente
  late final AnimationController _beat; // un gesto de una sola vez
  late final AnimationController _antic; // una ocurrencia
  bool _entered = false;

  /// La pose que ya se ve y de la que parte la interpolación.
  MascotPose? _shownPose;
  MascotPose? _morphFrom;
  MascotBeat? _activeBeat;
  MascotAntic? _activeAntic;

  /// Hacia dónde mira mientras lo arrastras, en -1..1 por eje.
  Offset _look = Offset.zero;

  /// Mantenido pulsado: ojos entrecerrados y rubor.
  bool _petted = false;

  /// Toques recientes. A partir de [MascotTokens.dizzyTaps] se marea.
  final List<DateTime> _pokes = [];
  bool _dizzy = false;
  Timer? _dizzyTimer;
  Timer? _blinkTimer;

  /// Sube cada vez que cambia el movimiento. Un parpadeo en vuelo de una
  /// generación anterior no programa el siguiente: sin esto, cambiar de pose
  /// a mitad de un parpadeo dejaba dos cadenas de parpadeo sueltas y el erizo
  /// parpadeaba el doble.
  int _blinkGeneration = 0;
  final _random = math.Random();

  static const Curve _sine = MotionCurves.easeInOutSine;

  @override
  void initState() {
    super.initState();
    assert(
      MascotTokens.allowedScreens.contains(widget.host.contractName),
      'MascotView en una pantalla no permitida: ${widget.host.contractName}. '
      'Ver la lista en el encabezado de lib/features/mascot/mascot_view.dart.',
    );

    _idle = AnimationController(vsync: this, duration: _idleDuration);
    _aux = AnimationController(vsync: this, duration: _auxDuration ?? MotionDurations.base);
    _enter = AnimationController(vsync: this, duration: MotionDurations.mascotEnter);
    _blink = AnimationController(vsync: this, duration: MotionDurations.mascotBlink);
    _poke = AnimationController(vsync: this, duration: MotionDurations.mascotHop);
    _morph = AnimationController(vsync: this, duration: MotionDurations.mascotMorph, value: 1);
    _beat = AnimationController(vsync: this, duration: MotionDurations.mascotHop);
    _antic = AnimationController(vsync: this, duration: MotionDurations.mascotAntic);
  }

  /// La pose que se dibuja: la pedida, salvo que esté mareado.
  MascotPose get _pose => _dizzy ? MascotPose.confundido : widget.pose;

  @visibleForTesting
  MascotPose get debugDrawnPose => _pose;

  @visibleForTesting
  MascotBeat? get debugBeat => _beat.isAnimating ? _activeBeat : null;

  @visibleForTesting
  bool get debugMorphing => _morph.isAnimating;

  @visibleForTesting
  MascotAntic? get debugAntic => _antic.isAnimating ? _activeAntic : null;

  void _handleTap() {
    unawaited(Haptics.fire('tocarMascota'));
    final now = DateTime.now();
    _pokes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > MascotTokens.pokeWindow);
    if (_pokes.length >= MascotTokens.dizzyTaps && !_dizzy) {
      _pokes.clear();
      setState(() => _dizzy = true);
      _syncMotion();
      _dizzyTimer?.cancel();
      _dizzyTimer = Timer(MotionDurations.mascotDizzy, () {
        if (!mounted) return;
        setState(() => _dizzy = false);
        _syncMotion();
      });
    }
    if (!MotionGuard.of(context).reduced) _poke.forward(from: 0);
    widget.onTap?.call();
  }

  void _handleLongPress() {
    unawaited(Haptics.fire('tocarMascota'));
    setState(() => _petted = true);
    widget.onLongPress?.call();
  }

  void _lookAt(Offset local) {
    final half = widget.size / 2;
    final dx = ((local.dx - half) / half).clamp(-1.0, 1.0);
    final dy = ((local.dy - half) / half).clamp(-1.0, 1.0);
    setState(() => _look = Offset(dx, dy));
  }

  void _release() => setState(() {
        _look = Offset.zero;
        _petted = false;
      });

  Duration get _idleDuration => switch (_pose) {
        MascotPose.rodando => MotionDurations.mascotRun,
        MascotPose.dormido => MotionDurations.mascotSleep,
        _ => MotionDurations.mascotBreathe,
      };

  /// Null cuando la pose no tiene segundo movimiento.
  Duration? get _auxDuration => switch (_pose) {
        // Corriendo, el segundo reloj es el de mirar atrás cuando se cansa.
        MascotPose.rodando => MotionDurations.mascotLookBack,
        MascotPose.dormido => MotionDurations.mascotSleep,
        MascotPose.examinando => MotionDurations.mascotGlance,
        MascotPose.confundido => MotionDurations.mascotBreathe,
        _ => null,
      };

  @override
  void didUpdateWidget(MascotView old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) _syncMotion();
    if (widget.beat != null && widget.beatKey != old.beatKey) _playBeat(widget.beat!);
    if (widget.antic != null && widget.anticKey != old.anticKey) _playAntic(widget.antic!);
  }

  /// Bajo reduced-motion no se mueve: la frase ya lo cuenta.
  void _playAntic(MascotAntic antic) {
    if (MotionGuard.of(context).reduced || _pose == MascotPose.rodando) return;
    _activeAntic = antic;
    _antic.forward(from: 0);
  }

  /// Bajo reduced-motion no hay gesto: la pose y la frase ya lo dicen.
  void _playBeat(MascotBeat beat) {
    if (MotionGuard.of(context).reduced) return;
    _activeBeat = beat;
    _beat
      ..duration = beat.duration
      ..forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
    if (!_entered) {
      _entered = true;
      // Bajo reduced-motion la entrada se queda en el fade del contrato: la
      // escala no se toca y solo aparece.
      _enter.duration = MotionGuard.of(context).duration(MotionDurations.mascotEnter);
      _enter.forward();
      if (widget.beat != null) _playBeat(widget.beat!);
      if (widget.antic != null) _playAntic(widget.antic!);
    }
  }

  void _syncMotion() {
    final guard = MotionGuard.of(context);

    // Cambio de pose: se interpola desde la que se veía. Bajo reduced-motion
    // cambia de golpe.
    final target = _pose;
    if (_shownPose != null && _shownPose != target && !guard.reduced) {
      _morphFrom = _shownPose;
      _morph.forward(from: 0);
    } else if (guard.reduced) {
      _morph.value = 1;
    }
    _shownPose = target;

    _blinkGeneration++;
    _blinkTimer?.cancel();

    if (!guard.allowsLoops) {
      // Congelado en el primer fotograma, no oculto.
      for (final c in [_idle, _aux, _blink]) {
        c.stop();
        c.value = 0;
      }
      return;
    }

    _idle.duration = _idleDuration;
    _aux.duration = _auxDuration ?? MotionDurations.base;
    switch (_pose) {
      case MascotPose.rodando:
        // La fase de la carrera y la de mirar atrás avanzan sin volver.
        _idle.repeat();
        _aux.repeat();
      case MascotPose.dormido:
        _idle.repeat(reverse: true);
        // Las z suben siempre en el mismo sentido: no vuelven.
        _aux.repeat();
      case MascotPose.examinando || MascotPose.confundido:
        _idle.repeat(reverse: true);
        _aux.repeat(reverse: true);
      case MascotPose.reposo || MascotPose.satisfecho:
        // A tamaño pequeño (la esquina, el loader en línea) respirar un 2 %
        // son décimas de píxel: no se ve y obliga a redibujar a 120 Hz en
        // todas las pantallas. Ahí solo parpadea.
        if (widget.size <= MascotTokens.smallThreshold) {
          _idle
            ..stop()
            ..value = 0;
        } else {
          _idle.repeat(reverse: true);
        }
        _aux.stop();
        _aux.value = 0;
    }

    if (_eyesCanBlink) _scheduleBlink();
  }

  bool get _eyesCanBlink => _pose != MascotPose.dormido;

  /// Cada 4–7 s. El intervalo se sortea de nuevo tras cada parpadeo para que no
  /// caiga en un ritmo perceptible.
  void _scheduleBlink() {
    final generation = _blinkGeneration;
    final min = MascotTokens.blinkMin.inMilliseconds;
    final max = MascotTokens.blinkMax.inMilliseconds;
    final wait = Duration(milliseconds: min + _random.nextInt(max - min));
    _blinkTimer = Timer(wait, () async {
      if (!mounted || generation != _blinkGeneration) return;
      await _blink.forward();
      await _blink.reverse();
      if (mounted && generation == _blinkGeneration) _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _dizzyTimer?.cancel();
    _poke.dispose();
    _morph.dispose();
    _beat.dispose();
    _antic.dispose();
    _idle.dispose();
    _aux.dispose();
    _enter.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;

    final guard = MotionGuard.of(context);
    final enterCurve = CurvedAnimation(
      parent: _enter,
      curve: guard.curve(MotionCurves.easeOutBackBounce),
    );

    final art = RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _aux, _blink, _enter, _poke, _morph, _beat, _antic]),
          builder: (context, _) {
            // Entrada: sobrepasa un poco y asienta. El origen es la base de la
            // silueta para que parezca que llega al suelo, no que se infla.
            final t = enterCurve.value;
            final scale = guard.reduced ? 1.0 : MascotTokens.enterScale + (1 - MascotTokens.enterScale) * t;
            final pose = _pose;
            // El contrato pide easeInOutSine para los vaivenes. Sin curva, un
            // `repeat(reverse: true)` es una onda triangular: el cuerpo frena
            // en seco arriba y abajo y la respiración se ve mecánica. La fase
            // de la carrera es lineal (los senos van dentro del pintor) y las
            // z y la mirada atrás avanzan sin volver.
            final linear = pose == MascotPose.rodando || pose == MascotPose.dormido;
            final idle = pose == MascotPose.rodando ? _idle.value : _sine.transform(_idle.value);
            final aux = linear ? _aux.value : _sine.transform(_aux.value);
            // La respiración en reposo es solo una escala: se hace fuera del
            // pintor, sobre la capa ya pintada, para que respirar no obligue a
            // redibujar el erizo entero en cada fotograma.
            final spec = _poses[pose]!;
            final antic = _antic.isAnimating ? _activeAntic : null;
            final breathes = spec.breathes && antic == null;
            final breath = breathes ? 1 + (MascotTokens.breatheScaleMax - 1) * idle : 1.0;
            return Opacity(
              opacity: _enter.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: Transform(
                  transform: Matrix4.diagonal3Values(1, breath, 1),
                  alignment: FractionalOffset(0.5, (spec.cy + spec.ryBottom) / 100),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _ErizogenesPainter(
                        pose: pose,
                        dark: dark,
                        breathe: false,
                        idle: breathes ? 0.5 : idle,
                        aux: aux,
                        blink: _petted ? 0 : _blink.value,
                        poke: _poke.isAnimating ? _poke.value : 0,
                        look: _look,
                        petted: _petted,
                        weary: widget.weary,
                        from: _morph.isAnimating ? _morphFrom : null,
                        morph: MotionCurves.easeOutCubic.transform(_morph.value),
                        beat: _beat.isAnimating ? _activeBeat : null,
                        beatT: _beat.value,
                        antic: antic,
                        anticT: _antic.value,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (!widget.interactive) return art;
    // `container`: el botón es el erizo, no su ancestro. Sin esto la etiqueta
    // se fundía hacia arriba y en la esquina el lector de pantalla leía la
    // pantalla entera como «Tócalo y suelta una sentencia».
    return Semantics(
      container: true,
      button: true,
      label: widget.semanticHint ?? SMascotVoice.hint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        onLongPressEnd: (_) => _release(),
        onPanStart: (d) => _lookAt(d.localPosition),
        onPanUpdate: (d) => _lookAt(d.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: art,
      ),
    );
  }
}

/// Erizógenes quieto, en el fotograma de reposo de la pose: sin entrada,
/// sin parpadeo, sin temporizadores.
///
/// Existe para los widgets de la pantalla de inicio, que son vistas nativas:
/// ahí se captura una sola imagen y un `MascotView` capturado en su primer
/// fotograma saldría a mitad de la entrada, encogido y medio transparente.
/// No lleva `host` porque no se monta en ninguna pantalla: se rasteriza.
class MascotStill extends StatelessWidget {
  const MascotStill({required this.pose, required this.size, required this.brightness, super.key});

  final MascotPose pose;
  final double size;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ErizogenesPainter(
            pose: pose,
            dark: brightness == Brightness.dark,
            idle: 0,
            aux: 0,
            blink: 0,
          ),
        ),
      );
}

/// El ánfora de fondo de la época terracota, retirada: Erizógenes morado no
/// tiene vasija. Se queda como un hueco vacío solo para que las pantallas que
/// aún la nombran compilen hasta quitarla; no pinta nada ni ocupa sitio.
class MascotVase extends StatelessWidget {
  const MascotVase({this.pose = MascotPose.reposo, this.width, super.key});

  final MascotPose pose;
  final double? width;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// El dibujo
//
// Todas las coordenadas están en un lienzo de 100×100. La geometría es la
// ilustración (exenta del guardia de literales); lo que se mueve en una
// reacción sale de MascotTokens. Referencia: Cátedra `b416a89`, dirección B
// del lienzo «Erizógenes rediseño».
// ─────────────────────────────────────────────────────────────────────────────

/// La boca, un trazo: media sonrisa ladeada, recta, dormida, fruncida,
/// sonrisa de verdad, ondulada (no entiende) y abierta (jadea).
enum _Mouth { smirk, flat, sleep, purse, grin, wavy, pant }

/// El monóculo: dónde está, cuánto agranda el ojo y cuánto brilla. Todo
/// continuo para que se interpole entre poses.
class _Monocle {
  const _Monocle({
    this.radius = 10.5,
    this.magnify = 1,
    this.slide = 0,
    this.hang = 0,
    this.glint = 0.55,
    this.hold = 0,
  });

  final double radius;

  /// Cuánto agranda el cristal el ojo derecho.
  final double magnify;

  /// 0 en el ojo, 1 resbalado a la mejilla (dormido).
  final double slide;

  /// 0 en el ojo, 1 caído y colgando de la cadena (confundido).
  final double hang;

  /// Brillo del cristal: es lo que antes decía la llama. Vivo en reposo,
  /// intenso al examinar, apagado dormido o caído.
  final double glint;

  /// 0 suelto, 1 una pata lo sostiene (examinando).
  final double hold;

  static _Monocle lerp(_Monocle a, _Monocle b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return _Monocle(
      radius: l(a.radius, b.radius),
      magnify: l(a.magnify, b.magnify),
      slide: l(a.slide, b.slide),
      hang: l(a.hang, b.hang),
      glint: l(a.glint, b.glint),
      hold: l(a.hold, b.hold),
    );
  }

  _Monocle copyWith({double? slide, double? glint, double? hold}) => _Monocle(
        radius: radius,
        magnify: magnify,
        slide: slide ?? this.slide,
        hang: hang,
        glint: glint ?? this.glint,
        hold: hold ?? this.hold,
      );
}

/// Una pose es una cara, una actitud de las púas y un monóculo sobre el mismo
/// cuerpo.
class _PoseSpec {
  const _PoseSpec({
    required this.cy,
    required this.ryTop,
    required this.ryBottom,
    required this.tilt,
    required this.lidLeft,
    required this.lidRight,
    required this.browLeft,
    required this.browRight,
    required this.gaze,
    required this.mouth,
    this.monocle = const _Monocle(),
    this.sweep = 0,
    this.droop = 0,
    this.bristle = 0,
    this.irregular = 0,
    this.breathes = false,
    this.runs = false,
    this.smallPupils = false,
  });

  /// Centro vertical del cuerpo y sus dos semiejes: la cúpula es más alta que
  /// honda, como la testa de un erizo de mar.
  final double cy, ryTop, ryBottom;

  /// Inclinación del cuerpo, en grados.
  final double tilt;

  /// Párpado superior: 0 abierto, 1 cerrado.
  final double lidLeft, lidRight;

  /// Cejas: dx es cuánto baja (negativo, sube) y dy la inclinación en grados.
  final Offset browLeft, browRight;
  final Offset gaze;
  final _Mouth mouth;
  final _Monocle monocle;

  /// Grados que las agujas se barren hacia atrás (carrera).
  final double sweep;

  /// Grados que las agujas se tumban hacia los lados (sueño).
  final double droop;

  /// Cuánto más largas: 0 relajadas, positivo erizadas.
  final double bristle;

  /// 0 ordenadas, 1 cada una por su lado (desconcierto).
  final double irregular;
  final bool breathes, runs, smallPupils;

  /// De una pose a otra. Lo continuo se interpola; lo discreto (boca, si
  /// corre, si respira) cambia a mitad de camino.
  static _PoseSpec lerp(_PoseSpec a, _PoseSpec b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    final late = t >= 0.5;
    return _PoseSpec(
      cy: l(a.cy, b.cy),
      ryTop: l(a.ryTop, b.ryTop),
      ryBottom: l(a.ryBottom, b.ryBottom),
      tilt: l(a.tilt, b.tilt),
      lidLeft: l(a.lidLeft, b.lidLeft),
      lidRight: l(a.lidRight, b.lidRight),
      browLeft: Offset.lerp(a.browLeft, b.browLeft, t)!,
      browRight: Offset.lerp(a.browRight, b.browRight, t)!,
      gaze: Offset.lerp(a.gaze, b.gaze, t)!,
      mouth: late ? b.mouth : a.mouth,
      monocle: _Monocle.lerp(a.monocle, b.monocle, t),
      sweep: l(a.sweep, b.sweep),
      droop: l(a.droop, b.droop),
      bristle: l(a.bristle, b.bristle),
      irregular: l(a.irregular, b.irregular),
      breathes: late ? b.breathes : a.breathes,
      runs: late ? b.runs : a.runs,
      smallPupils: late ? b.smallPupils : a.smallPupils,
    );
  }

  /// La misma pose con otra cara: lo que no se pasa se queda como está.
  _PoseSpec copyWith({
    double? tilt,
    double? lidLeft,
    double? lidRight,
    Offset? browLeft,
    Offset? browRight,
    Offset? gaze,
    _Mouth? mouth,
    _Monocle? monocle,
    double? droop,
    double? bristle,
    double? irregular,
  }) =>
      _PoseSpec(
        cy: cy,
        ryTop: ryTop,
        ryBottom: ryBottom,
        tilt: tilt ?? this.tilt,
        lidLeft: lidLeft ?? this.lidLeft,
        lidRight: lidRight ?? this.lidRight,
        browLeft: browLeft ?? this.browLeft,
        browRight: browRight ?? this.browRight,
        gaze: gaze ?? this.gaze,
        mouth: mouth ?? this.mouth,
        monocle: monocle ?? this.monocle,
        sweep: sweep,
        droop: droop ?? this.droop,
        bristle: bristle ?? this.bristle,
        irregular: irregular ?? this.irregular,
        breathes: breathes,
        runs: runs,
        smallPupils: smallPupils,
      );

  /// La misma pose con un gesto encima: cada mando se suma a lo que ya hay.
  _PoseSpec adjusted({
    required double Function(double) lids,
    double browLift = 0,
    double bristle = 0,
    double droop = 0,
    double irregular = 0,
    double tilt = 0,
    Offset gaze = Offset.zero,
  }) =>
      copyWith(
        tilt: this.tilt + tilt,
        lidLeft: lids(lidLeft),
        lidRight: lids(lidRight),
        browLeft: browLeft.translate(-browLift, 0),
        browRight: browRight.translate(-browLift, 0),
        gaze: this.gaze + gaze,
        droop: this.droop + droop,
        bristle: this.bristle + bristle,
        irregular: math.min(1, this.irregular + irregular),
      );
}

const Map<MascotPose, _PoseSpec> _poses = {
  // Escéptico: un ojo a media asta, el otro agrandado por el monóculo.
  MascotPose.reposo: _PoseSpec(
    cy: 60,
    ryTop: 26,
    ryBottom: 20,
    tilt: 0,
    lidLeft: 0.42,
    lidRight: 0.22,
    browLeft: Offset(0, 6),
    browRight: Offset(-3, -4),
    gaze: Offset(0.4, 0.3),
    mouth: _Mouth.smirk,
    breathes: true,
  ),
  // Con prisa: el monóculo bien encajado y un destello que va y viene.
  MascotPose.rodando: _PoseSpec(
    cy: 60,
    ryTop: 26,
    ryBottom: 20,
    tilt: 9,
    lidLeft: 0.34,
    lidRight: 0.3,
    browLeft: Offset(1, 10),
    browRight: Offset(0, -8),
    gaze: Offset(1.6, 0),
    mouth: _Mouth.flat,
    monocle: _Monocle(glint: 0.75),
    sweep: -32,
    runs: true,
  ),
  // Dormido se le resbala el monóculo a la mejilla y el cristal se apaga.
  MascotPose.dormido: _PoseSpec(
    cy: 65,
    ryTop: 21,
    ryBottom: 18,
    tilt: 0,
    lidLeft: 1,
    lidRight: 1,
    browLeft: Offset(2, 2),
    browRight: Offset(2, -2),
    gaze: Offset.zero,
    mouth: _Mouth.sleep,
    monocle: _Monocle(radius: 9.5, magnify: 0.9, slide: 1, glint: 0.15),
    droop: 38,
    bristle: -0.2,
  ),
  // Examina con el monóculo sujeto con la pata: el ojo, enorme; el cristal,
  // encendido.
  MascotPose.examinando: _PoseSpec(
    cy: 61,
    ryTop: 26,
    ryBottom: 20,
    tilt: -7,
    lidLeft: 0.62,
    lidRight: 0.05,
    browLeft: Offset(2, 14),
    browRight: Offset(-6, -10),
    gaze: Offset(1.2, 1.8),
    mouth: _Mouth.purse,
    monocle: _Monocle(radius: 12, magnify: 1.18, glint: 0.9, hold: 1),
    bristle: 0.08,
  ),
  // Satisfecho a lo cínico: párpados pesados y media sonrisa, no un «¡yay!».
  MascotPose.satisfecho: _PoseSpec(
    cy: 59,
    ryTop: 26,
    ryBottom: 20,
    tilt: -4,
    lidLeft: 0.5,
    lidRight: 0.44,
    browLeft: Offset(-3, -4),
    browRight: Offset(-4, -2),
    gaze: Offset(0, 2.4),
    mouth: _Mouth.grin,
    monocle: _Monocle(glint: 0.7),
    bristle: 0.14,
    breathes: true,
  ),
  // Se le cae el monóculo y cuelga de la cadena, meciéndose.
  MascotPose.confundido: _PoseSpec(
    cy: 60,
    ryTop: 26,
    ryBottom: 20,
    tilt: -11,
    lidLeft: 0,
    lidRight: 0.05,
    browLeft: Offset(-6, -12),
    browRight: Offset(0, 14),
    gaze: Offset(-1.2, 0.8),
    mouth: _Mouth.wavy,
    monocle: _Monocle(radius: 8, magnify: 0.88, hang: 1, glint: 0),
    bristle: 0.12,
    irregular: 1,
    smallPupils: true,
  ),
};

/// Cuánto se tumban las púas al dormir: la referencia para acortarlas.
const double _sleepDroop = 38;

/// Semieje horizontal del cuerpo: igual en todas las poses.
const double _bodyRx = 28;

/// Centros de los ojos en x. El derecho es el del monóculo.
const double _eyeLeftX = 38.5;
const double _eyeRightX = 61.5;

/// La cadena del monóculo, relativa a (0, cy). Puesto, cae en curva hasta
/// el vientre, donde va prendida; caído, el monóculo cuelga tirante de un
/// punto junto al ojo, como en el dibujo original. Largo suelto y tirante.
const Offset _chainPin = Offset(67, 19);
const Offset _chainHook = Offset(73, -5);
const double _chainSlack = 24;
const double _chainTaut = 17;

double _rad(double deg) => deg * math.pi / 180;

Paint _fill(Color c) => Paint()..color = c;

double _ease(double x) => -(math.cos(math.pi * x.clamp(0.0, 1.0)) - 1) / 2;

/// Avance de 0 a 1 entre [a] y [b], con la curva de los vaivenes.
double _seg(double t, double a, double b) => _ease((t - a) / (b - a));

/// Sube y baja una vez entre 0 y 1; 0 fuera.
double _bump(double x) => x <= 0 || x >= 1 ? 0 : math.sin(math.pi * x);

/// Los colores con que se pinta, como pinturas ya hechas: una vez por tema, no
/// en cada fotograma. En oscuro las agujas y los pies se aclaran y aparece la
/// luz de borde: violeta oscuro sobre casi negro perdía la silueta.
class _Palette {
  _Palette({required bool dark})
      : body = _fill(ColorTokens.mascotBody),
        bodyShade = ColorTokens.mascotBodyShade,
        bodyLight = ColorTokens.mascotBodyLight,
        rim = dark ? ColorTokens.mascotRimLight : null,
        ink = ColorTokens.mascotInk,
        brow = ColorTokens.mascotBrow,
        spikes = _fill(dark ? ColorTokens.mascotSpikesOnDark : ColorTokens.mascotSpikes),
        spikeMid = _fill(dark ? ColorTokens.mascotSpikeMidOnDark : ColorTokens.mascotSpikeMid),
        spikeTip = _fill(dark ? ColorTokens.mascotSpikeTipOnDark : ColorTokens.mascotSpikeTip),
        tubercle = _fill(ColorTokens.mascotTubercle.withValues(alpha: 0.55)),
        beard = _fill(ColorTokens.mascotTubercle),
        eye = _fill(ColorTokens.mascotEye),
        pupil = _fill(ColorTokens.mascotPupil),
        paw = _fill(dark ? ColorTokens.mascotPawOnDark : ColorTokens.mascotPaw),
        monocle = ColorTokens.mascotMonocle,
        monocleShade = ColorTokens.mascotMonocleShade,
        bone = _fill(ColorTokens.mascotBone),
        boneShade = _fill(ColorTokens.mascotBoneShade),
        clay = _fill(ColorTokens.mascotClay),
        clayDark = ColorTokens.mascotClayDark,
        sun = _fill(ColorTokens.mascotSun),
        accent = ColorTokens.mascotAccent,
        cheek = ColorTokens.mascotCheek,
        shadowAlpha = dark ? MascotTokens.shadowAlphaDark : MascotTokens.shadowAlphaLight;

  final Paint body, spikes, spikeMid, spikeTip, tubercle, beard, eye, pupil, paw, bone, boneShade, clay, sun;
  final Color bodyShade, bodyLight, ink, brow, monocle, monocleShade, clayDark, accent, cheek;

  /// Luz de borde: solo en oscuro.
  final Color? rim;
  final double shadowAlpha;

  static final light = _Palette(dark: false);
  static final dark = _Palette(dark: true);
}

/// Lo que dibuja una ocurrencia en un instante: la cara que pone, qué objeto
/// sostiene y dónde, y lo que aparece alrededor (tinaja, sol).
class _AnticFrame {
  const _AnticFrame({
    required this.spec,
    this.prop = 0,
    this.propAt = Offset.zero,
    this.propRotation = 0,
    this.propOpen = 1,
    this.sand = 0.5,
    this.held = true,
    this.hop = 0,
    this.jar,
    this.sun,
  });

  final _PoseSpec spec;

  /// 1 el objeto fuera, 0 guardado.
  final double prop;
  final Offset propAt;
  final double propRotation, propOpen, sand;
  final bool held;
  final double hop;

  /// Altura de la tinaja respecto al centro del cuerpo; null, no hay tinaja.
  final double? jar;

  /// Dónde sale el sol; null, no sale.
  final Offset? sun;

  /// Guion común: 0–0,14 se lo piensa, 0,14–0,24 saca el objeto, lo usa y
  /// 0,8–0,88 lo guarda. El monóculo no se lo quita nunca: sin él no ve.
  static _AnticFrame at(MascotAntic antic, double t, _PoseSpec base) {
    final out = _seg(t, 0.14, 0.24) * (1 - _seg(t, 0.8, 0.88));
    switch (antic) {
      case MascotAntic.bowl:
        // Mira el cuenco, lo piensa y lo tira por encima del hombro.
        final look = _seg(t, 0.24, 0.4) * (1 - _seg(t, 0.55, 0.6));
        final fly = _seg(t, 0.55, 0.8);
        final after = t > 0.6;
        return _AnticFrame(
          spec: base.copyWith(
            gaze: Offset(2.2 * look, 2 * look),
            lidLeft: after ? 0.5 : 0.42 + 0.2 * look,
            lidRight: after ? 0.44 : null,
            browLeft: Offset(2 * look, 6 + 8 * look),
            mouth: after ? _Mouth.grin : null,
          ),
          prop: t < 0.55 ? out : 1 - _seg(t, 0.72, 0.8),
          propAt: Offset(74 + 24 * fly, 12 - 40 * _bump(fly * 0.9) - 14 * fly),
          propRotation: 320 * fly,
          held: t < 0.56,
        );
      case MascotAntic.scroll:
        // Desenrolla la lista con las dos patas y la lee de lado a lado.
        final scan = t > 0.36 && t < 0.76 ? math.sin((t - 0.36) / 0.4 * math.pi * 3) : 0.0;
        return _AnticFrame(
          spec: base.copyWith(
            gaze: Offset(1.8 * scan, 2.4),
            lidLeft: 0.5,
            lidRight: 0.2,
            mouth: _Mouth.purse,
            browRight: const Offset(-5, -8),
            monocle: base.monocle.copyWith(glint: 0.9),
          ),
          prop: out,
          propAt: const Offset(64, 12),
          propOpen: _seg(t, 0.24, 0.36) * (1 - _seg(t, 0.76, 0.84)),
        );
      case MascotAntic.hourglass:
        // Le da la vuelta y te mira mientras cae la arena.
        final flip = _seg(t, 0.34, 0.46);
        final stare = _seg(t, 0.5, 0.56) * (1 - _seg(t, 0.78, 0.84));
        return _AnticFrame(
          spec: base.copyWith(
            gaze: Offset(2 * (1 - stare), 2 * (1 - stare)),
            browRight: Offset(-3 - 5 * stare, -4),
            lidLeft: 0.42 - 0.2 * stare,
            mouth: stare < 0.5 ? _Mouth.purse : _Mouth.smirk,
          ),
          prop: out,
          propAt: const Offset(76, 8),
          propRotation: 180 * flip,
          sand: flip < 1 ? 0.8 : 0.8 - 0.6 * _seg(t, 0.46, 0.8),
        );
      case MascotAntic.chicken:
        // Lo alza, orgulloso: «¡He aquí el hombre de Platón!».
        final lift = _seg(t, 0.28, 0.4) * (1 - _seg(t, 0.74, 0.82));
        return _AnticFrame(
          spec: base.copyWith(
            mouth: t > 0.4 && t < 0.76 ? _Mouth.grin : _Mouth.smirk,
            lidLeft: 0.3,
            lidRight: 0.15,
            browLeft: Offset(-4 * lift, 4),
            browRight: Offset(-6 * lift, -4),
            bristle: 0.25 * lift,
            gaze: Offset(1.5, -1.5 * lift),
          ),
          prop: out,
          propAt: Offset(76, 6 - 14 * lift),
          propRotation: -10 * lift,
          hop: 0.35 * _bump(_seg(t, 0.36, 0.5)),
        );
      case MascotAntic.jar:
        // Se mete en la tinaja y asoma a un lado y al otro.
        final inside = _seg(t, 0.16, 0.3) * (1 - _seg(t, 0.78, 0.9));
        final peek = t > 0.34 && t < 0.74 ? math.sin((t - 0.34) / 0.4 * 2 * math.pi) : 0.0;
        return _AnticFrame(
          spec: base.copyWith(gaze: Offset(2.4 * peek, 0), lidLeft: 0.35, lidRight: 0.2, mouth: _Mouth.smirk),
          jar: inside > 0.02 ? 48 - 34 * inside : null,
        );
      case MascotAntic.sun:
        // Se tumba al sol, satisfecho; el monóculo le resbala. Que nadie se
        // lo tape.
        final lie = _seg(t, 0.16, 0.3) * (1 - _seg(t, 0.8, 0.9));
        return _AnticFrame(
          spec: base.copyWith(
            lidLeft: 0.42 + 0.58 * lie,
            lidRight: 0.22 + 0.78 * lie,
            mouth: lie > 0.5 ? _Mouth.grin : _Mouth.smirk,
            browLeft: Offset(-3 * lie, 6),
            browRight: Offset(-3 - 2 * lie, -4),
            droop: 14 * lie,
            tilt: base.tilt - 14 * lie,
            monocle: base.monocle.copyWith(slide: lie, glint: 0.55 + 0.4 * lie),
          ),
          sun: lie > 0.05 ? Offset(14, 12 + 20 * (1 - lie)) : null,
        );
    }
  }
}

class _ErizogenesPainter extends CustomPainter {
  _ErizogenesPainter({
    required this.pose,
    required this.dark,
    required this.idle,
    required this.aux,
    required this.blink,
    this.poke = 0,
    this.look = Offset.zero,
    this.petted = false,
    this.weary = false,
    this.from,
    this.morph = 1,
    this.beat,
    this.beatT = 0,
    this.antic,
    this.anticT = 0,
    this.breathe = true,
  });

  final MascotPose pose;

  /// Si respira dentro del pintor. `MascotView` lo hace fuera, con una
  /// transformación sobre la capa ya pintada; la imagen quieta de los
  /// widgets, aquí.
  final bool breathe;

  /// Tema oscuro: agujas y pies más claros, luz de borde y otra opacidad de
  /// sombra.
  final bool dark;

  /// 0..1, ya con su curva. Respiración, sueño o fase de la carrera.
  final double idle;

  /// 0..1, ya con su curva. z, mirada, bamboleo o mirar atrás.
  final double aux;

  /// 0..1. 1 = ojos cerrados.
  final double blink;

  /// 0..1 durante el salto de un toque; 0 en reposo.
  final double poke;

  /// Hacia dónde mira mientras lo arrastras, -1..1 por eje.
  final Offset look;

  /// Mantenido pulsado: ojos entrecerrados y rubor.
  final bool petted;

  /// Carga larga: corre cansado y mira atrás.
  final bool weary;

  /// Pose de la que viene y cuánto lleva (0..1, ya con curva). Null: quieta.
  final MascotPose? from;
  final double morph;

  /// Gesto en curso y su progreso 0..1.
  final MascotBeat? beat;
  final double beatT;

  /// Ocurrencia en curso y su progreso 0..1.
  final MascotAntic? antic;
  final double anticT;

  static final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  _Palette get _c => dark ? _Palette.dark : _Palette.light;

  Paint _stroke(Color color, double width) => _line
    ..color = color
    ..strokeWidth = width;

  @override
  void paint(Canvas canvas, Size size) {
    final c = _c;
    var base =
        from != null && morph < 1 ? _PoseSpec.lerp(_poses[from]!, _poses[pose]!, morph) : _poses[pose]!;

    // Ocurrencia: parte de la pose y vuelve a ella; en los bordes se funde
    // para que ni el principio ni el final den un salto.
    final anticFrame = antic == null ? null : _AnticFrame.at(antic!, anticT, _poses[MascotPose.reposo]!);
    if (anticFrame != null) {
      final edge = _seg(anticT, 0, 0.1) * (1 - _seg(anticT, 0.9, 1));
      base = _PoseSpec.lerp(base, anticFrame.spec, edge);
    }

    // El gesto se reparte en unos pocos mandos: n (se da cuenta), s (suspira),
    // e (tropieza) y un salto con su propia fase.
    final t = beat == null ? 0.0 : beatT;
    final n = switch (beat) {
      MascotBeat.notice => _bump(t),
      MascotBeat.celebrate => _bump(t / 0.4),
      _ => 0.0,
    };
    final sigh = beat == MascotBeat.sigh ? _bump(t) : 0.0;
    final trip = beat == MascotBeat.stumble ? (1 - t) : 0.0;
    final (double hopPhase, double hopAmp) = poke > 0
        ? (poke, 1.0)
        : switch (beat) {
            MascotBeat.hop => (t, 1.0),
            MascotBeat.celebrate when t > 0.4 => ((t - 0.4) / 0.6, MascotTokens.celebrateHop),
            _ => (0.0, 0.0),
          };
    final hop = math.max(hopAmp * _bump(hopPhase), anticFrame?.hop ?? 0);
    final p = beat == null
        ? base
        : base.adjusted(
            lids: (l) =>
                (l * (1 - n) + MascotTokens.sighLid * sigh).clamp(0.0, l >= 0.99 && n == 0 ? 1.0 : 0.9),
            browLift: MascotTokens.noticeBrow * n,
            bristle: MascotTokens.noticeBristle * n + 0.3 * _bump(t) * (trip > 0 ? 1 : 0),
            droop: MascotTokens.sighDroop * sigh,
            irregular: trip,
            tilt: MascotTokens.stumbleTilt * math.sin(2 * math.pi * t) * trip,
            gaze: Offset(0, 1.5 * sigh),
          );

    // A tamaño pequeño la silueta necesita agujas más gordas y trazos más
    // gruesos, y pierde luces, tubérculos y eslabones.
    final small = size.width <= MascotTokens.smallThreshold;

    // La carrera: la fase va lineal y los senos salen de ella. Cansado, la
    // zancada se acorta y cada tanto mira hacia atrás.
    final phase = p.runs ? 2 * math.pi * idle : 0.0;
    final step = math.sin(phase);
    final effort = weary ? MascotTokens.wearyBob : 1.0;
    final bob = p.runs ? -MascotTokens.runBob * step.abs() * effort : 0.0;
    final stride = p.runs ? step * effort : 0.0;
    final lookBack = p.runs && weary ? ((math.sin(2 * math.pi * aux) - 0.6) / 0.4).clamp(0.0, 1.0) : 0.0;

    canvas.save();
    canvas.scale(size.width / 100.0);

    _paintShadow(canvas, p, c, hop, step.abs() * (p.runs ? 1 : 0));
    final sun = anticFrame?.sun;
    if (sun != null) _paintSun(canvas, c, sun);

    // Tropiezo: un vaivén de lado que se apaga. Se da cuenta: se estira un
    // poco hacia arriba. Suspiro: se hunde desde los pies.
    if (trip > 0) canvas.translate(MascotTokens.stumbleShift * math.sin(3 * math.pi * t) * trip, 0);
    if (n > 0) canvas.translate(0, -MascotTokens.noticeLift * n);
    if (sigh > 0) _scaleFromFeet(canvas, p, 1, 1 - MascotTokens.sighSink * sigh);

    // Salto (toque, gesto u ocurrencia): sube y, al despegar y al caer, se
    // aplasta.
    if (hop > 0) {
      canvas.translate(0, -MascotTokens.hopHeight * hop);
      const edge = MascotTokens.hopSquashPhase;
      final squash = hopPhase < edge
          ? (edge - hopPhase) / edge
          : hopPhase > 1 - edge
              ? (hopPhase - (1 - edge)) / edge
              : 0.0;
      _scaleFromFeet(canvas, p, 1 + MascotTokens.hopSquashX * squash, 1 - MascotTokens.hopSquashY * squash);
    }

    if (p.runs) {
      _paintSpeedLines(canvas, p, c);
      canvas.translate(0, bob);
      // Al tocar el suelo se aplasta un poco: dos contactos por ciclo.
      final contact = MascotTokens.squashScale * (1 - step.abs());
      _scaleFromFeet(canvas, p, 1 + contact, 1 - contact);
    } else if (pose == MascotPose.dormido) {
      // Respiración de sueño: más lenta y hacia abajo. Un cuerpo dormido no se
      // hincha, se hunde un poco.
      _scaleFromFeet(canvas, p, 1, 1 - (1 - MascotTokens.sleepScale) * idle);
    } else if (p.breathes && breathe) {
      _scaleFromFeet(canvas, p, 1, 1 + (MascotTokens.breatheScaleMax - 1) * idle);
    }

    canvas.translate(50, p.cy);
    canvas.rotate(_rad(p.tilt - MascotTokens.lookBackTilt * lookBack));
    canvas.translate(-50, -p.cy);

    // Un toque lo eriza y le abre los ojos de golpe.
    final bristle = p.bristle + MascotTokens.hopBristle * hop;
    final flutter = p.runs ? MascotTokens.runSpineFlutter * math.sin(2 * phase) : 0.0;
    _paintSpikes(canvas, p, c, small, bristle, p.sweep + flutter);
    _paintFeet(canvas, p, c, small, stride);
    _paintBody(canvas, p, c, small);
    _paintFace(canvas, p, c, small, hop, lookBack);
    _paintMonocle(canvas, p, c, small, hop, phase);
    final jar = anticFrame?.jar;
    if (jar != null) _paintJar(canvas, c, Offset(50, p.cy + jar));
    if (anticFrame != null && anticFrame.prop > 0) _paintProp(canvas, p, c, antic!, anticFrame, small);
    if (pose == MascotPose.dormido) _paintZs(canvas, c);

    canvas.restore();
  }

  void _scaleFromFeet(Canvas canvas, _PoseSpec p, double sx, double sy) {
    final originY = p.cy + p.ryBottom;
    canvas.translate(50, originY);
    canvas.scale(sx, sy);
    canvas.translate(-50, -originY);
  }

  /// La sombra se queda en el suelo: al saltar o en lo alto de cada zancada se
  /// encoge y se aclara.
  void _paintShadow(Canvas canvas, _PoseSpec p, _Palette c, double hop, double runUp) {
    final k = 1 - MascotTokens.shadowHopShrink * hop - 0.12 * runUp;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50, p.cy + p.ryBottom + 7), width: 48 * k, height: 6.4 * k),
      Paint()..color = ColorTokens.mascotShadow.withValues(alpha: c.shadowAlpha * k),
    );
  }

  /// Punto de la superficie de la cúpula en el ángulo [a], escalado por [k].
  Offset _surface(_PoseSpec p, double a, double k) {
    final s = math.sin(a);
    return Offset(50 + _bodyRx * k * math.cos(a), p.cy + (s < 0 ? p.ryTop : p.ryBottom) * k * s);
  }

  static void _needle(Path path, Offset base, double angle, double length, double halfWidth) {
    final dx = math.cos(angle), dy = math.sin(angle);
    path
      ..moveTo(base.dx - dy * halfWidth, base.dy + dx * halfWidth)
      ..lineTo(base.dx + dx * length, base.dy + dy * length)
      ..lineTo(base.dx + dy * halfWidth, base.dy - dx * halfWidth)
      ..close();
  }

  /// Agujas de erizo de mar en dos capas y tres tonos: oscura en la raíz,
  /// media en el tramo y lila claro en la punta. Nacen dentro del cuerpo (que
  /// las tapa) y cubren todo menos el vientre. El largo varía con una suma de
  /// senos fija: irregular a la vista, idéntico en cada fotograma.
  void _paintSpikes(Canvas canvas, _PoseSpec p, _Palette c, bool small, double bristle, double sweep) {
    final roots = Path();
    final mids = Path();
    final tips = Path();
    final reach = 17 * (1 + bristle * 1.6);
    final layers = small
        ? [(MascotTokens.spikesSmall, 1.0, 3.1, 0.0)]
        : [
            (MascotTokens.spikesNormal, 1.0, 2.3, 0.0),
            (MascotTokens.spikesFront, 0.62, 2.0, 0.5),
          ];
    for (final (n, share, width, offset) in layers) {
      for (var i = 0; i < n; i++) {
        final a = _rad(158 + (i + offset) / (n - 1) * 224);
        final variation = 1 + 0.17 * math.sin(i * 2.39 + offset * 7) + 0.09 * math.sin(i * 5.1 + 1.3);
        // Tumbadas se ven más cortas; proporcional para que se interpole.
        final length = reach * share * variation * (1 - 0.18 * math.min(1, p.droop / _sleepDroop));
        final cos = math.cos(a);
        var turn = sweep;
        if (p.droop > 0) turn += p.droop * cos.sign * math.min(1, cos.abs() * 3);
        if (p.irregular > 0) turn += 16 * math.sin(i * 3.7) * p.irregular;
        final angle = a + _rad(turn);
        final dir = Offset(math.cos(angle), math.sin(angle));
        final base = _surface(p, a, 0.86);
        const root = _bodyRx * 0.14;
        _needle(roots, base, angle, length + root, width);
        final mid = length * 0.4 + root;
        _needle(mids, base + dir * mid, angle, length * 0.6, width * 0.6);
        final tip = length * 0.66 + root;
        _needle(tips, base + dir * tip, angle, length * 0.34, width * 0.36);
      }
    }
    canvas.drawPath(roots, c.spikes);
    canvas.drawPath(mids, c.spikeMid);
    canvas.drawPath(tips, c.spikeTip);
  }

  /// Pies tubulares. Corriendo se alternan: el que va adelante, levantado.
  void _paintFeet(Canvas canvas, _PoseSpec p, _Palette c, bool small, double stride) {
    final y = p.cy + p.ryBottom + 1.5;
    final w = small ? 14.0 : 12.0;
    final h = small ? 9.2 : 7.6;
    final reach = MascotTokens.runStride * stride;
    const lift = MascotTokens.runLift;
    for (final foot in [
      Offset(41 - reach, y - math.max(0, stride) * lift),
      Offset(59 + reach, y - math.max(0, -stride) * lift),
    ]) {
      canvas.drawOval(Rect.fromCenter(center: foot, width: w, height: h), c.paw);
    }
  }

  /// La cúpula: media elipse alta arriba y otra más baja abajo, con volumen
  /// (luz arriba a la izquierda, sombra abajo a la derecha), las hileras de
  /// tubérculos de un erizo de mar y, en oscuro, la luz de borde.
  void _paintBody(Canvas canvas, _PoseSpec p, _Palette c, bool small) {
    final top = Rect.fromCenter(center: Offset(50, p.cy), width: _bodyRx * 2, height: p.ryTop * 2);
    final bottom = Rect.fromCenter(center: Offset(50, p.cy), width: _bodyRx * 2, height: p.ryBottom * 2);
    final dome = Path()
      ..addArc(top, math.pi, math.pi)
      ..arcTo(bottom, 0, math.pi, false)
      ..close();
    canvas.drawPath(dome, c.body);

    canvas.save();
    canvas.clipPath(dome);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(60, p.cy + 17), width: 70, height: 42),
      Paint()..color = c.bodyShade.withValues(alpha: 0.5),
    );
    if (!small) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(39, p.cy - 16), width: 34, height: 19),
        Paint()..color = c.bodyLight.withValues(alpha: 0.5),
      );
      for (final phi in const [-0.95, -0.42, 0.1, 0.62]) {
        for (final th in const [0.3, 0.52, 0.74, 0.96]) {
          final y = p.cy - p.ryTop * math.cos(th);
          // Solo en lo alto: la cara no lleva tubérculos.
          if (y > p.cy - 11) continue;
          final r = 0.75 + 0.35 * math.sin(th);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(50 + _bodyRx * math.sin(th) * math.sin(phi), y),
              width: 2 * r * (0.6 + 0.4 * math.cos(phi)),
              height: 2 * r,
            ),
            c.tubercle,
          );
        }
      }
    }
    canvas.restore();

    final rim = c.rim;
    if (rim != null) {
      canvas.drawArc(top.deflate(1.2), _rad(-165), _rad(60), false, _stroke(rim, small ? 2.6 : 2));
    }
    canvas.drawPath(dome, _stroke(c.ink.withValues(alpha: 0.7), small ? 1.6 : 1.1));
  }

  void _paintFace(Canvas canvas, _PoseSpec p, _Palette c, bool small, double hop, double lookBack) {
    final ey = p.cy - 2;
    final er = small ? 8.2 : 7.4;
    final pupilR = (small ? 3.4 : 2.8) * (p.smallPupils ? 0.72 : 1);
    // El cristal agranda el ojo mientras está puesto; caído, ya no.
    final m = p.monocle;
    final onEye = 1 - m.hang;
    final mag = 1 + (m.magnify - 1) * onEye;
    final glass = 1 + 0.08 * onEye * (1 - m.slide);

    // Examinando: la mirada barre de lado a lado, como quien lee una fila.
    final glance =
        pose == MascotPose.examinando && antic == null ? MascotTokens.glanceOffset * (2 * aux - 1) : 0.0;
    var gaze = p.gaze + Offset(glance, 0) + look * MascotTokens.lookPupil;
    gaze = Offset.lerp(gaze, const Offset(-MascotTokens.lookBackGaze, 0), lookBack)!;

    double lid(double base) {
      var l = petted ? math.max(base, MascotTokens.pettedLid) : base;
      if (weary && p.runs) l = math.min(0.9, l + MascotTokens.wearyLid);
      l *= 1 - hop; // el salto le abre los ojos
      return l + (1 - l) * blink;
    }

    _paintEye(canvas, c, Offset(_eyeLeftX, ey), er * 0.95, er * 1.02, lid(p.lidLeft), gaze, pupilR, small);
    _paintEye(
      canvas,
      c,
      Offset(_eyeRightX, ey - 0.5),
      er * mag * glass,
      er * 1.05 * mag * glass,
      lid(p.lidRight),
      gaze * mag,
      pupilR * mag * (1 + 0.15 * onEye),
      small,
    );

    final browWidth = small ? 3.6 : 3.0;
    _paintBrow(canvas, c, Offset(_eyeLeftX, ey - er - 2.2), p.browLeft, browWidth);
    _paintBrow(canvas, c, Offset(_eyeRightX, ey - er * mag - 3.6), p.browRight, browWidth);

    // Rubor solo cuando lo acarician. No lo admitirá.
    if (petted) {
      final blush = Paint()..color = c.cheek.withValues(alpha: MascotTokens.blushAlpha * 1.6);
      for (final cx in const [30.0, 70.0]) {
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, p.cy + 8), width: 9, height: 4.5), blush);
      }
    }

    final mouth = weary && p.runs ? _Mouth.pant : p.mouth;
    _paintMouth(canvas, p, c, small, mouth);
    _paintBeard(canvas, p, c, small);
  }

  /// Un ojo con su párpado: el blanco, la pupila con su brillo y encima un
  /// párpado del color del cuerpo recortado a la forma del ojo. Cerrado del
  /// todo es una curva cansada hacia abajo.
  void _paintEye(
    Canvas canvas,
    _Palette c,
    Offset o,
    double rx,
    double ry,
    double lid,
    Offset gaze,
    double pupilR,
    bool small,
  ) {
    if (lid >= 0.99) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - rx, o.dy)
          ..quadraticBezierTo(o.dx, o.dy + ry * 0.7, o.dx + rx, o.dy),
        _stroke(c.brow, small ? 2.6 : 2.0),
      );
      return;
    }
    final oval = Rect.fromCenter(center: o, width: rx * 2, height: ry * 2);
    canvas.drawOval(oval, c.eye);
    canvas.save();
    canvas.clipPath(Path()..addOval(oval));
    final pupil = o + gaze;
    canvas.drawCircle(pupil, pupilR, c.pupil);
    canvas.drawCircle(pupil.translate(-pupilR * 0.35, -pupilR * 0.4), pupilR * 0.3, c.eye);
    final top = o.dy - ry;
    final ly = top + lid * 2 * ry;
    if (lid > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - rx - 1, top - 1)
          ..lineTo(o.dx + rx + 1, top - 1)
          ..lineTo(o.dx + rx + 1, ly)
          ..quadraticBezierTo(o.dx, ly + ry * 0.18, o.dx - rx - 1, ly)
          ..close(),
        c.body,
      );
    }
    canvas.restore();
    canvas.drawOval(oval, _stroke(c.ink.withValues(alpha: 0.45), 0.8));
    if (lid > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - rx * 0.98, ly)
          ..quadraticBezierTo(o.dx, ly + ry * 0.18, o.dx + rx * 0.98, ly),
        _stroke(c.brow, small ? 2 : 1.5),
      );
    }
  }

  /// [shape]: dx cuánto baja la ceja, dy su inclinación en grados.
  void _paintBrow(Canvas canvas, _Palette c, Offset o, Offset shape, double width) {
    const half = 6.2;
    final a = _rad(shape.dy);
    final y = o.dy + shape.dx;
    canvas.drawPath(
      Path()
        ..moveTo(o.dx - half * math.cos(a), y - half * math.sin(a))
        ..quadraticBezierTo(o.dx, y - 1.4, o.dx + half * math.cos(a), y + half * math.sin(a)),
      _stroke(c.brow, width),
    );
  }

  void _paintMouth(Canvas canvas, _PoseSpec p, _Palette c, bool small, _Mouth mouth) {
    final y = p.cy + 11;
    if (mouth == _Mouth.pant) {
      canvas.drawOval(Rect.fromCenter(center: Offset(50, y + 0.4), width: 4, height: 3.6), Paint()..color = c.brow);
      return;
    }
    final path = switch (mouth) {
      _Mouth.smirk => Path()
        ..moveTo(44, y)
        ..quadraticBezierTo(49, y + 2, 56, y - 2.2),
      _Mouth.flat => Path()
        ..moveTo(45, y)
        ..lineTo(55, y + 0.6),
      _Mouth.sleep => Path()
        ..moveTo(48, y)
        ..quadraticBezierTo(50, y + 1.2, 52, y),
      _Mouth.purse => Path()
        ..moveTo(48.5, y)
        ..quadraticBezierTo(50, y - 1, 51.5, y),
      _Mouth.grin => Path()
        ..moveTo(44, y - 1)
        ..quadraticBezierTo(50, y + 3.2, 56, y - 2.4),
      _Mouth.wavy || _Mouth.pant => Path()
        ..moveTo(44.5, y)
        ..quadraticBezierTo(46.8, y - 1.8, 49, y)
        ..quadraticBezierTo(51.2, y + 1.8, 53.5, y),
    };
    canvas.drawPath(path, _stroke(c.brow, small ? 2.4 : 2.0));
  }

  /// La barba del filósofo: tres púas que cuelgan de la barbilla. Dormido se
  /// le tuercen hacia los lados.
  void _paintBeard(Canvas canvas, _PoseSpec p, _Palette c, bool small) {
    final y = p.cy + 13.5;
    final droop = 0.5 * math.min(1, p.droop / _sleepDroop);
    final shafts = Path();
    final tips = Path();
    for (final (x, length, deg) in const [(46.6, 8.0, 20.0), (50.0, 11.0, 0.0), (53.4, 8.0, -20.0)]) {
      final angle = _rad(90 + deg * (1 - droop));
      final l = length * (1 - droop * 0.25);
      _needle(shafts, Offset(x, y), angle, l, small ? 2.4 : 1.6);
      _needle(
        tips,
        Offset(x + math.cos(angle) * l * 0.6, y + math.sin(angle) * l * 0.6),
        angle,
        l * 0.4,
        small ? 0.9 : 0.8,
      );
    }
    // Entrecana: del tono de los tubérculos, para que se lea sobre la sombra
    // del vientre sin parecer dientes.
    canvas.drawPath(shafts, c.beard);
    canvas.drawPath(shafts, _stroke(c.ink.withValues(alpha: 0.55), 0.5));
    canvas.drawPath(tips, c.spikeTip);
  }

  /// El monóculo de latón con su cadena. En el ojo, la cadena cae en curva
  /// hasta el costado; resbalado, en la mejilla; caído, cuelga tirante del
  /// enganche y se mece. El brillo del cristal es el estado de ánimo.
  void _paintMonocle(Canvas canvas, _PoseSpec p, _Palette c, bool small, double hop, double phase) {
    final m = p.monocle;
    final anchor = Offset.lerp(_chainPin, _chainHook, m.hang)!.translate(0, p.cy);
    final eye = Offset(_eyeRightX, p.cy - 2.5);
    final onEye = eye.translate(0, 5 * m.slide - MascotTokens.hopMonocleLift * hop * (1 - m.hang));
    // Caído: un péndulo bajo el enganche, que se mece con el bamboleo.
    final swing = pose == MascotPose.confundido && antic == null ? MascotTokens.wobbleDegrees * (2 * aux - 1) : 0.0;
    final down = _rad(76 - 1.6 * swing);
    final dir = Offset(math.cos(down), math.sin(down));
    final r = m.radius;
    final hanging = anchor + dir * (_chainTaut + r);
    // Entre el ojo y la cadena tirante cae en arco, hacia fuera.
    final center = Offset.lerp(onEye, hanging, m.hang)! + Offset(5 * _bump(m.hang), 0);
    final rotation = 12 * m.slide + (26 + swing * 2) * m.hang;

    // La pata que lo sostiene al examinar.
    if (m.hold > 0.02) {
      canvas.save();
      canvas.translate(center.dx + r * 0.62, center.dy + r * 0.86);
      canvas.rotate(_rad(-28));
      canvas.scale(m.hold);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 12, height: 9), c.paw);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 12, height: 9),
        _stroke(c.ink.withValues(alpha: 0.5), 0.8),
      );
      canvas.restore();
    }

    // El enganche de la cadena en el aro: abajo a la derecha puesto, hacia
    // el enganche caído.
    final lugOn = _rad(52 + 12 * m.slide);
    final toAnchor = anchor - center;
    final lugHang = math.atan2(toAnchor.dy, toAnchor.dx);
    final lugAngle = lugOn + _angleDelta(lugOn, lugHang) * m.hang;
    final lug = center + Offset(math.cos(lugAngle), math.sin(lugAngle)) * r;

    // La cadena: una parábola con el largo que le queda, combada hacia fuera
    // y hacia abajo. Corriendo, bota con la zancada.
    final length = _chainSlack + (_chainTaut - _chainSlack) * m.hang;
    final span = anchor - lug;
    final chord = span.distance;
    final sag = chord >= length || chord == 0 ? 0.0 : math.sqrt(3 * chord * (length - chord) / 8);
    var normal = chord == 0 ? Offset.zero : Offset(-span.dy, span.dx) / chord;
    if (normal.dx + normal.dy < 0) normal = -normal;
    final bounce = p.runs ? 2.5 * math.sin(phase).abs() : 0.0;
    final control = Offset.lerp(lug, anchor, 0.5)! + normal * (2 * sag - bounce);
    final chain = c.monocle;
    if (small) {
      canvas.drawPath(
        Path()
          ..moveTo(lug.dx, lug.dy)
          ..quadraticBezierTo(control.dx, control.dy, anchor.dx, anchor.dy),
        _stroke(chain, 1.8),
      );
    } else {
      final link = _fill(chain);
      final links = (length / 2).round();
      for (var i = 0; i <= links; i++) {
        final t = i / links;
        final u = 1 - t;
        canvas.drawCircle(lug * (u * u) + control * (2 * u * t) + anchor * (t * t), 0.72, link);
      }
      canvas.drawCircle(anchor, 1.3, link);
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_rad(rotation));
    // El cristal: un velo apenas, con un reflejo que dice cómo está.
    canvas.drawCircle(Offset.zero, r, _fill(ColorTokens.mascotEye.withValues(alpha: 0.12 + 0.06 * m.hang)));
    final glint = m.glint;
    if (glint > 0.02) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * 0.7),
        _rad(-155),
        _rad(50),
        false,
        _stroke(ColorTokens.mascotEye.withValues(alpha: 0.65 * glint), small ? 1.8 : 1.3),
      );
    }
    // Examinando: un destello más fuerte, una vez por barrido de la mirada.
    // Corriendo, uno por zancada.
    final flash = switch (pose) {
      MascotPose.examinando when antic == null => (1 - (aux - 0.85).abs() / 0.15).clamp(0.0, 1.0),
      MascotPose.rodando => math.max(0.0, math.sin(phase) - 0.6) / 0.4,
      _ => 0.0,
    };
    if (flash > 0 && !small) {
      canvas.drawCircle(
        Offset(-r * 0.36, -r * 0.44),
        1.4 * flash,
        _fill(ColorTokens.mascotEye.withValues(alpha: 0.9 * flash)),
      );
    }
    // El aro de latón, con su sombra por dentro.
    canvas.drawCircle(Offset.zero, r, _stroke(c.monocle, small ? 3.2 : 2.2));
    if (!small) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r - 1.1),
        _rad(20),
        _rad(140),
        false,
        _stroke(c.monocleShade, 0.7),
      );
    }
    canvas.restore();
    canvas.drawCircle(lug, small ? 1.6 : 1.2, _fill(c.monocle));
  }

  /// La diferencia más corta entre dos ángulos, para que el enganche gire por
  /// el lado corto.
  static double _angleDelta(double from, double to) {
    var d = (to - from) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    return d;
  }

  void _paintHand(Canvas canvas, _Palette c, Offset at, double k) {
    canvas.drawOval(Rect.fromCenter(center: at, width: 6.4 * k, height: 4.8 * k), c.paw);
  }

  /// El objeto de la ocurrencia, en la mano.
  void _paintProp(Canvas canvas, _PoseSpec p, _Palette c, MascotAntic antic, _AnticFrame f, bool small) {
    final k = f.prop * (small ? 1.2 : 1);
    if (k <= 0.01) return;
    final at = Offset(f.propAt.dx, p.cy + f.propAt.dy);
    final edge = _stroke(c.ink, 0.6);
    canvas.save();
    switch (antic) {
      case MascotAntic.bowl:
        // El cuenco que tiró al ver a un niño beber con las manos.
        canvas.translate(at.dx, at.dy);
        canvas.rotate(_rad(f.propRotation));
        canvas.scale(1.3 * k);
        final body = Path()
          ..moveTo(-7, -1)
          ..quadraticBezierTo(-6.5, 6, 0, 6.5)
          ..quadraticBezierTo(6.5, 6, 7, -1)
          ..close();
        canvas.drawPath(body, c.clay);
        canvas.drawPath(body, edge);
        final rim = Rect.fromCenter(center: const Offset(0, -1), width: 14, height: 3.6);
        canvas.drawOval(rim, _fill(c.clayDark));
        canvas.drawOval(rim, edge);
      case MascotAntic.scroll:
        // La lista de pendientes, en rollo: lo que hay que hacer, en pequeño.
        canvas.translate(at.dx - 14, at.dy - 2);
        canvas.scale(1.2 * k);
        final w = 4 + 14 * f.propOpen;
        final sheet = Rect.fromLTWH(-w / 2, -7, w, 13);
        canvas.drawRect(sheet, c.bone);
        canvas.drawRect(sheet, edge);
        if (f.propOpen > 0.3) {
          final text = _stroke(c.boneShade.color, 1);
          for (var i = 0; i < 3; i++) {
            final y = -4 + i * 3.4;
            canvas.drawLine(Offset(-w / 2 + 2, y), Offset(w / 2 - 2 - (i == 2 ? 3 : 0), y), text);
          }
        }
        for (final side in const [-1.0, 1.0]) {
          final roller = RRect.fromRectAndRadius(
            Rect.fromLTWH(side * w / 2 - 1.8, -8.2, 3.6, 15.4),
            const Radius.circular(1.8),
          );
          canvas.drawRRect(roller, c.clay);
          canvas.drawRRect(roller, edge);
        }
      case MascotAntic.hourglass:
        canvas.translate(at.dx, at.dy);
        canvas.rotate(_rad(f.propRotation));
        canvas.scale(1.3 * k);
        final glass = Path()
          ..moveTo(-4.5, -7)
          ..lineTo(4.5, -7)
          ..lineTo(0.8, 0)
          ..lineTo(4.5, 7)
          ..lineTo(-4.5, 7)
          ..lineTo(-0.8, 0)
          ..close();
        canvas.drawPath(glass, _fill(c.bone.color.withValues(alpha: 0.55)));
        canvas.drawPath(glass, edge);
        final top = 7 * (1 - f.sand) * 0.8;
        final spread = 4.5 * (1 - f.sand) * 0.8;
        canvas.drawPath(
          Path()
            ..moveTo(-spread, -top)
            ..lineTo(spread, -top)
            ..lineTo(0, -0.5)
            ..close(),
          c.sun,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-4, 6.5)
            ..lineTo(4, 6.5)
            ..lineTo(3.2 * f.sand, 6.5 - 5 * f.sand)
            ..lineTo(-3.2 * f.sand, 6.5 - 5 * f.sand)
            ..close(),
          c.sun,
        );
        for (final y in const [-7.8, 7.8]) {
          final cap = RRect.fromRectAndRadius(Rect.fromLTWH(-5.6, y - 1, 11.2, 2), const Radius.circular(1));
          canvas.drawRRect(cap, _fill(c.monocle));
          canvas.drawRRect(cap, _stroke(c.ink, 0.5));
        }
      case MascotAntic.chicken:
        // «¡He aquí el hombre de Platón!»: un gallo desplumado.
        canvas.translate(at.dx, at.dy - 6);
        canvas.rotate(_rad(f.propRotation));
        canvas.scale(1.6 * k);
        _paintChicken(canvas, c);
      case MascotAntic.jar || MascotAntic.sun:
        break;
    }
    canvas.restore();

    if (f.held) {
      final hand = small ? 1.6 : 1.35;
      _paintHand(canvas, c, at.translate(-2, 7 * k), hand * k);
      if (antic == MascotAntic.scroll) _paintHand(canvas, c, at.translate(-28, 7 * k), hand * k);
    }
  }

  void _paintChicken(Canvas canvas, _Palette c) {
    final skin = _fill(ColorTokens.mascotChicken);
    final fold = _stroke(ColorTokens.mascotChickenShade, 0.8);
    final edge = _stroke(c.ink, 0.6);
    final leg = _stroke(ColorTokens.mascotSun, 1);
    for (final sx in const [-1.6, 1.6]) {
      canvas.drawLine(Offset(sx, 4), Offset(sx * 1.4, 10), leg);
      canvas.drawLine(Offset(sx * 1.4 - 1.2, 10), Offset(sx * 1.4 + 1.2, 10), leg);
    }
    final body = Rect.fromCenter(center: Offset.zero, width: 13, height: 10.4);
    canvas.drawOval(body, skin);
    canvas.drawOval(body, edge);
    canvas.drawPath(
      Path()
        ..moveTo(-3, 1)
        ..quadraticBezierTo(0, 3.5, 3, 1),
      fold,
    );
    final goose = _fill(ColorTokens.mascotChickenShade);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(-3 + i * 1.5, -1.5 + (i % 2)), 0.35, goose);
    }
    canvas.drawPath(
      Path()
        ..moveTo(4.5, -3)
        ..quadraticBezierTo(7.5, -8, 6.5, -11),
      _stroke(ColorTokens.mascotChicken, 2.4),
    );
    final head = Rect.fromCenter(center: const Offset(6.8, -11.8), width: 4.4, height: 4);
    canvas.drawOval(head, skin);
    canvas.drawOval(head, _stroke(c.ink, 0.5));
    canvas.drawPath(
      Path()
        ..moveTo(5.6, -14)
        ..relativeQuadraticBezierTo(0.6, -1.6, 1.2, 0)
        ..relativeQuadraticBezierTo(0.6, -1.6, 1.2, 0),
      _fill(ColorTokens.mascotComb),
    );
    canvas.drawPath(
      Path()
        ..moveTo(8.8, -12)
        ..relativeLineTo(2, 0.6)
        ..relativeLineTo(-2, 0.6)
        ..close(),
      c.sun,
    );
    canvas.drawCircle(const Offset(7.4, -12.2), 0.45, _fill(c.ink));
    final tail = _stroke(ColorTokens.mascotChicken, 1);
    canvas.drawLine(const Offset(-6, -1), const Offset(-8.2, -2.6), tail);
    canvas.drawLine(const Offset(-6, 0.6), const Offset(-8.4, 0.8), tail);
  }

  /// La tinaja donde vivía, delante de él: se mete dentro y asoma.
  void _paintJar(Canvas canvas, _Palette c, Offset at) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final edge = _stroke(c.ink, 1.1);
    final body = Path()
      ..moveTo(-22, -10)
      ..quadraticBezierTo(-30, 8, -18, 22)
      ..lineTo(18, 22)
      ..quadraticBezierTo(30, 8, 22, -10)
      ..close();
    canvas.drawPath(body, c.clay);
    canvas.drawPath(body, edge);
    final lip = Path()
      ..moveTo(-23.5, -12)
      ..lineTo(23.5, -12)
      ..lineTo(22, -8)
      ..lineTo(-22, -8)
      ..close();
    canvas.drawPath(lip, _fill(c.clayDark));
    canvas.drawPath(lip, edge);
    canvas.drawLine(const Offset(-24, 2), const Offset(24, 2), edge);
    canvas.drawLine(const Offset(-22, 6), const Offset(22, 6), edge);
    canvas.restore();
  }

  /// El sol que nadie debe tapar.
  void _paintSun(Canvas canvas, _Palette c, Offset at) {
    const r = 6.0;
    canvas.drawCircle(at, r, c.sun);
    final ray = _stroke(c.sun.color, 1.4);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(at + d * (r + 2), at + d * (r + 4.5), ray);
    }
  }

  /// Tres «z» que suben y se apagan, desfasadas un tercio de ciclo. Se dibujan
  /// como trazo, no como texto: son parte de la ilustración.
  void _paintZs(Canvas canvas, _Palette c) {
    const anchors = [Offset(80, 40), Offset(88, 29), Offset(93, 20)];
    const sizes = [6.0, 5.0, 4.0];
    for (var i = 0; i < anchors.length; i++) {
      final t = (aux + i / 3) % 1.0;
      final alpha = t < 0.3 ? (t / 0.3) * 0.9 : 0.9 * (1 - (t - 0.3) / 0.7);
      final o = anchors[i].translate(0, 6 - 16 * t);
      final w = sizes[i];
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(o.dx + w, o.dy)
          ..lineTo(o.dx, o.dy + w)
          ..lineTo(o.dx + w, o.dy + w),
        _stroke(c.accent.withValues(alpha: alpha.clamp(0.0, 1.0)), 1.8),
      );
    }
  }

  void _paintSpeedLines(Canvas canvas, _PoseSpec p, _Palette c) {
    for (final (x1, dy, x2, alpha) in const [
      (3.0, -16.0, 16.0, 0.42),
      (0.0, -3.0, 11.0, 0.26),
      (4.0, 10.0, 13.0, 0.13),
    ]) {
      canvas.drawLine(
          Offset(x1, p.cy + dy), Offset(x2, p.cy + dy), _stroke(c.accent.withValues(alpha: alpha), 3));
    }
  }

  @override
  bool shouldRepaint(_ErizogenesPainter old) =>
      old.pose != pose ||
      old.dark != dark ||
      old.idle != idle ||
      old.aux != aux ||
      old.blink != blink ||
      old.poke != poke ||
      old.look != look ||
      old.petted != petted ||
      old.weary != weary ||
      old.from != from ||
      old.morph != morph ||
      old.beat != beat ||
      old.beatT != beatT ||
      old.antic != antic ||
      old.anticT != anticT ||
      old.breathe != breathe;
}
