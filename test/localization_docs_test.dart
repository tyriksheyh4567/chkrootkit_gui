import 'package:chkrootkit_gui/l10n/app_language.dart';
import 'package:chkrootkit_gui/widgets/documentation_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('offline documentation is included in both languages', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final language in ['ru', 'en']) {
      for (final topic in [
        'guide',
        'scanners',
        'threats',
        'security',
        'building',
      ]) {
        expect(
          await rootBundle.loadString('assets/docs/$language/$topic.md'),
          isNotEmpty,
        );
      }
    }
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'English guide and Russian switch at compact width ($brightness)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(String language) => AppLanguage(
          code: language,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.teal,
                brightness: brightness,
              ),
            ),
            home: const Scaffold(body: DocumentationPage()),
          ),
        );
        await tester.runAsync(() async {
          await rootBundle.loadString('assets/docs/en/guide.md');
          await rootBundle.loadString('assets/docs/ru/guide.md');
        });
        await tester.pumpWidget(app('en'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('User guide'), findsOneWidget);
        expect(
          find.textContaining('chkrootkit GUI 1.0.0 user guide'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('User guide'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Scanner arguments').last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.textContaining('Scanner arguments and directories'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        // The selected topic remains selected when switching languages.
        await tester.pumpWidget(app('ru'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Параметры сканеров'), findsOneWidget);
        expect(
          find.textContaining('Параметры сканеров и каталоги'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
