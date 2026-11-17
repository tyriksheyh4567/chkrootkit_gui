import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:chkrootkit_gui/services/scan_launch.dart';
import 'package:chkrootkit_gui/widgets/working_directory_card.dart';

void main() {
  test('scan root supports mounted systems only for chkrootkit', () {
    expect(ScanLaunch.scanRootFor('chkrootkit', ''), '/');
    expect(
      ScanLaunch.scanRootFor('chkrootkit', '~/mounted', home: '/home/test'),
      '/home/test/mounted',
    );
    expect(
      () => ScanLaunch.scanRootFor('chkrootkit', 'relative'),
      throwsFormatException,
    );
    expect(
      () => ScanLaunch.scanRootFor('rkhunter', '/mnt'),
      throwsFormatException,
    );
    expect(
      () => ScanLaunch.scanRootFor('unhide', '/mnt'),
      throwsFormatException,
    );
    expect(
      () => ScanLaunch.scanRootFor('lynis', '/mnt'),
      throwsFormatException,
    );
  });
  test(
    'automatic cwd follows binary symlink; explicit cwd and ~/ supported',
    () async {
      final temp = await Directory.systemTemp.createTemp('chk-cwd-');
      addTearDown(() => temp.delete(recursive: true));
      final real = File('${temp.path}/release dir/chkrootkit');
      await real.parent.create();
      await real.writeAsString('test');
      final link = Link('${temp.path}/chkrootkit');
      await link.create(real.path);
      final auto = await ScanLaunch.prepare(link.path, '');
      expect(auto.executable, real.path);
      expect(auto.workingDirectory, real.parent.path);
      final selected = await ScanLaunch.prepare(
        link.path,
        '~/scanner dir',
        home: temp.path,
      );
      expect(selected.workingDirectory, '${temp.path}/scanner dir');
      await expectLater(
        ScanLaunch.prepare(link.path, 'relative'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        ScanLaunch.prepare(link.path, '/path\u0000bad'),
        throwsA(isA<FormatException>()),
      );
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'cwd card is editable, labeled and disabled during scan ($brightness)',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget app(bool enabled) => MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkingDirectoryCard(
                controller: controller,
                tool: 'chkrootkit',
                arguments: const [],
                enabled: enabled,
              ),
            ),
          ),
        );
        await tester.pumpWidget(app(true));
        await tester.enterText(find.byType(TextField), '~/scanner');
        expect(controller.text, '~/scanner');
        expect(
          find.textContaining('Каталог сканирования задаётся отдельно'),
          findsOneWidget,
        );
        await tester.pumpWidget(app(false));
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
