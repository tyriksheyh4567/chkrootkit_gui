import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'store_cipher.dart';

enum StorageMode { create, unlock, migrate, damaged }

class StorageInspection {
  const StorageInspection(this.mode, this.message);
  final StorageMode mode;
  final String message;
}

class ApiProfile {
  const ApiProfile({
    required this.url,
    required this.model,
    required this.key,
    required this.provider,
  });
  final String url;
  final String model;
  final String key;
  final String provider;
}

class AnalysisStore {
  AnalysisStore._(this._api, this._cache, this._cipher, this.paths);
  final Database _api;
  final Database _cache;
  final StoreCipher _cipher;
  final List<String> paths;
  bool _closed = false;

  static List<String> databasePaths({
    String? configDirectory,
    String? cacheDirectory,
  }) {
    final env = Platform.environment;
    final home = env['HOME'] ?? Directory.current.path;
    return [
      '${configDirectory ?? '${env['XDG_CONFIG_HOME'] ?? '$home/.config'}/chkrootkit_gui'}/api.db',
      '${cacheDirectory ?? '${env['XDG_CACHE_HOME'] ?? '$home/.cache'}/chkrootkit_gui'}/requests.db',
    ];
  }

  static bool _envelopeValid(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return data['v'] == 1 &&
          base64Decode(data['nonce'] as String).length == 12 &&
          base64Decode(data['mac'] as String).length == 16 &&
          base64Decode(data['cipher'] as String).isNotEmpty;
    } on Object {
      return false;
    }
  }

  static Future<StorageInspection> inspect({
    String? configDirectory,
    String? cacheDirectory,
  }) async {
    final paths = databasePaths(
      configDirectory: configDirectory,
      cacheDirectory: cacheDirectory,
    );
    final apiExists = await File(paths[0]).exists();
    final cacheExists = await File(paths[1]).exists();
    if (!apiExists && !cacheExists) {
      return const StorageInspection(
        StorageMode.create,
        'Базы ещё не созданы. Задайте новый пароль шифрования.',
      );
    }
    if (!apiExists) {
      return const StorageInspection(
        StorageMode.damaged,
        'Есть кэш, но нет базы API с параметрами шифрования. Восстановите api.db из резервной копии либо удалите обе базы с подтверждением.',
      );
    }
    Database? api;
    Database? cache;
    try {
      api = sqlite3.open(paths[0], mode: OpenMode.readOnly);
      if (api.select('PRAGMA quick_check').first.values.first != 'ok') {
        throw const FormatException();
      }
      bool table(Database db, String name) => db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [name],
      ).isNotEmpty;
      final encrypted = table(api, 'encryption');
      StorageMode mode;
      if (encrypted) {
        final meta = api.select(
          'SELECT id, salt, verification FROM encryption',
        );
        if (meta.length != 1 ||
            meta.first['id'] != 1 ||
            base64Decode(meta.first['salt'] as String).length != 32 ||
            !_envelopeValid(meta.first['verification'] as String)) {
          throw const FormatException();
        }
        api.select('SELECT id, payload FROM encrypted_profile LIMIT 0');
        for (final row in api.select('SELECT payload FROM encrypted_profile')) {
          if (!_envelopeValid(row['payload'] as String)) {
            throw const FormatException();
          }
        }
        mode = StorageMode.unlock;
      } else if (table(api, 'profile') && !table(api, 'encrypted_profile')) {
        api.select(
          'SELECT id, url, model, api_key, provider FROM profile LIMIT 0',
        );
        mode = StorageMode.migrate;
      } else {
        throw const FormatException();
      }
      if (cacheExists) {
        cache = sqlite3.open(paths[1], mode: OpenMode.readOnly);
        if (cache.select('PRAGMA quick_check').first.values.first != 'ok') {
          throw const FormatException();
        }
        if (table(cache, 'encrypted_responses') && mode == StorageMode.unlock) {
          cache.select(
            'SELECT request_hash, payload, created FROM encrypted_responses LIMIT 0',
          );
          for (final row in cache.select(
            'SELECT payload FROM encrypted_responses',
          )) {
            if (!_envelopeValid(row['payload'] as String)) {
              throw const FormatException();
            }
          }
        } else if (table(cache, 'responses')) {
          cache.select(
            'SELECT request_hash, answer, created FROM responses LIMIT 0',
          );
        } else {
          throw const FormatException();
        }
      }
      return StorageInspection(
        mode,
        mode == StorageMode.migrate
            ? 'Найден старый незашифрованный профиль. Задайте пароль для его шифрования. Старый кэш будет очищен.'
            : cacheExists
            ? 'Найдены сформированные зашифрованные базы. Введите существующий пароль.'
            : 'Найдена зашифрованная база API. Введите существующий пароль; отсутствующий кэш будет создан заново.',
      );
    } on Object {
      return const StorageInspection(
        StorageMode.damaged,
        'Структура баз повреждена или создание не завершено. Данные не изменены. Восстановите базы из копии либо удалите их с подтверждением.',
      );
    } finally {
      api?.dispose();
      cache?.dispose();
    }
  }

  static Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      for (final suffix in ['', '-journal', '-wal', '-shm']) {
        final file = File('$path$suffix');
        if (await file.exists()) await file.delete();
      }
    }
  }

  static Future<AnalysisStore> open({
    required String password,
    String? configDirectory,
    String? cacheDirectory,
  }) async {
    if (password.length < 8) {
      throw const FormatException(
        'Пароль должен содержать минимум 8 символов.',
      );
    }
    final inspection = await inspect(
      configDirectory: configDirectory,
      cacheDirectory: cacheDirectory,
    );
    if (inspection.mode == StorageMode.damaged) {
      throw FormatException(inspection.message);
    }
    final env = Platform.environment;
    final home = env['HOME'] ?? Directory.current.path;
    final config = Directory(
      configDirectory ??
          '${env['XDG_CONFIG_HOME'] ?? '$home/.config'}/chkrootkit_gui',
    );
    final cache = Directory(
      cacheDirectory ??
          '${env['XDG_CACHE_HOME'] ?? '$home/.cache'}/chkrootkit_gui',
    );
    for (final dir in [config, cache]) {
      await dir.create(recursive: true);
      if (Platform.isLinux) {
        final result = await Process.run('chmod', ['700', dir.path]);
        if (result.exitCode != 0) {
          throw const FileSystemException('Не удалось защитить каталог базы');
        }
      }
    }
    Database? api;
    Database? responses;
    try {
      api = sqlite3.open('${config.path}/api.db');
      for (final db in [api]) {
        db.execute('PRAGMA journal_mode=DELETE');
        db.execute('PRAGMA busy_timeout=3000');
        db.execute('PRAGMA secure_delete=ON');
      }
      api.execute(
        'CREATE TABLE IF NOT EXISTS encryption (id INTEGER PRIMARY KEY CHECK(id=1), salt TEXT NOT NULL, verification TEXT NOT NULL)',
      );
      final metadata = api.select(
        'SELECT salt, verification FROM encryption WHERE id=1',
      );
      final salt = metadata.isEmpty
          ? await StoreCipher.newSalt()
          : base64Decode(metadata.first['salt'] as String);
      final cipher = await StoreCipher.derive(password, salt);
      if (metadata.isEmpty) {
        api.execute('INSERT INTO encryption VALUES(1, ?, ?)', [
          base64Encode(salt),
          await cipher.seal('chkrootkit-gui', 'verification'),
        ]);
      } else {
        try {
          final verification = await cipher.open(
            metadata.first['verification'] as String,
            'verification',
          );
          if (verification != 'chkrootkit-gui') throw const FormatException();
        } on Object {
          throw const FormatException(
            'Неверный пароль или повреждены данные базы.',
          );
        }
      }
      // A wrong password must not create an empty cache and break the next unlock.
      responses = sqlite3.open('${cache.path}/requests.db');
      responses.execute('PRAGMA journal_mode=DELETE');
      responses.execute('PRAGMA busy_timeout=3000');
      responses.execute('PRAGMA secure_delete=ON');
      api.execute(
        'CREATE TABLE IF NOT EXISTS encrypted_profile (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)',
      );
      responses.execute(
        'CREATE TABLE IF NOT EXISTS encrypted_responses (request_hash TEXT PRIMARY KEY, payload TEXT NOT NULL, created INTEGER NOT NULL)',
      );
      // Migrate the previous plaintext schema without retaining plaintext pages.
      if (api
          .select("SELECT name FROM sqlite_master WHERE name='profile'")
          .isNotEmpty) {
        final rows = api.select('SELECT * FROM profile WHERE id=1');
        if (rows.isNotEmpty) {
          final row = rows.first;
          final payload = await cipher.seal(
            jsonEncode({
              'url': row['url'],
              'model': row['model'],
              'key': row['api_key'],
              'provider': row['provider'],
            }),
            'profile',
          );
          api.execute('INSERT OR REPLACE INTO encrypted_profile VALUES(1, ?)', [
            payload,
          ]);
        }
        api.execute('DROP TABLE profile');
        api.execute('VACUUM');
      }
      // Old cache is disposable: discard unencrypted responses during migration.
      if (responses
          .select("SELECT name FROM sqlite_master WHERE name='responses'")
          .isNotEmpty) {
        responses.execute('DROP TABLE responses');
        responses.execute('VACUUM');
      }
      for (final path in [
        '${config.path}/api.db',
        '${cache.path}/requests.db',
      ]) {
        if (Platform.isLinux) {
          final result = await Process.run('chmod', ['600', path]);
          if (result.exitCode != 0) {
            throw const FileSystemException('Не удалось защитить базу');
          }
        }
      }
      return AnalysisStore._(api, responses, cipher, [
        '${config.path}/api.db',
        '${cache.path}/requests.db',
      ]);
    } catch (_) {
      api?.dispose();
      responses?.dispose();
      rethrow;
    }
  }

  Future<ApiProfile?> loadProfile() async {
    final rows = _api.select(
      'SELECT payload FROM encrypted_profile WHERE id=1',
    );
    if (rows.isEmpty) return null;
    final row = jsonDecode(
      await _cipher.open(rows.first['payload'] as String, 'profile'),
    ) as Map<String, dynamic>;
    return ApiProfile(
      url: row['url'] as String,
      model: row['model'] as String,
      key: row['key'] as String,
      provider: row['provider'] as String,
    );
  }

  Future<void> saveProfile(ApiProfile profile, {required bool saveKey}) async {
    final payload = await _cipher.seal(
      jsonEncode({
        'url': profile.url,
        'model': profile.model,
        'key': saveKey ? profile.key : '',
        'provider': profile.provider,
      }),
      'profile',
    );
    _api.execute('INSERT OR REPLACE INTO encrypted_profile VALUES(1, ?)', [
      payload,
    ]);
  }

  // Version the prompt contract and isolate cache entries by credential/account.
  static String requestHash({
    required String endpoint,
    required String provider,
    required String model,
    required String key,
    required String tool,
    required int exitCode,
    required String output,
    String language = 'ru',
  }) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            'scan-analysis-v2',
            language,
            endpoint,
            provider,
            model,
            sha256.convert(utf8.encode(key)).toString(),
            tool,
            exitCode,
            output,
          ]),
        ),
      )
      .toString();

  Future<String?> lookup(String hash) async {
    final threshold = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    _cache.execute('DELETE FROM encrypted_responses WHERE created < ?', [
      threshold,
    ]);
    final rows = _cache.select(
      'SELECT payload FROM encrypted_responses WHERE request_hash=?',
      [hash],
    );
    return rows.isEmpty
        ? null
        : await _cipher.open(rows.first['payload'] as String, 'cache:$hash');
  }

  Future<void> cache(String hash, String answer) async {
    final payload = await _cipher.seal(answer, 'cache:$hash');
    _cache.execute(
      'INSERT OR REPLACE INTO encrypted_responses VALUES (?, ?, ?)',
      [hash, payload, DateTime.now().millisecondsSinceEpoch],
    );
    _cache.execute(
      'DELETE FROM encrypted_responses WHERE request_hash NOT IN (SELECT request_hash FROM encrypted_responses ORDER BY created DESC LIMIT 100)',
    );
  }

  void clearCache() => _cache.execute('DELETE FROM encrypted_responses');
  void deleteProfile() => _api.execute('DELETE FROM encrypted_profile');
  void close() {
    if (_closed) return;
    _closed = true;
    _api.dispose();
    _cache.dispose();
  }
}
