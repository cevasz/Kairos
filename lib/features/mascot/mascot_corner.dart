import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/strings.g.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.g.dart';
import 'application/mascot_voice.dart';
import 'mascot_companion.dart';
import 'mascot_view.dart';

/// Erizógenes en la esquina de toda la app.
///
/// Vive encima del `Navigator` (en `MaterialApp.builder`), así que acompaña
/// también en el detalle de una materia, los formularios y las hojas. Para no
/// tapar nada, en reposo solo asoma la cabeza por el borde izquierdo, a la
/// altura de la barra de navegación. Cuando algo pasa
/// ([MascotCornerController.react]) sale entero con su globo y, al rato, se
/// vuelve a esconder.
///
/// Tocarlo cuando asoma le saca una sentencia; tocarlo mientras habla lo
/// calla. Con el teclado abierto se esconde del todo: ahí estorba.
class MascotCorner extends ConsumerWidget {
  const MascotCorner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider).valueOrNull?.mascotaEsquina ?? false;
    if (!enabled) return child;

    final line = ref.watch(mascotCornerProvider);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 0;
    final guard = MotionGuard.of(context);
    final slide = guard.duration(MotionDurations.mascotCornerSlide);
    final curve = guard.curve(MotionCurves.easeOutCubic);
    final size = MascotTokens.sizeCorner;
    final speaking = line != null;

    // A la altura de la barra inferior del shell, que es donde menos estorba:
    // por encima de ella en las pestañas y en el margen de abajo en lo demás.
    final bottom = media.padding.bottom +
        (NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight) +
        SpaceTokens.s;

    // En reposo asoma un poco más de la mitad; hablando, sale entero.
    final dx = keyboard ? -size : (speaking ? SpaceTokens.s : -size * 0.45);

    void onTap() {
      final c = ref.read(mascotCornerProvider.notifier);
      speaking ? c.dismiss() : c.muse();
    }

    return Stack(
      children: [
        child,
        AnimatedPositioned(
          duration: slide,
          curve: curve,
          left: dx,
          bottom: bottom,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // MascotView ya es un botón para el lector de pantalla; aquí solo
              // cambia qué hace tocarlo.
              MascotView(
                pose: line?.pose ?? MascotPose.reposo,
                size: size,
                host: MascotHost.corner,
                onTap: onTap,
                semanticHint: SMascotVoice.hintCorner,
                beat: line?.beat,
                beatKey: line?.serial,
                antic: line?.antic,
                anticKey: line?.serial,
              ),
              AnimatedSwitcher(
                duration: slide,
                switchInCurve: curve,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: a, alignment: Alignment.bottomLeft, child: c),
                ),
                child: speaking
                    ? ConstrainedBox(
                        key: ValueKey(line.serial),
                        constraints: BoxConstraints(
                          maxWidth: media.size.width - size - SpaceTokens.screenMargin * 2,
                        ),
                        child: GestureDetector(
                          onTap: onTap,
                          child: Material(
                            type: MaterialType.transparency,
                            child: MascotBubble(
                              child: Text(
                                line.text,
                                style: context.type(
                                  TypeTokens.bodyS,
                                  color: context.themed(ColorTokens.textPrimary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
