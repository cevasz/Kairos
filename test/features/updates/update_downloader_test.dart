import 'dart:io';

import 'package:kairos/core/platform/update_channel.dart';
import 'package:kairos/domain/updates/update_manifest.dart';
import 'package:kairos/features/updates/application/update_providers.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChannel extends UpdateChannel {
  _FakeChannel({this.downloads = true, this.installs = true});

  final bool downloads;
  final bool installs;
  File? opened;

  @override
  Future<bool> download(Uri apk, File target, {void Function(double? progress)? onProgress}) async {
    for (var i = 0; i <= 1000; i++) {
      onProgress?.call(i / 1000);
    }
    if (!downloads) return false;
    await target.parent.create(recursive: true);
    await target.writeAsString('apk');
    return true;
  }

  @override
  Future<bool> install(File apk) async {
    opened = apk;
    return installs;
  }
}

void main() {
  final update = UpdateManifest(
    versionCode: 7,
    versionName: '0.2.0',
    apk: Uri.parse('https://example.com/kairos.apk'),
  );
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('kairos_updates'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('descarga a cache/updates y abre el instalador', () async {
    final channel = _FakeChannel();
    final states = <UpdateDownload>[];
    final d = UpdateDownloader(channel, cacheDir: () async => tmp);
    d.addListener(states.add, fireImmediately: false);

    await d.start(update);

    expect(channel.opened?.path, endsWith('/updates/kairos-7.apk'));
    expect(d.state, isA<UpdateIdle>());
    // Mil trozos, pero como mucho un aviso por punto porcentual.
    expect(states.whereType<UpdateDownloading>().length, lessThanOrEqualTo(102));
    expect(states.whereType<UpdateInstalling>(), hasLength(1));
  });

  test('si la descarga o el instalador fallan, lo dice y se puede reintentar', () async {
    final noNet = UpdateDownloader(_FakeChannel(downloads: false), cacheDir: () async => tmp);
    await noNet.start(update);
    expect(noNet.state, isA<UpdateFailed>());

    final noInstaller = UpdateDownloader(_FakeChannel(installs: false), cacheDir: () async => tmp);
    await noInstaller.start(update);
    expect(noInstaller.state, isA<UpdateFailed>());
    await noInstaller.start(update);
    expect(noInstaller.state, isA<UpdateFailed>(), reason: 'reintentar vuelve a intentarlo, no se queda colgado');
  });

  test('UpdateCheck solo ofrece lo que es más nuevo que lo instalado', () {
    expect(UpdateCheck(installed: (6, '0.1.0'), latest: update).available, update);
    expect(UpdateCheck(installed: (7, '0.2.0'), latest: update).available, isNull);
    expect(const UpdateCheck(installed: (6, '0.1.0'), latest: null).available, isNull);
    expect(const UpdateCheck(installed: (6, '0.1.0'), latest: null).reachable, isFalse);
    expect(UpdateCheck(installed: null, latest: update).available, isNull, reason: 'fuera de Android no hay nada que instalar');
  });
}
