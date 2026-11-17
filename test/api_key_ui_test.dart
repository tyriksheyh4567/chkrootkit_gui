import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:chkrootkit_gui/services/analysis_store.dart';
import 'package:chkrootkit_gui/widgets/analysis_panel.dart';
import 'package:chkrootkit_gui/widgets/storage_password_dialog.dart';

void main() {
  for (final mode in [
    StorageMode.create,
    StorageMode.migrate,
    StorageMode.unlock,
  ]) {
    testWidgets('password dialog for $mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoragePasswordDialog(
              inspection: StorageInspection(mode, 'status'),
            ),
          ),
        ),
      );
      expect(
        find.byType(TextField),
        findsNWidgets(mode == StorageMode.unlock ? 1 : 2),
      );
      expect(
        find.text(
          mode == StorageMode.unlock ? 'Разблокировать' : 'Создать и открыть',
        ),
        findsOneWidget,
      );
      if (mode != StorageMode.unlock) {
        await tester.enterText(find.byType(TextField).first, 'test-password');
        await tester.enterText(find.byType(TextField).last, 'other-password');
        await tester.tap(find.text('Создать и открыть'));
        await tester.pump();
        expect(find.text('Пароли не совпадают'), findsWidgets);
      }
    });
  }

  testWidgets(
    'saved key loads after unlock and survives a new scan; empty key is blocked',
    (tester) async {
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('chk-key-ui-'),
      ))!;
      addTearDown(() => temp.delete(recursive: true));
      final config = '${temp.path}/config';
      final cache = '${temp.path}/cache';
      await tester.runAsync(() async {
        final store = await AnalysisStore.open(
          password: 'test-password',
          configDirectory: config,
          cacheDirectory: cache,
        );
        await store.saveProfile(
          const ApiProfile(
            url: 'https://gptunnel.ru/v1',
            model: 'test-model',
            key: 'test-secret',
            provider: 'gptunnel',
          ),
          saveKey: true,
        );
        store.close();
      });
      Widget app(String output) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnalysisPanel(
              key: const ValueKey('panel'),
              tool: 'chkrootkit',
              exitCode: 1,
              output: output,
              configDirectory: config,
              cacheDirectory: cache,
            ),
          ),
        ),
      );
      await tester.pumpWidget(app('scan 1'));
      await tester.tap(find.text('Анализ через API'));
      for (
        var i = 0;
        i < 30 && find.byType(StoragePasswordDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Разблокировать базы'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      await tester.enterText(find.byType(TextField).last, 'test-password');
      await tester.tap(find.text('Разблокировать'));
      await tester.pump(const Duration(milliseconds: 300));
      for (
        var i = 0;
        i < 60 &&
            find
                .text('Ключ загружен из зашифрованной базы.')
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      final field = find.widgetWithText(
        TextField,
        'API-ключ GPTunnel (обязательно)',
      );
      expect(tester.widget<TextField>(field).controller!.text, 'test-secret');
      expect(find.text('Ключ загружен из зашифрованной базы.'), findsOneWidget);
      await tester.pumpWidget(app('scan 2'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'test-secret');
      expect(find.text('Разблокировать базы'), findsNothing);
      await tester.enterText(field, '');
      final send = find.text('Отправить вывод на анализ');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      expect(find.textContaining('GPTunnel требует API-ключ.'), findsWidgets);
      // Dispose before deleting the fixture databases.
      await tester.pumpWidget(const SizedBox());
    },
  );
}
