import '../l10n/app_language.dart';

import 'package:material_ui/material_ui.dart';

enum AccentChoice {
  system('Системный', Colors.teal),
  teal('Бирюзовый', Colors.teal),
  blue('Синий', Colors.blue),
  purple('Фиолетовый', Colors.deepPurple),
  orange('Оранжевый', Colors.deepOrange),
  green('Зелёный', Colors.green),
  rose('Розовый', Colors.pink);

  const AccentChoice(this.label, this.seed);
  final String label;
  final Color seed;
}

class AccentPicker extends StatelessWidget {
  const AccentPicker({
    required this.choice,
    required this.onChanged,
    super.key,
  });
  final AccentChoice choice;
  final ValueChanged<AccentChoice> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<AccentChoice>(
    tooltip: tr(context, 'Цвет приложения'),
    icon: const Icon(Icons.palette_outlined),
    initialValue: choice,
    onSelected: onChanged,
    itemBuilder: (_) => AccentChoice.values
        .map((value) => PopupMenuItem(value: value, child: TrText(value.label)))
        .toList(),
  );
}
