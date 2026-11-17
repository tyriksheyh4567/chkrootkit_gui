import '../l10n/app_language.dart';

import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

/// Renders untrusted model prose without loading images or opening URLs.
class ModelMarkdown extends StatelessWidget {
  const ModelMarkdown({required this.data, super.key});
  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MarkdownBody(
      data: data,
      selectable: true,
      fitContent: false,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyMedium,
        h1: theme.textTheme.headlineLarge,
        h2: theme.textTheme.headlineMedium,
        h3: theme.textTheme.headlineSmall,
        h4: theme.textTheme.titleLarge,
        h5: theme.textTheme.titleMedium,
        h6: theme.textTheme.titleSmall,
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        listBullet: theme.textTheme.bodyMedium,
        blockquote: theme.textTheme.bodyMedium,
        tableBody: theme.textTheme.bodyMedium,
        tableHead: theme.textTheme.titleSmall,
        tableBorder: TableBorder.all(color: scheme.outlineVariant),
        textScaler: MediaQuery.textScalerOf(context),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          color: scheme.onSurface,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        ),
        a: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      imageBuilder: (_, _, alt) => Text(
        '[${tr(context, 'Изображение')}: ${alt ?? tr(context, 'без описания')}]',
      ),
      onTapLink: (_, href, _) async {
        final uri = Uri.tryParse(href ?? '');
        if (uri == null ||
            !['https', 'http'].contains(uri.scheme) ||
            uri.host.isEmpty) {
          return;
        }
        await Clipboard.setData(ClipboardData(text: uri.toString()));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: TrText('Ссылка скопирована')));
        }
      },
    );
  }
}
