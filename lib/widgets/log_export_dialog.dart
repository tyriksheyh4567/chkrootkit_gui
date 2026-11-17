import '../l10n/app_language.dart';

import 'package:material_ui/material_ui.dart';

class LogExportDialog extends StatefulWidget {
  const LogExportDialog({required this.initialPath, super.key});
  final String initialPath;
  @override
  State<LogExportDialog> createState() => _LogExportDialogState();
}

class _LogExportDialogState extends State<LogExportDialog> {
  late final _path = TextEditingController(text: widget.initialPath);
  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const TrText('Экспорт вывода последней проверки'),
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: _path,
        decoration: localizedDecoration(
          context,
          labelText: 'Полный путь к .log',
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const TrText('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _path.text.trim()),
        child: const TrText('Сохранить'),
      ),
    ],
  );
}
