import 'package:flutter/material.dart';

import '../../l10n/strings.g.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.g.dart';
import '../../theme/transitions.dart';
import 'application/mascot_voice.dart';
import 'mascot_view.dart';

/// Lo que se ve cuando una pantalla no pudo leer sus datos.
///
/// Erizógenes entra tropezando y confundido, dice una frase seca, explica qué
/// pasó (los datos siguen en el teléfono) y ofrece reintentar. El texto de la
/// excepción no se enseña de entrada: está detrás de «Ver detalle», para quien
/// lo necesite.
///
/// No va nunca junto a una materia perdida ni a la calculadora imposible: ahí
/// no hay error de carga, hay una mala noticia, y el contrato la deja sin
/// mascota.
class MascotError extends StatefulWidget {
  const MascotError({required this.error, required this.onRetry, super.key});

  final Object error;

  /// Vuelve a pedir los datos. Quien pone el error sabe qué recargar.
  final VoidCallback onRetry;

  @override
  State<MascotError> createState() => _MascotErrorState();
}

class _MascotErrorState extends State<MascotError> {
  /// La frase se sortea una vez: si cambiara con cada rebuild parecería que
  /// la pantalla parpadea.
  late final String _title = VariantPicker().pick(SLoadError.titleVariants);
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final secondary = context.themed(ColorTokens.textSecondary);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SpaceTokens.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotView(
              pose: MascotPose.confundido,
              size: MascotTokens.sizeLoadError,
              host: MascotHost.loadError,
              beat: MascotBeat.stumble,
            ),
            const SizedBox(height: SpaceTokens.l),
            Text(_title, textAlign: TextAlign.center, style: context.type(TypeTokens.titleM)),
            const SizedBox(height: SpaceTokens.s),
            Text(
              SLoadError.body,
              textAlign: TextAlign.center,
              style: context.type(TypeTokens.bodyM, color: secondary),
            ),
            const SizedBox(height: SpaceTokens.xl),
            FilledButton(onPressed: widget.onRetry, child: const Text(SLoadError.retry)),
            const SizedBox(height: SpaceTokens.s),
            TextButton(
              onPressed: () => setState(() => _details = !_details),
              child: Text(_details ? SLoadError.hideDetails : SLoadError.details),
            ),
            AnimatedSize(
              duration: MotionGuard.of(context).duration(MotionDurations.fast),
              curve: MotionCurves.easeOutCubic,
              child: StateSwitcher(
                child: _details
                    ? SelectableText(
                        '${widget.error}',
                        key: const ValueKey(true),
                        textAlign: TextAlign.center,
                        style: context.type(TypeTokens.captionS, color: context.themed(ColorTokens.textTertiary)),
                      )
                    : const SizedBox.shrink(key: ValueKey(false)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
