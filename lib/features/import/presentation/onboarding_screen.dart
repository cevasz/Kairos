import 'package:flutter/material.dart';

import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout.dart';
import '../../../theme/tokens.g.dart';
import '../../mascot/mascot_view.dart';
import '../../subjects/presentation/subjects_screen.dart';
import 'import_screen.dart';

/// A1: la bienvenida. Es la pantalla de inicio mientras no haya ninguna
/// actividad; en cuanto existe una, la app arranca en el shell.
///
/// No hay «saltar»: sin datos no hay nada que enseñar detrás, y las dos
/// salidas de aquí son justamente las dos formas de meter datos.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ContentWidth(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: LayoutTokens.screenPaddingHHero),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Center(
                      child: MascotView(
                        pose: MascotPose.reposo,
                        size: MascotTokens.sizeSplash,
                        host: MascotHost.splash,
                      ),
                    ),
                    SizedBox(height: SpaceTokens.xl),
                    Text(
                      SOnboarding.brand,
                      textAlign: TextAlign.center,
                      style: context.type(TypeTokens.displayM),
                    ),
                    SizedBox(height: SpaceTokens.m),
                    Text(
                      SOnboarding.tagline,
                      textAlign: TextAlign.center,
                      style: context.type(TypeTokens.titleS),
                    ),
                    SizedBox(height: SpaceTokens.s),
                    Text(
                      SOnboarding.subtitle,
                      textAlign: TextAlign.center,
                      style: context.type(TypeTokens.bodyL, color: ColorTokens.textSecondary.of(b)),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => openImport(context),
                      child: const Text(SOnboarding.ctaImport),
                    ),
                    SizedBox(height: SpaceTokens.s),
                    OutlinedButton(
                      onPressed: () => openSubjectForm(context),
                      child: const Text(SOnboarding.ctaManual),
                    ),
                    SizedBox(height: SpaceTokens.l),
                    Text(
                      SOnboarding.privacyFooter,
                      textAlign: TextAlign.center,
                      style: context.type(TypeTokens.captionS, color: ColorTokens.textTertiary.of(b)),
                    ),
                    SizedBox(height: SpaceTokens.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
