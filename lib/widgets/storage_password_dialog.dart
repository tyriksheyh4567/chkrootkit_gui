import '../l10n/app_language.dart';

import 'package:material_ui/material_ui.dart';

import '../services/analysis_store.dart';

class StoragePasswordDialog extends StatefulWidget {
  const StoragePasswordDialog({required this.inspection, super.key});
  final StorageInspection inspection;
  @override
  State<StoragePasswordDialog> createState() => _StoragePasswordDialogState();
}

class _StoragePasswordDialogState extends State<StoragePasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool get _creating => widget.inspection.mode != StorageMode.unlock;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.length < 8) {
      setState(() => _error = 'Минимум 8 символов');
      return;
    }
    if (_creating && _password.text != _confirmation.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: TrText(
      widget.inspection.mode == StorageMode.migrate
          ? 'Зашифровать старые базы'
          : _creating
          ? 'Создать пароль баз'
          : 'Разблокировать базы',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrText(widget.inspection.message),
            if (_creating)
              const TrText(
                'Пароль не сохраняется; без него восстановить данные нельзя.',
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: localizedDecoration(
                context,
                labelText: _creating ? 'Новый пароль' : 'Пароль',
                errorText: _error,
              ),
              onSubmitted: _creating ? null : (_) => _submit(),
            ),
            if (_creating) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: localizedDecoration(
                  context,
                  labelText: 'Повторите пароль',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const TrText('Отмена'),
      ),
      FilledButton(
        onPressed: _submit,
        child: TrText(_creating ? 'Создать и открыть' : 'Разблокировать'),
      ),
    ],
  );
}
