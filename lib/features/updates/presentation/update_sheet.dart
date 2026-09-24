import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/updates/update_manifest.dart';
import '../../../l10n/strings.g.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/motion.dart';
import '../../../theme/tokens.g.dart';
import '../../../theme/transitions.dart';
import '../application/update_providers.dart';

/// Muestra el aviso de versión nueva arriba, una vez por sesión. Lo llama el
/// shell cuando la comprobación del arranque encuentra algo.
void showUpdateBanner(BuildContext context, WidgetRef ref, UpdateManifest update) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null || ref.read(updateBannerDismissedProvider)) return;
  void close() {
    ref.read(updateBannerDismissedProvider.notifier).state = true;
    messenger.hideCurrentMaterialBanner();
  }

  messenger.showMaterialBanner(
    MaterialBanner(
      leading: const Icon(Icons.system_update_outlined),
      content: Text(SUpdates.bannerLine(version: update.versionName)),
      actions: [
        TextButton(onPressed: close, child: const Text(SUpdates.later)),
        FilledButton(
          onPressed: () {
            close();
            openUpdateSheet(context, update);
          },
          child: const Text(SUpdates.update),
        ),
      ],
    ),
  );
}

Future<void> openUpdateSheet(BuildContext context, UpdateManifest update) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => UpdateSheet(update: update),
    );

/// La versión nueva, qué trae y el botón que la descarga e instala.
class UpdateSheet extends ConsumerWidget {
  const UpdateSheet({required this.update, super.key});

  final UpdateManifest update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(updateDownloadProvider);
    final secondary = context.themed(ColorTokens.textSecondary);
    final busy = download is UpdateDownloading || download is UpdateInstalling;

    final status = switch (download) {
      UpdateDownloading(:final progress) => Column(
          key: const ValueKey('downloading'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress),
            SizedBox(height: SpaceTokens.s),
            Text(
              progress == null
                  ? SUpdates.downloadingUnknown
                  : SUpdates.downloading(n: (progress * 100).floor()),
              style: context.type(TypeTokens.bodyM, color: secondary),
            ),
          ],
        ),
      UpdateInstalling() => Text(
          SUpdates.installing,
          key: const ValueKey('installing'),
          style: context.type(TypeTokens.bodyM, color: secondary),
        ),
      UpdateFailed() => Text(
          SUpdates.failed,
          key: const ValueKey('failed'),
          style: context.type(TypeTokens.bodyM, color: context.themed(ColorTokens.accentUrgent)),
        ),
      UpdateIdle() => const SizedBox.shrink(key: ValueKey('idle')),
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SpaceTokens.screenMargin,
          0,
          SpaceTokens.screenMargin,
          SpaceTokens.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(SUpdates.available(version: update.versionName), style: context.type(TypeTokens.titleM)),
            if (update.notes.isNotEmpty) ...[
              SizedBox(height: SpaceTokens.s),
              Text(update.notes, style: context.type(TypeTokens.bodyM)),
            ],
            SizedBox(height: SpaceTokens.m),
            Text(SUpdates.installHint, style: context.type(TypeTokens.bodyM, color: secondary)),
            SizedBox(height: SpaceTokens.l),
            AnimatedSize(
              duration: MotionGuard.of(context).duration(MotionDurations.fast),
              curve: MotionCurves.easeOutCubic,
              child: StateSwitcher(child: status),
            ),
            SizedBox(height: SpaceTokens.l),
            FilledButton(
              onPressed: busy ? null : () => ref.read(updateDownloadProvider.notifier).start(update),
              child: Text(download is UpdateFailed ? SLoadError.retry : SUpdates.update),
            ),
          ],
        ),
      ),
    );
  }
}
