import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chkrootkit_gui/services/analysis_store.dart';
import 'package:chkrootkit_gui/services/scan_analysis_client.dart';

void main() {
  test('request cache isolates response languages', () {
    String hash(String language) => AnalysisStore.requestHash(
      endpoint: 'https://example.org/v1/chat/completions',
      provider: 'openai',
      model: 'test',
      key: '',
      tool: 'chkrootkit',
      exitCode: 0,
      output: 'log',
      language: language,
    );
    expect(hash('ru'), isNot(hash('en')));
  });
  test('empty GPTunnel key is rejected before HTTP; 401 is authorization and 402 is balance', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var count = 0;
    server.listen((request) async {
      count++;
      await request.drain<void>();
      request.response.statusCode = count == 1 ? 401 : 402;
      await request.response.close();
    });
    Future<String> send(String key) => ScanAnalysisClient().analyze(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'model',
      apiKey: key,
      tool: 'chkrootkit',
      exitCode: 0,
      output: 'log',
      provider: 'gptunnel',
    );
    await expectLater(
      send('  '),
      throwsA(
        isA<ScanAnalysisException>().having(
          (e) => e.message,
          'missing key',
          contains('не введён'),
        ),
      ),
    );
    expect(count, 0);
    await expectLater(
      send('test-key'),
      throwsA(
        isA<ScanAnalysisException>().having(
          (e) => e.message,
          '401',
          contains('авторизацию'),
        ),
      ),
    );
    await expectLater(
      send('test-key'),
      throwsA(
        isA<ScanAnalysisException>().having(
          (e) => e.message,
          '402',
          contains('Недостаточно средств'),
        ),
      ),
    );
  });

  test('root, base URL and complete endpoint resolve to the same GPTunnel endpoint', () {
    for (final url in [
      'https://gptunnel.ru',
      'https://gptunnel.ru/v1/',
      'https://gptunnel.ru/v1/chat/completions',
    ]) {
      expect(
        ScanAnalysisClient.endpointFor(url).toString(),
        'https://gptunnel.ru/v1/chat/completions',
      );
    }
    expect(
      () => ScanAnalysisClient.endpointFor(
        'https://docs.gptunnel.ru/api/chat-completions/',
      ),
      throwsA(isA<ScanAnalysisException>()),
    );
    expect(
      () => ScanAnalysisClient.endpointFor('http://remote.example/v1'),
      throwsA(isA<ScanAnalysisException>()),
    );
  });

  test(
    'GPTunnel uses raw key, OpenAI uses Bearer; model 404 is distinguished',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var count = 0;
      server.listen((request) async {
        count++;
        expect(request.uri.path, '/v1/chat/completions');
        expect(
          request.headers.value('Authorization'),
          count == 1 ? 'secret' : 'Bearer secret',
        );
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['model'], 'selected-model');
        expect(body['messages'][0]['content'], contains('Reply in English'));
        expect(body['messages'][1]['content'], contains('sample log'));
        if (count == 2) {
          request.response.statusCode = 404;
          request.response.write(
            jsonEncode({
              'error': {'code': 'model_not_found', 'message': 'secret'},
            }),
          );
        } else {
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'review manually'},
                },
              ],
            }),
          );
        }
        await request.response.close();
      });
      Future<String> send(String provider) => ScanAnalysisClient().analyze(
        baseUrl: 'http://127.0.0.1:${server.port}/v1/chat/completions',
        provider: provider,
        model: 'selected-model',
        apiKey: 'secret',
        tool: 'chkrootkit',
        exitCode: 1,
        output: 'sample log',
        language: 'en',
      );
      expect(await send('gptunnel'), 'review manually');
      await expectLater(
        send('openai'),
        throwsA(
          isA<ScanAnalysisException>().having(
            (e) => e.message,
            'model error',
            allOf(contains('Модель не найдена'), isNot(contains('secret'))),
          ),
        ),
      );
    },
  );

  test('two SQLite databases survive restart, key opt-in, cache isolation and deletion', () async {
    final temp = await Directory.systemTemp.createTemp('chk-sqlite-');
    addTearDown(() => temp.delete(recursive: true));
    Future<AnalysisStore> open() => AnalysisStore.open(
      password: 'test-passphrase',
      configDirectory: '${temp.path}/config',
      cacheDirectory: '${temp.path}/cache',
    );
    var store = await open();
    const profile = ApiProfile(
      url: 'https://gptunnel.ru/v1',
      model: 'selected-model',
      key: 'secret',
      provider: 'gptunnel',
    );
    await store.saveProfile(profile, saveKey: false);
    expect((await store.loadProfile())!.key, isEmpty);
    await store.saveProfile(profile, saveKey: true);
    String hash(String key) => AnalysisStore.requestHash(
      endpoint: profile.url,
      provider: profile.provider,
      model: profile.model,
      key: key,
      tool: 'chkrootkit',
      exitCode: 1,
      output: 'sample log',
    );
    await store.cache(hash('secret'), 'review manually');
    store.close();
    store = await open();
    try {
      expect((await store.loadProfile())!.key, 'secret');
      expect(await store.lookup(hash('secret')), 'review manually');
      expect(await store.lookup(hash('other-account')), isNull);
      expect(File('${temp.path}/config/api.db').existsSync(), isTrue);
      expect(File('${temp.path}/cache/requests.db').existsSync(), isTrue);
      expect(File('${temp.path}/config/api.db').statSync().mode & 0x1ff, 0x180);
      store.clearCache();
      expect(await store.lookup(hash('secret')), isNull);
      expect(await store.loadProfile(), isNotNull);
      store.deleteProfile();
      expect(await store.loadProfile(), isNull);
    } finally {
      store.close();
    }
  });
}
