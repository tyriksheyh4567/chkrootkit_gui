import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:chkrootkit_gui/services/analysis_store.dart';

void main() {
  test('inspect distinguishes fresh, encrypted, missing cache and damaged files without modifying them', () async {
    final temp = await Directory.systemTemp.createTemp('chk-inspect-');
    addTearDown(() => temp.delete(recursive: true));
    final config = '${temp.path}/config';
    final cache = '${temp.path}/cache';
    Future<StorageInspection> inspect() =>
        AnalysisStore.inspect(configDirectory: config, cacheDirectory: cache);
    expect((await inspect()).mode, StorageMode.create);
    expect(await Directory(config).exists(), isFalse);
    final store = await AnalysisStore.open(
      password: 'test-password',
      configDirectory: config,
      cacheDirectory: cache,
    );
    store.close();
    expect((await inspect()).mode, StorageMode.unlock);
    await File('$cache/requests.db').delete();
    expect((await inspect()).mode, StorageMode.unlock);
    await expectLater(
      AnalysisStore.open(
        password: 'wrong-password',
        configDirectory: config,
        cacheDirectory: cache,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(await File('$cache/requests.db').exists(), isFalse);
    expect((await inspect()).mode, StorageMode.unlock);
    final before = await File('$config/api.db').readAsBytes();
    await File('$cache/requests.db').writeAsString('not a database');
    expect((await inspect()).mode, StorageMode.damaged);
    await expectLater(
      AnalysisStore.open(
        password: 'test-password',
        configDirectory: config,
        cacheDirectory: cache,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(await File('$config/api.db').readAsBytes(), before);
    expect(await File('$cache/requests.db').readAsString(), 'not a database');
    await File('$config/api.db').delete();
    expect((await inspect()).mode, StorageMode.damaged);
  });

  test('legacy and incomplete schemas are distinguished', () async {
    final temp = await Directory.systemTemp.createTemp('chk-schema-');
    addTearDown(() => temp.delete(recursive: true));
    await Directory('${temp.path}/config').create();
    final file = '${temp.path}/config/api.db';
    var db = sqlite3.open(file);
    db.execute(
      'CREATE TABLE profile (id INTEGER, url TEXT, model TEXT, api_key TEXT, provider TEXT)',
    );
    db.dispose();
    Future<StorageInspection> inspect() => AnalysisStore.inspect(
      configDirectory: '${temp.path}/config',
      cacheDirectory: '${temp.path}/cache',
    );
    expect((await inspect()).mode, StorageMode.migrate);
    db = sqlite3.open(file);
    db.execute(
      'CREATE TABLE encryption (id INTEGER, salt TEXT, verification TEXT)',
    );
    db.dispose();
    expect((await inspect()).mode, StorageMode.damaged);
  });
}
