import 'dart:convert';
import 'dart:io';

import 'package:chkrootkit_gui/services/scan_analysis_client.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  int count = 0;
  server.listen((request) async {
    count++;
    check(request.uri.path == '/v1/chat/completions', 'Wrong endpoint');
    check(
      request.headers.value('authorization') == 'Bearer test-key',
      'Missing bearer',
    );
    final body = jsonDecode(await utf8.decoder.bind(request).join());
    check(body['model'] == 'test-model', 'Missing model');
    check(body['messages'][1]['content'].contains('INFECTED'), 'Missing log');
    if (count == 2) {
      request.response.statusCode = 401;
      request.response.write('secret-body-test-key');
    } else if (count == 3) {
      request.response.write('{"choices":[]}');
    } else {
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'Проверьте вручную'},
            },
          ],
        }),
      );
    }
    await request.response.close();
  });
  Future<String> send(String url, {String output = 'INFECTED'}) async {
    final client = ScanAnalysisClient();
    try {
      return await client.analyze(
        baseUrl: url,
        model: 'test-model',
        apiKey: 'test-key',
        tool: 'chkrootkit',
        exitCode: 1,
        output: output,
      );
    } finally {
      client.close();
    }
  }

  final url = 'http://127.0.0.1:${server.port}/v1/';
  try {
    check(await send(url) == 'Проверьте вручную', 'Invalid success response');
    for (final endpoint in [url, url, 'http://remote.example/v1']) {
      try {
        await send(endpoint);
        throw StateError('Expected failure');
      } on ScanAnalysisException catch (error) {
        check(!error.message.contains('test-key'), 'Leaked key');
      }
    }
    try {
      await send(url, output: 'X' * 200001);
      throw StateError('Expected size limit');
    } on ScanAnalysisException {
      /* expected */
    }
    check(count == 3, 'Unexpected network requests');
    stdout.writeln(
      'PASS: endpoint, bearer, request body, success, HTTP error redaction, malformed response, remote HTTP rejection, log limit',
    );
  } finally {
    await server.close(force: true);
  }
}
