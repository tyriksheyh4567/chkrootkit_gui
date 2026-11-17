import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:chkrootkit_gui/widgets/accent_picker.dart';
import 'package:chkrootkit_gui/widgets/database_delete_dialog.dart';

void main() {
  testWidgets(
    'deletion requires explicit confirmation; cancel leaves data alone',
    (tester) async {
      var deletions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  if (await confirmDatabaseDeletion(context)) deletions++;
                },
                child: const Text('Стереть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Стереть'));
      await tester.pumpAndSettle();
      expect(deletions, 0);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(deletions, 0);
      await tester.tap(find.text('Стереть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить базы'));
      await tester.pumpAndSettle();
      expect(deletions, 1);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'manual accent can be selected without dynamic colors ($brightness)',
      (tester) async {
        var choice = AccentChoice.teal;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: choice.seed,
                  brightness: brightness,
                ),
              ),
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    AccentPicker(
                      choice: choice,
                      onChanged: (next) => setState(() => choice = next),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Цвет приложения'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Оранжевый'));
        await tester.pumpAndSettle();
        expect(choice, AccentChoice.orange);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
