import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/updates/update_manifest.dart';

/// Dónde publica cada canal su `version.json` (§52). La estable lee el
/// Release más reciente (`latest/download` redirige siempre a él, y un
/// pre-release nunca es «latest»); la Dev lee el pre-release fijo `dev`, que
/// `tool/publicar-dev.sh` reemplaza en cada entrega.
final Uri kUpdateManifestUrl =
    Uri.parse('https://github.com/cevasz/Kairos/releases/latest/download/version.json');
final Uri kDevManifestUrl =
    Uri.parse('https://github.com/cevasz/Kairos/releases/download/dev/version.json');

/// La versión instalada, la red y el instalador de Android.
///
/// Todo falla en silencio hacia `null`/`false`: sin red o fuera de Android la
/// app sigue igual, solo que no se entera de versiones nuevas.
class UpdateChannel {
  UpdateChannel({HttpClient? client, Uri? manifest})
      : _client = client ?? HttpClient(),
        _manifest = manifest ?? kUpdateManifestUrl;

  /// El `version.json` del canal de esta compilación.
  final Uri _manifest;

  static const _channel = MethodChannel('kairos/updates');

  /// Leer el manifiesto es un GET pequeño; si tarda más, no hay red útil.
  static const Duration _manifestTimeout = Duration(seconds: 10);

  /// El APK pesa decenas de megas: se da margen por cada trozo, no al total.
  static const Duration _chunkTimeout = Duration(seconds: 30);

  final HttpClient _client;

  /// `(versionCode, versionName)` de lo que está instalado.
  Future<(int, String)?> installed() async {
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('version');
      final code = info?['code'];
      final name = info?['name'];
      if (code is int && name is String) return (code, name);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
    return null;
  }

  Future<UpdateManifest?> fetchManifest([Uri? url]) async {
    try {
      final request = await _client.getUrl(url ?? _manifest).timeout(_manifestTimeout);
      request.followRedirects = true;
      final response = await request.close().timeout(_manifestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join().timeout(_manifestTimeout);
      return UpdateManifest.fromJson(jsonDecode(body));
    } on Object {
      return null;
    }
  }

  /// Descarga el APK a [target] e informa del avance de 0 a 1 (null si el
  /// servidor no dice el tamaño). Devuelve si terminó bien.
  Future<bool> download(Uri apk, File target, {void Function(double? progress)? onProgress}) async {
    try {
      final request = await _client.getUrl(apk).timeout(_chunkTimeout);
      request.followRedirects = true;
      final response = await request.close().timeout(_chunkTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return false;
      }
      await target.parent.create(recursive: true);
      final sink = target.openWrite();
      final total = response.contentLength;
      var received = 0;
      try {
        await for (final chunk in response.timeout(_chunkTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(total > 0 ? received / total : null);
        }
      } finally {
        await sink.close();
      }
      return total <= 0 || received == total;
    } on Object {
      return false;
    }
  }

  /// Abre el instalador de Android con el APK descargado. La primera vez
  /// Android pide permiso para instalar apps desde Kairós.
  Future<bool> install(File apk) async {
    try {
      return await _channel.invokeMethod<bool>('install', {'path': apk.path}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
