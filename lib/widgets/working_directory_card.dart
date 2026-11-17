import '../l10n/app_language.dart';

import 'package:material_ui/material_ui.dart';

class WorkingDirectoryCard extends StatelessWidget {
  const WorkingDirectoryCard({
    required this.controller,
    required this.tool,
    required this.arguments,
    required this.enabled,
    super.key,
  });
  final TextEditingController controller;
  final String tool;
  final List<String> arguments;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            'Параметры запуска',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SelectableText('Команда: $tool ${arguments.join(' ')}'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: enabled,
            autocorrect: false,
            decoration: localizedDecoration(
              context,
              labelText: 'Рабочий каталог (cwd)',
              hintText: 'Авто: каталог реального бинарника',
              helperMaxLines: 5,
              helperText: 'Пустое поле выбирает каталог реального бинарника. Допустим абсолютный путь или ~/. Для chkrootkit здесь должны находиться вспомогательные бинарники. Каталог сканирования задаётся отдельно.',
            ),
          ),
        ],
      ),
    ),
  );
}
