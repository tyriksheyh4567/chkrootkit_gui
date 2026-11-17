import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:chkrootkit_gui/widgets/model_markdown.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('model Markdown formats prose at compact width ($brightness)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data =
          '''## Кратко

**Предупреждение**: проверьте `sqlite-jdbc`.

- Первый пункт
- Второй пункт

> Нужна ручная проверка

```text
${'long_path_' * 35}
INFECTED: Possible Linux.Xor.DDoS
```

| Проверка | Статус |
| --- | --- |
| lkm | not tested |

![diagram](https://example.invalid/private.png)
''';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ModelMarkdown(data: data),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.selectable, isTrue);
      expect(find.byType(Image), findsNothing);
      expect(find.text('[Изображение: diagram]'), findsOneWidget);
      final texts = tester
          .widgetList<flutter.SelectableText>(
            find.byType(flutter.SelectableText),
          )
          .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
          .join('\n');
      expect(texts, contains('Кратко'));
      expect(texts, isNot(contains('## Кратко')));
      expect(texts, contains('Предупреждение'));
      expect(texts, isNot(contains('**Предупреждение**')));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('links copy HTTP URLs but reject local/command schemes', (
    tester,
  ) async {
    final writes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          writes.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ModelMarkdown(data: '[source](https://example.org)'),
        ),
      ),
    );
    final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    body.onTapLink!('bad', 'file:///etc/passwd', '');
    await tester.pump();
    expect(writes, isEmpty);
    body.onTapLink!('source', 'https://example.org', '');
    await tester.pumpAndSettle();
    expect(writes, ['https://example.org']);
    expect(find.text('Ссылка скопирована'), findsOneWidget);
  });
}
