import '../l10n/app_language.dart';

import 'package:material_ui/material_ui.dart';

Future<bool> confirmDatabaseDeletion(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('Удалить обе базы?'),
        content: const TrText(
          'Будут удалены API-настройки, сохранённый ключ, кэш и параметры шифрования. Восстановление через приложение невозможно. Экспортированные .log останутся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const TrText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const TrText('Удалить базы'),
          ),
        ],
      ),
    ) ??
    false;
