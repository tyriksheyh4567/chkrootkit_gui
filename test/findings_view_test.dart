import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:chkrootkit_gui/services/scan_report.dart';
import 'package:chkrootkit_gui/widgets/findings_view.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Findings empty and populated at compact width: $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app(ScanReport? report, List<String> alerts) => MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: FindingsView(report: report, alerts: alerts, onExport: () {}),
          ),
        ),
      );
      await tester.pumpWidget(app(null, []));
      expect(find.textContaining('Проверка ещё не завершена'), findsOneWidget);
      expect(find.text('Diamorphine'), findsNothing);
      expect(find.text('Анализ через API'), findsNothing);
      final report = ScanReport(
        tool: 'chkrootkit',
        output: 'Checking: INFECTED',
        exitCode: 1,
        time: DateTime(2026),
      );
      await tester.pumpWidget(app(report, ['Checking: INFECTED']));
      expect(find.text('Checking: INFECTED'), findsOneWidget);
      expect(find.text('Источник: chkrootkit'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(report, []));
      expect(
        find.textContaining('Строк с известными маркерами'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
