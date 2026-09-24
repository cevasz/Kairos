import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.g.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.g.dart';
import '../../theme/transitions.dart';
import 'application/mascot_tips.dart';
import 'application/mascot_voice.dart';
import 'mascot_view.dart';

/// Erizógenes con algo útil que decir.
///
/// Toca al erizo (o al globo) y pasa al siguiente consejo; mantenlo pulsado y
/// suelta una de sus frases. Los consejos salen de [mascotTipsProvider]: nunca
/// inventa, y si no tiene nada que decir no aparece.
///
/// Dos formas: `compact` es la fila de la cabecera de Hoy; la otra es el
/// estado vacío, con el erizo grande y el texto debajo.
class MascotCompanion extends ConsumerStatefulWidget {
  const MascotCompanion.compact({super.key})
      : hero = false,
        fallback = null,
        heroPose = null,
        heroTitle = null;

  /// Para el día vacío: el erizo grande en `heroPose` y, hasta que lo toques,
  /// `fallback` como texto.
  const MascotCompanion.hero({
    required String this.fallback,
    required MascotPose this.heroPose,
    this.heroTitle,
    super.key,
  }) : hero = true;

  final bool hero;

  /// Va entre el erizo y su frase, como el titular del día vacío.
  final Widget? heroTitle;
  final String? fallback;
  final MascotPose? heroPose;

  @override
  ConsumerState<MascotCompanion> createState() => _MascotCompanionState();
}

class _MascotCompanionState extends ConsumerState<MascotCompanion> {
  /// -1 en el héroe: todavía enseña su frase de siempre.
  late int _index = widget.hero ? -1 : 0;

  /// Frase de caricia en curso; tapa al consejo hasta el siguiente toque.
  String? _petLine;
  final _random = math.Random();

  /// Uno de cada [MascotTokens.anticEveryTaps] toques no pasa de consejo:
  /// hace una ocurrencia, la que venga a cuento, con su frase.
  int _taps = 0;
  MascotAntic? _antic;
  String? _anticLine;
  int _anticSerial = 0;
  final _picker = VariantPicker();

  void _next(int count) => setState(() {
        _petLine = null;
        _anticLine = null;
        _taps++;
        if (_taps % MascotTokens.anticEveryTaps == 0) {
          final antic = ref.read(mascotAnticProvider);
          _antic = antic;
          _anticLine = _picker.pick(antic.lines);
          _anticSerial++;
          return;
        }
        if (count == 0) return;
        _index = (_index + 1) % count;
      });

  void _pet() => setState(() {
        _petLine = SMascotVoice.petLines[_random.nextInt(SMascotVoice.petLines.length)];
      });

  @override
  Widget build(BuildContext context) {
    final tips = ref.watch(mascotTipsProvider);
    if (!widget.hero && tips.isEmpty) return const SizedBox.shrink();

    final i = tips.isEmpty || _index < 0 ? -1 : _index % tips.length;
    final tip = i < 0 ? null : tips[i];
    final text = _anticLine ?? _petLine ?? tip?.text ?? widget.fallback ?? '';
    final pose = widget.hero ? widget.heroPose! : (tip?.pose ?? MascotPose.reposo);

    final mascot = MascotView(
      pose: _petLine != null && !widget.hero ? MascotPose.satisfecho : pose,
      size: widget.hero ? MascotTokens.sizeEmptyDay : MascotTokens.sizeCompanion,
      host: widget.hero ? MascotHost.emptyDay : MascotHost.companion,
      onTap: () => _next(tips.length),
      onLongPress: _pet,
      antic: _antic,
      anticKey: _anticSerial,
    );

    final line = StateSwitcher(
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: widget.hero ? TextAlign.center : TextAlign.start,
        style: context.type(
          widget.hero ? TypeTokens.bodyL : TypeTokens.bodyM,
          color: context.themed(widget.hero ? ColorTokens.textSecondary : ColorTokens.textPrimary),
        ),
      ),
    );

    final dots = tips.length > 1 ? _Dots(count: tips.length, active: i) : null;

    if (widget.hero) {
      return Column(
        children: [
          mascot,
          const SizedBox(height: SpaceTokens.xl),
          if (widget.heroTitle != null) ...[widget.heroTitle!, const SizedBox(height: SpaceTokens.s)],
          GestureDetector(onTap: () => _next(tips.length), child: line),
          if (dots != null) ...[const SizedBox(height: SpaceTokens.s), dots],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        mascot,
        const SizedBox(width: SpaceTokens.s),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _next(tips.length),
            child: MascotBubble(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: MotionGuard.of(context).duration(MotionDurations.fast),
                    curve: MotionCurves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: line,
                  ),
                  if (dots != null) ...[const SizedBox(height: SpaceTokens.s), dots],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Globo de diálogo con la cola hacia el erizo, abajo a la izquierda.
class MascotBubble extends StatelessWidget {
  const MascotBubble({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fill = ColorTokens.surfaceCard.of(b);
    final border = ColorTokens.surfaceBorder.of(b);
    return CustomPaint(
      painter: _TailPainter(fill: fill, border: border),
      child: Container(
        margin: const EdgeInsets.only(left: SpaceTokens.s),
        padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.m, vertical: SpaceTokens.m),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(RadiusTokens.card),
          border: Border.all(color: border, width: BorderTokens.hairline),
        ),
        child: child,
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.fill, required this.border});
  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    // Un triángulo pequeño que sale del borde izquierdo, cerca de la base:
    // ahí queda la boca del erizo.
    final y = size.height - SpaceTokens.l;
    final tip = Offset(0, y + SpaceTokens.xs);
    final path = Path()
      ..moveTo(SpaceTokens.s + BorderTokens.hairline, y - SpaceTokens.s)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(SpaceTokens.s + BorderTokens.hairline, y + SpaceTokens.xs);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = BorderTokens.hairline,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.fill != fill || old.border != border;
}

/// Cuántos consejos hay y cuál se ve. Pequeño: es un índice, no un control.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: MotionGuard.of(context).duration(MotionDurations.fast),
            curve: MotionCurves.easeOutCubic,
            margin: const EdgeInsets.only(right: SpaceTokens.xs),
            width: i == active ? SpaceTokens.m : SpaceTokens.xs + SpaceTokens.xs / 2,
            height: SpaceTokens.xs + SpaceTokens.xs / 2,
            decoration: BoxDecoration(
              color: i == active ? ColorTokens.accentPrimary.of(b) : ColorTokens.surfaceBorder.of(b),
              borderRadius: BorderRadius.circular(RadiusTokens.full),
            ),
          ),
      ],
    );
  }
}
