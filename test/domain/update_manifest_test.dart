import 'package:kairos/domain/updates/update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ok = {
    'versionCode': 12,
    'versionName': '0.2.0',
    'apk': 'https://github.com/cevasz/Kairos/releases/download/v0.2.0/kairos.apk',
    'notes': 'Erizógenes, el viejo.',
  };

  test('lee un version.json válido', () {
    final m = UpdateManifest.fromJson(ok)!;
    expect(m.versionCode, 12);
    expect(m.versionName, '0.2.0');
    expect(m.apk.host, 'github.com');
    expect(m.notes, 'Erizógenes, el viejo.');
  });

  test('rechaza lo que no sirve: sin código, código 0, sin nombre, http o basura', () {
    expect(UpdateManifest.fromJson(null), isNull);
    expect(UpdateManifest.fromJson('hola'), isNull);
    expect(UpdateManifest.fromJson({...ok, 'versionCode': null}), isNull);
    expect(UpdateManifest.fromJson({...ok, 'versionCode': 0}), isNull);
    expect(UpdateManifest.fromJson({...ok, 'versionName': ''}), isNull);
    expect(UpdateManifest.fromJson({...ok, 'apk': 'http://github.com/x.apk'}), isNull, reason: 'solo https');
    expect(UpdateManifest.fromJson({...ok, 'apk': 'no es un enlace'}), isNull);
  });

  test('las notas son opcionales', () {
    expect(UpdateManifest.fromJson({...ok}..remove('notes'))!.notes, isEmpty);
  });

  test('solo cuenta como nueva si el versionCode es mayor', () {
    final m = UpdateManifest.fromJson(ok)!;
    expect(m.isNewerThan(11), isTrue);
    expect(m.isNewerThan(12), isFalse);
    expect(m.isNewerThan(40), isFalse);
  });
}
