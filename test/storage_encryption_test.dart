import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:chkrootkit_gui/services/analysis_store.dart';
import 'package:chkrootkit_gui/services/store_cipher.dart';

void main() {
  test(
    'AES-GCM random nonces and authenticated context/tamper detection',
    () async {
      final cipher = await StoreCipher.derive(
        'test-password',
        await StoreCipher.newSalt(),
      );
      final a = await cipher.seal('sensitive-value', 'profile');
      final b = await cipher.seal('sensitive-value', 'profile');
      expect(a, isNot(b));
      expect(await cipher.open(a, 'profile'), 'sensitive-value');
      await expectLater(cipher.open(a, 'other-context'), throwsA(anything));
      final tampered = jsonDecode(a) as Map<String, dynamic>;
      tampered['mac'] = base64Encode(List.filled(16, 0));
      await expectLater(
        cipher.open(jsonEncode(tampered), 'profile'),
        throwsA(anything),
      );
    },
  );
  test('migrate plaintext, reject wrong password, erase and create new encrypted databases', () async {
    final temp = await Directory.systemTemp.createTemp('chk-encryption-');
    addTearDown(() => temp.delete(recursive: true));
    final paths = AnalysisStore.databasePaths(
      configDirectory: '${temp.path}/config',
      cacheDirectory: '${temp.path}/cache',
    );
    for (final p in paths) {
      await File(p).parent.create(recursive: true);
    }
    final legacy = sqlite3.open(paths[0]);
    legacy.execute(
      'CREATE TABLE profile (id INTEGER PRIMARY KEY, url TEXT, model TEXT, api_key TEXT, provider TEXT)',
    );
    legacy.execute(
      "INSERT INTO profile VALUES(1, 'https://gptunnel.ru/v1', 'model', 'SUPER-SECRET-KEY', 'gptunnel')",
    );
    legacy.dispose();
    final legacyCache = sqlite3.open(paths[1]);
    legacyCache.execute(
      'CREATE TABLE responses (request_hash TEXT, answer TEXT, created INTEGER)',
    );
    legacyCache.execute(
      "INSERT INTO responses VALUES('old', 'OLD-PRIVATE-LOG', 1)",
    );
    legacyCache.dispose();
    Future<AnalysisStore> open(String pass) => AnalysisStore.open(
      password: pass,
      configDirectory: '${temp.path}/config',
      cacheDirectory: '${temp.path}/cache',
    );
    var store = await open('test-password');
    expect((await store.loadProfile())!.key, 'SUPER-SECRET-KEY');
    expect(await store.lookup('old'), isNull);
    await store.cache('hash', 'PRIVATE-ANALYSIS');
    store.close();
    for (final p in paths) {
      final bytes = latin1.decode(await File(p).readAsBytes());
      expect(bytes, isNot(contains('SUPER-SECRET-KEY')));
      expect(bytes, isNot(contains('PRIVATE-ANALYSIS')));
      expect(bytes, isNot(contains('OLD-PRIVATE-LOG')));
    }
    await expectLater(open('wrong-password'), throwsA(isA<FormatException>()));
    store = await open('test-password');
    expect(await store.lookup('hash'), 'PRIVATE-ANALYSIS');
    store.close();
    await AnalysisStore.deleteFiles(paths);
    for (final p in paths) {
      expect(await File(p).exists(), isFalse);
    }
    store = await open('new-password');
    expect(await store.loadProfile(), isNull);
    expect(await store.lookup('hash'), isNull);
    store.close();
  });
}
