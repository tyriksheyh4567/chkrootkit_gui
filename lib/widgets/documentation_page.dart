import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_language.dart';
import 'model_markdown.dart';

/// Offline documentation bundled with the application in both languages.
class DocumentationPage extends StatefulWidget {
  const DocumentationPage({super.key});
  @override
  State<DocumentationPage> createState() => _DocumentationPageState();
}

class _DocumentationPageState extends State<DocumentationPage> {
  String _topic = 'guide';
  String? _path;
  Future<String>? _document;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final path = 'assets/docs/${AppLanguage.of(context)}/$_topic.md';
    if (_path != path) {
      _path = path;
      _document = rootBundle.loadString(path);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _topic,
          decoration: localizedDecoration(context, labelText: 'Справка'),
          items: [
            for (final entry in const {
              'guide': 'Руководство',
              'scanners': 'Параметры сканеров',
              'threats': 'Справочник угроз',
              'security': 'Хранение данных',
              'building': 'Сборка и релизы',
            }.entries)
              DropdownMenuItem(value: entry.key, child: TrText(entry.value)),
          ],
          onChanged: (topic) {
            if (topic != null) {
              setState(() {
                _topic = topic;
                _load();
              });
            }
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<String>(
            future: _document,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: TrText('Не удалось открыть справку.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                key: ValueKey(_path),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: ModelMarkdown(data: snapshot.data!),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
