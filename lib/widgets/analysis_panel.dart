import '../l10n/app_language.dart';

import 'package:material_ui/material_ui.dart';

import '../services/scan_analysis_client.dart';
import '../services/analysis_store.dart';
import 'storage_password_dialog.dart';
import 'model_markdown.dart';
import 'database_delete_dialog.dart';

class AnalysisPanel extends StatefulWidget {
  const AnalysisPanel({
    required this.tool,
    required this.exitCode,
    required this.output,
    this.configDirectory,
    this.cacheDirectory,
    super.key,
  });
  final String tool;
  final int exitCode;
  final String output;
  final String? configDirectory;
  final String? cacheDirectory;
  @override
  State<AnalysisPanel> createState() => _AnalysisPanelState();
}

class _AnalysisPanelState extends State<AnalysisPanel>
    with AutomaticKeepAliveClientMixin<AnalysisPanel> {
  @override
  bool get wantKeepAlive => true;
  final _url = TextEditingController(text: 'https://gptunnel.ru/v1');
  final _model = TextEditingController();
  final _key = TextEditingController();
  ScanAnalysisClient? _client;
  String? _answer;
  String? _error;
  bool _busy = false;
  bool _loading = true;
  bool _loadStarted = false;
  bool _saveKey = false;
  bool _keyLoaded = false;
  bool _storedHasKey = false;
  bool _showKey = false;
  String? _keyError;
  bool _useCache = true;
  bool _fromCache = false;
  String _provider = 'gptunnel';
  AnalysisStore? _store;

  @override
  void didUpdateWidget(covariant AnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.output != widget.output ||
        oldWidget.tool != widget.tool ||
        oldWidget.exitCode != widget.exitCode) {
      if (_client != null) {
        _client!.close();
        _client = null;
        _busy = false;
      }
      _answer = null;
      _fromCache = false;
      _error = null;
      // API configuration and the unlocked store belong to the session, not a scan.
    }
  }

  void _applyProfile(ApiProfile? profile) {
    if (profile == null) {
      _storedHasKey = false;
      _error = 'В базе нет сохранённого API-профиля. Введите настройки и сохраните их.';
      return;
    }
    _url.text = profile.url;
    _model.text = profile.model;
    _key.text = profile.key;
    _provider = profile.provider == 'gptunnel' ? 'gptunnel' : 'openai';
    _storedHasKey = profile.key.trim().isNotEmpty;
    _keyLoaded = _storedHasKey;
    _saveKey = _storedHasKey;
    _keyError = null;
    _error = _storedHasKey ? null : 'Профиль загружен, но API-ключ в нём не сохранён. Введите ключ; для следующих запусков включите сохранение ключа и нажмите «Сохранить API».';
  }

  Future<void> _reloadProfile() async {
    setState(() => _busy = true);
    try {
      final profile = await _store!.loadProfile();
      if (mounted) setState(() => _applyProfile(profile));
    } on Object {
      if (mounted) {
        setState(() => _error = 'Не удалось расшифровать API-профиль.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    _loadStarted = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inspection = await AnalysisStore.inspect(
        configDirectory: widget.configDirectory,
        cacheDirectory: widget.cacheDirectory,
      );
      if (!mounted) return;
      if (inspection.mode == StorageMode.damaged) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const TrText('Базы повреждены или не завершены'),
            content: TrText(inspection.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const TrText('Закрыть'),
              ),
            ],
          ),
        );
        _loadStarted = false;
        if (mounted) setState(() => _error = inspection.message);
        return;
      }
      final password = await showDialog<String>(
        context: context,
        builder: (_) => StoragePasswordDialog(inspection: inspection),
      );
      if (!mounted || password == null) {
        _loadStarted = false;
        return;
      }
      final store = await AnalysisStore.open(
        password: password,
        configDirectory: widget.configDirectory,
        cacheDirectory: widget.cacheDirectory,
      );
      if (!mounted) {
        store.close();
        return;
      }
      _store = store;
      final profile = await store.loadProfile();
      if (!mounted) {
        store.close();
        return;
      }
      _applyProfile(profile);
    } on Object catch (error) {
      _store?.close();
      _store = null;
      _loadStarted = false;
      if (mounted) {
        _error = error is FormatException
            ? error.message
            : 'Не удалось открыть SQLite-базы. Проверьте права и libsqlite3.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saveKey && _key.text.trim().isEmpty) {
      setState(() => _keyError = 'Введите ключ перед сохранением.');
      return;
    }
    setState(() => _busy = true);
    try {
      ScanAnalysisClient.endpointFor(_url.text);
      await _store!.saveProfile(
        ApiProfile(
          url: _url.text.trim(),
          model: _model.text.trim(),
          key: _key.text.trim(),
          provider: _provider,
        ),
        saveKey: _saveKey,
      );
      if (!mounted) return;
      setState(() {
        _error = null;
        _storedHasKey = _saveKey && _key.text.trim().isNotEmpty;
        if (!_storedHasKey) _keyLoaded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TrText(
            _storedHasKey
                ? 'Настройки и зашифрованный ключ сохранены в api.db'
                : 'Настройки сохранены БЕЗ API-ключа. Ключ останется только в текущем сеансе.',
          ),
        ),
      );
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось сохранить настройки. Проверьте URL и доступ к базе.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearCache() {
    try {
      _store!.clearCache();
      setState(() {
        _answer = null;
        _fromCache = false;
        _error = null;
      });
    } on Object {
      setState(() => _error = 'Не удалось очистить кэш.');
    }
  }

  void _deleteProfile() {
    try {
      _store!.deleteProfile();
      setState(() {
        _key.clear();
        _saveKey = false;
        _keyLoaded = false;
        _storedHasKey = false;
        _keyError = null;
        _error = null;
      });
    } on Object {
      setState(() => _error = 'Не удалось удалить сохранённый профиль.');
    }
  }

  Future<void> _wipeDatabases() async {
    final confirmed = await confirmDatabaseDeletion(context);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final paths =
        _store?.paths ??
        AnalysisStore.databasePaths(
          configDirectory: widget.configDirectory,
          cacheDirectory: widget.cacheDirectory,
        );
    _store?.close();
    _store = null;
    try {
      await AnalysisStore.deleteFiles(paths);
      if (!mounted) return;
      setState(() {
        _key.clear();
        _model.clear();
        _url.text = 'https://gptunnel.ru/v1';
        _provider = 'gptunnel';
        _saveKey = false;
        _keyLoaded = false;
        _storedHasKey = false;
        _keyError = null;
        _answer = null;
        _fromCache = false;
        _error = null;
      });
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось удалить базы полностью. Проверьте права файлов.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loadStarted = false;
          _loading = false;
        });
      }
    }
  }

  void _cancel() {
    _client?.close();
    _client = null;
    setState(() => _busy = false);
  }

  Future<void> _analyze() async {
    final language = AppLanguage.of(context);
    if (_provider == 'gptunnel' && _key.text.trim().isEmpty) {
      setState(() {
        _keyError = 'GPTunnel требует API-ключ. Введите его или загрузите сохранённый профиль.';
        _error = _keyError;
      });
      return;
    }
    final client = ScanAnalysisClient();
    _client = client;
    setState(() {
      _busy = true;
      _answer = null;
      _error = null;
      _fromCache = false;
    });
    try {
      final endpoint = ScanAnalysisClient.endpointFor(_url.text);
      final hash = AnalysisStore.requestHash(
        endpoint: endpoint.toString(),
        provider: _provider,
        model: _model.text.trim(),
        key: _key.text.trim(),
        tool: widget.tool,
        exitCode: widget.exitCode,
        output: widget.output,
        language: language,
      );
      if (_useCache && _store != null) {
        final cached = await _store!.lookup(hash);
        if (!mounted || !identical(_client, client)) return;
        if (cached != null) {
          setState(() {
            _answer = cached;
            _fromCache = true;
          });
          return;
        }
      }
      final answer = await client.analyze(
        baseUrl: _url.text,
        model: _model.text,
        apiKey: _key.text,
        tool: widget.tool,
        exitCode: widget.exitCode,
        output: widget.output,
        language: language,
        provider: _provider,
      );
      if (mounted && identical(_client, client)) {
        if (_useCache) await _store?.cache(hash, answer);
        if (!mounted || !identical(_client, client)) return;
        setState(() => _answer = answer);
      }
    } on Object catch (error) {
      if (mounted && identical(_client, client)) {
        setState(
          () => _error = error is ScanAnalysisException
              ? error.message
              : 'Ошибка локального хранилища анализа.',
        );
      }
    } finally {
      client.close();
      if (mounted && identical(_client, client)) {
        setState(() {
          _busy = false;
          _client = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _client?.close();
    _store?.close();
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ExpansionTile(
      title: const TrText('Анализ через API'),
      onExpansionChanged: (expanded) {
        if (expanded && !_loadStarted) _load();
      },
      childrenPadding: const EdgeInsets.all(16),
      children: [
        const TrText(
          'По нажатию весь вывод этой проверки будет отправлен на указанный сервер. '
          'Он может содержать имена файлов, пользователей и адреса. Ключ сохраняется на диск только по отдельному выбору.',
        ),
        const SizedBox(height: 12),
        if (_loading)
          LinearProgressIndicator(
            semanticsLabel: tr(context, 'Открытие баз API'),
          ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _provider,
          key: ValueKey(_provider),
          decoration: localizedDecoration(
            context,
            labelText: 'Совместимость API',
          ),
          items: const [
            DropdownMenuItem(value: 'gptunnel', child: TrText('GPTunnel')),
            DropdownMenuItem(
              value: 'openai',
              child: TrText('OpenAI compatible'),
            ),
          ],
          onChanged: _busy || _loading
              ? null
              : (value) => setState(() => _provider = value!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _url,
          enabled: !_busy && !_loading,
          decoration: localizedDecoration(
            context,
            labelText: 'Base URL или полный endpoint',
            hintText: 'https://server.example/v1',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          enabled: !_busy && !_loading,
          decoration: localizedDecoration(context, labelText: 'Модель'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          enabled: !_busy && !_loading,
          obscureText: !_showKey,
          onChanged: (_) => setState(() {
            _keyLoaded = false;
            _keyError = null;
          }),
          enableSuggestions: false,
          autocorrect: false,
          decoration: localizedDecoration(
            context,
            labelText: _provider == 'gptunnel'
                ? 'API-ключ GPTunnel (обязательно)'
                : 'API-ключ (если требуется)',
            errorText: _keyError,
            helperMaxLines: 3,
            helperText: _key.text.trim().isEmpty
                ? (_storedHasKey
                      ? 'Ключ есть в базе. Нажмите «Загрузить API из базы».'
                      : 'Ключ отсутствует. Введите API-ключ своего аккаунта.')
                : _keyLoaded
                ? 'Ключ загружен из зашифрованной базы.'
                : _storedHasKey
                ? 'Ключ введён; в базе также есть сохранённый ключ.'
                : 'Ключ введён только для текущего сеанса.',
            suffixIcon: IconButton(
              tooltip: tr(context, _showKey ? 'Скрыть ключ' : 'Показать ключ'),
              onPressed: () => setState(() => _showKey = !_showKey),
              icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const TrText('Сохранять API-ключ в api.db'),
          subtitle: const TrText(
            'Для сохранения ключа включите опцию и нажмите «Сохранить API». Без неё сохраняются только URL, модель и провайдер.',
          ),
          value: _saveKey,
          onChanged: _busy || _loading
              ? null
              : (value) => setState(() => _saveKey = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const TrText('Кэшировать анализ на 7 дней'),
          subtitle: const TrText(
            'Отдельная requests.db: до 100 ответов; исходные логи и ключи не сохраняются в кэше.',
          ),
          value: _useCache,
          onChanged: _busy || _loading
              ? null
              : (value) => setState(() => _useCache = value),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_store != null)
              TextButton(
                onPressed: _busy || _loading ? null : _reloadProfile,
                child: const TrText('Загрузить API из базы'),
              ),
            if (_store == null)
              TextButton(
                onPressed: _busy || _loading ? null : _load,
                child: const TrText('Открыть зашифрованные базы'),
              ),
            TextButton(
              onPressed: _busy || _loading ? null : _wipeDatabases,
              child: const TrText('Удалить обе базы…'),
            ),
            TextButton(
              onPressed: _busy || _loading || _store == null ? null : _save,
              child: const TrText('Сохранить API'),
            ),
            TextButton(
              onPressed: _busy || _loading || _store == null
                  ? null
                  : _deleteProfile,
              child: const TrText('Удалить сохранённый API'),
            ),
            TextButton(
              onPressed: _busy || _loading || _store == null
                  ? null
                  : _clearCache,
              child: const TrText('Очистить кэш'),
            ),
            FilledButton.tonal(
              onPressed: _busy || _loading ? null : _analyze,
              child: const TrText('Отправить вывод на анализ'),
            ),
            if (_busy)
              TextButton(
                onPressed: _cancel,
                child: const TrText('Отменить анализ'),
              ),
          ],
        ),
        if (_busy)
          LinearProgressIndicator(
            semanticsLabel: tr(context, 'Анализ выполняется'),
          ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: TrText(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_answer != null) ...[
          const SizedBox(height: 12),
          if (_fromCache)
            const TrText('Ответ из локального кэша; запрос не отправлялся.'),
          const TrText(
            'Ответ модели — предположение, требующее ручной проверки.',
          ),
          ModelMarkdown(data: _answer!),
        ],
      ],
    );
  }
}
