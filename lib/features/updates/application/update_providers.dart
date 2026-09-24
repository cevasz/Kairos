import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/platform/update_channel.dart';
import '../../../domain/updates/update_manifest.dart';

final updateChannelProvider = Provider<UpdateChannel>((ref) => UpdateChannel());

/// Lo que se sabe de las versiones: la instalada y la última publicada.
class UpdateCheck {
  const UpdateCheck({required this.installed, required this.latest});

  /// `(versionCode, versionName)`; null fuera de Android.
  final (int, String)? installed;

  /// Null sin red o si el Release no trae un `version.json` válido.
  final UpdateManifest? latest;

  bool get reachable => latest != null;

  /// La versión que vale la pena instalar, si la hay.
  UpdateManifest? get available {
    final mine = installed;
    final theirs = latest;
    if (mine == null || theirs == null) return null;
    return theirs.isNewerThan(mine.$1) ? theirs : null;
  }
}

/// Se consulta una vez al abrir la app. «Buscar actualización» en Ajustes la
/// invalida para volver a mirar. Sin red no falla: dice que no se pudo.
final updateCheckProvider = FutureProvider<UpdateCheck>((ref) async {
  final channel = ref.watch(updateChannelProvider);
  final installed = await channel.installed();
  final latest = await channel.fetchManifest();
  return UpdateCheck(installed: installed, latest: latest);
});

/// El aviso de versión nueva sale una vez por sesión: «Luego» es luego.
final updateBannerDismissedProvider = StateProvider<bool>((ref) => false);

sealed class UpdateDownload {
  const UpdateDownload();
}

class UpdateIdle extends UpdateDownload {
  const UpdateIdle();
}

class UpdateDownloading extends UpdateDownload {
  const UpdateDownloading(this.progress);

  /// 0..1, o null si el servidor no dijo cuánto pesa.
  final double? progress;
}

class UpdateInstalling extends UpdateDownload {
  const UpdateInstalling();
}

class UpdateFailed extends UpdateDownload {
  const UpdateFailed();
}

final updateDownloadProvider = StateNotifierProvider<UpdateDownloader, UpdateDownload>(
  (ref) => UpdateDownloader(ref.watch(updateChannelProvider)),
);

class UpdateDownloader extends StateNotifier<UpdateDownload> {
  UpdateDownloader(this._channel, {Future<Directory> Function()? cacheDir})
      : _cacheDir = cacheDir ?? getTemporaryDirectory,
        super(const UpdateIdle());

  final UpdateChannel _channel;
  final Future<Directory> Function() _cacheDir;

  /// Descarga el APK a `cache/updates/` (lo único que el FileProvider
  /// comparte) y abre el instalador. Android hace el resto: la versión nueva
  /// se instala encima y los datos se quedan.
  Future<void> start(UpdateManifest update) async {
    if (state is UpdateDownloading || state is UpdateInstalling) return;
    state = const UpdateDownloading(null);
    final dir = await _cacheDir();
    final file = File(p.join(dir.path, 'updates', 'kairos-${update.versionCode}.apk'));
    var lastPercent = -1;
    final ok = await _channel.download(
      update.apk,
      file,
      onProgress: (progress) {
        // Un aviso por punto porcentual: el APK llega en miles de trozos y
        // redibujar con cada uno no aporta nada.
        final percent = progress == null ? -1 : (progress * 100).floor();
        if (!mounted || (percent == lastPercent && state is UpdateDownloading)) return;
        lastPercent = percent;
        state = UpdateDownloading(progress);
      },
    );
    if (!mounted) return;
    if (!ok) {
      state = const UpdateFailed();
      return;
    }
    state = const UpdateInstalling();
    final opened = await _channel.install(file);
    if (!mounted) return;
    state = opened ? const UpdateIdle() : const UpdateFailed();
  }
}
