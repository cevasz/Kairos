import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/strings.g.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../theme/transitions.dart';
import 'application/mascot_voice.dart';
import 'mascot_view.dart';

/// Erizógenes corriendo con su monóculo mientras algo carga, en lugar de un
/// spinner.
///
/// Si la espera pasa de [MotionDurations.mascotLoaderLong] se cansa: corre
/// más corto, baja los párpados, mira hacia atrás de vez en cuando y cambia a
/// las frases de espera larga. No es un error, pero tampoco finge que va
/// rápido.
///
/// Con «reducir movimiento» el erizo se queda quieto en la postura de carrera
/// y la frase cambia igual, sin animarse.
class MascotLoader extends StatefulWidget {
  const MascotLoader({this.lines, this.inline = false, super.key});

  /// Frases propias de esta espera; por defecto, las de carga genéricas.
  final List<String>? lines;

  /// En línea: erizo pequeño y frase al lado, para una fila o una cabecera.
  final bool inline;

  @override
  State<MascotLoader> createState() => _MascotLoaderState();
}

class _MascotLoaderState extends State<MascotLoader> {
  bool _weary = false;
  Timer? _long;

  @override
  void initState() {
    super.initState();
    _long = Timer(MotionDurations.mascotLoaderLong, () {
      if (mounted) setState(() => _weary = true);
    });
  }

  @override
  void dispose() {
    _long?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inline = widget.inline;
    final mascot = MascotView(
      pose: MascotPose.rodando,
      size: inline ? MascotTokens.sizeLoaderInline : MascotTokens.sizeLoader,
      host: MascotHost.loader,
      interactive: false,
      weary: _weary,
    );
    final text = RotatingLine(
      // La clave reinicia el sorteo: al cansarse, la frase cambia ya y no al
      // siguiente tic.
      key: ValueKey(_weary),
      lines: _weary ? SMascotVoice.loadingLongLines : (widget.lines ?? SMascotVoice.loadingLines),
      textAlign: inline ? TextAlign.start : TextAlign.center,
      style: context.type(TypeTokens.bodyM, color: context.themed(ColorTokens.textSecondary)),
    );

    if (inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [mascot, const SizedBox(width: SpaceTokens.m), Flexible(child: text)],
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpaceTokens.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [mascot, const SizedBox(height: SpaceTokens.l), text],
        ),
      ),
    );
  }
}

/// Una frase de Erizógenes que cambia sola cada
/// [MotionDurations.mascotLoaderLine]: una espera larga con la misma frase se
/// lee como una app colgada.
class RotatingLine extends StatefulWidget {
  const RotatingLine({required this.lines, this.style, this.textAlign, super.key});

  final List<String> lines;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<RotatingLine> createState() => _RotatingLineState();
}

class _RotatingLineState extends State<RotatingLine> {
  final _picker = VariantPicker();
  late String _line = _picker.pick(widget.lines);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(MotionDurations.mascotLoaderLine, (_) {
      if (mounted) setState(() => _line = _picker.pick(widget.lines));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StateSwitcher(
        child: Text(_line, key: ValueKey(_line), textAlign: widget.textAlign, style: widget.style),
      );
}
