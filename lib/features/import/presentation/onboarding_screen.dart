import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/layout.dart';
import '../../../theme/tokens.g.dart';
import '../../backup/application/backup_controller.dart';
import '../../backup/data/backup.dart';
import '../../mascot/mascot_view.dart';
import '../../subjects/presentation/subjects_screen.dart';
import 'import_screen.dart';

/// A1: la bienvenida. Es la pantalla de inicio mientras no haya ninguna
/// actividad; en cuanto existe una, la app arranca en el shell.
///
/// No hay «saltar»: sin datos no hay nada que enseñar detrás, y las dos
/// salidas de aquí son justamente las dos formas de meter datos.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    // Una app vacía también es la que recibe una copia: la Dev
                    // al estrenarse, o un teléfono nuevo (§51). Restaurar trae
                    // datos y la app pasa sola al shell.
                    TextButton(
                      onPressed: () => _restore(context, ref),
                      child: const Text(SBackup.restore),
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

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(backupControllerProvider).restore();
    final text = switch (result) {
      ImportCancelled() || ImportDoneResult() => null,
      ImportRejected(problem: BackupProblem.notADatabase) => SBackup.notADatabase,
      ImportRejected(problem: BackupProblem.foreign) => SBackup.foreign,
      ImportRejected(problem: BackupProblem.tooNew) => SBackup.tooNew,
      ImportRejected() => SBackup.restoreFailed,
    };
    if (text != null) messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}
