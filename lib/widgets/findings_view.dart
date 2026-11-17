import '../l10n/app_language.dart';

import 'package:material_ui/material_ui.dart';

import '../services/scan_report.dart';
import 'analysis_panel.dart';

class FindingsView extends StatelessWidget {
  const FindingsView({
    required this.report,
    required this.alerts,
    required this.onExport,
    super.key,
  });
  final ScanReport? report;
  final List<String> alerts;
  final VoidCallback onExport;
  @override
  Widget build(BuildContext context) {
    final report = this.report;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TrText(
          'Находки последней проверки',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: TrText(
            report == null
                ? 'Проверка ещё не завершена. Запустите сканер на вкладке «Проверка».'
                : '${report.tool} • ${report.time.toLocal()} • код завершения ${report.exitCode}',
          ),
        ),
        if (report != null) ...[
          TrText('Каталог сканирования: ${report.scanRoot}'),
          if (report.executable != null)
            SelectableText('${tr(context, 'Бинарник: ')}${report.executable}'),
          if (report.workingDirectory != null)
            SelectableText(
              '${tr(context, 'Рабочий каталог: ')}${report.workingDirectory}',
            ),
          const SizedBox(height: 12),
          const TrText(
            'Предупреждения сканера требуют ручной проверки. Учитывайте ошибки запуска и пропущенные тесты.',
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const TrText(
              'Строк с известными маркерами предупреждений не найдено. Это не гарантирует отсутствие угроз.',
            ),
          ...alerts.map(
            (line) => Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: SelectableText(line),
                subtitle: TrText('Источник: ${report.tool}'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onExport,
              icon: const Icon(Icons.save_alt),
              label: const TrText('Экспорт .log'),
            ),
          ),
          const SizedBox(height: 12),
          AnalysisPanel(
            key: const ValueKey('analysis-panel'),
            tool: report.tool,
            exitCode: report.exitCode,
            output: report.output,
          ),
        ],
      ],
    );
  }
}
