/// Lo que publica cada versión junto a su APK: `version.json` en el Release
/// de GitHub. La app lo lee para saber si hay algo más nuevo que ella.
///
/// Dart puro: se prueba sin teléfono ni red.
class UpdateManifest {
  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.apk,
    this.notes = '',
  });

  /// El `versionCode` de Android. Es lo único que se compara: crece con cada
  /// compilación y Android no instala uno menor encima de uno mayor.
  final int versionCode;

  /// Lo que se le enseña a la persona («0.2.0»).
  final String versionName;
  final Uri apk;
  final String notes;

  /// Null si el JSON no trae lo mínimo o el enlace no es https: un manifiesto
  /// roto no debe acabar en una descarga rara.
  static UpdateManifest? fromJson(Object? json) {
    if (json is! Map) return null;
    final code = json['versionCode'];
    final name = json['versionName'];
    final apk = Uri.tryParse('${json['apk'] ?? ''}');
    if (code is! int || code <= 0 || name is! String || name.isEmpty) return null;
    if (apk == null || apk.scheme != 'https' || apk.host.isEmpty) return null;
    final notes = json['notes'];
    return UpdateManifest(
      versionCode: code,
      versionName: name,
      apk: apk,
      notes: notes is String ? notes : '',
    );
  }

  bool isNewerThan(int installedVersionCode) => versionCode > installedVersionCode;
}
