import 'widgets/documentation_page.dart';
import 'l10n/app_language.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'services/scan_report.dart';
import 'services/scan_launch.dart';
import 'widgets/working_directory_card.dart';
import 'services/appearance_store.dart';
import 'widgets/log_export_dialog.dart';
import 'widgets/accent_picker.dart';
import 'widgets/findings_view.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main(List<String> args) async {
  runApp(const RootkitGuardApp());
}

enum ThemeChoice { system, light, dark }

enum ScanStatus { idle, running, success, warning, error }

enum ResultView { parsed, raw }

enum InstallTarget { system, user }

class ToolState {
  const ToolState({required this.available, this.version});
  final bool available;
  final String? version;
}

class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.workingDirectory,
    this.executable,
  });
  final int exitCode;
  final String stdout;
  final String stderr;
  final String? workingDirectory;
  final String? executable;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'exitCode': exitCode,
    'stdout': stdout,
    'stderr': stderr,
  };

  factory CommandResult.fromJson(Map<String, dynamic> json) => CommandResult(
    exitCode: json['exitCode'] as int,
    stdout: json['stdout'] as String,
    stderr: json['stderr'] as String,
    workingDirectory: json['workingDirectory'] as String?,
    executable: json['executable'] as String?,
  );
}

/// Parses the stable status markers emitted by the supported command line tools.
///
/// In particular, `not infected` and `not found` are successful chkrootkit
/// checks. A substring search for `INFECTED`/`FOUND` would incorrectly turn
/// both into alerts.
class ParsedScan {
  const ParsedScan({
    required this.lines,
    required this.alerts,
    required this.okLines,
    required this.infoLines,
  });
  final List<String> lines;
  final List<String> alerts;
  final List<String> okLines;
  final List<String> infoLines;

  factory ParsedScan.fromRaw(String raw, {String? tool}) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    final alerts = <String>[];
    final okLines = <String>[];
    final infoLines = <String>[];

    for (final line in lines) {
      final classification = _classifyLine(line, tool);
      switch (classification) {
        case _LineKind.alert:
          alerts.add(line);
        case _LineKind.ok:
          okLines.add(line);
        case _LineKind.info:
          infoLines.add(line);
      }
    }
    return ParsedScan(
      lines: lines,
      alerts: alerts,
      okLines: okLines,
      infoLines: infoLines,
    );
  }

  static _LineKind _classifyLine(String line, String? tool) {
    final value = line.trim();
    final lower = value.toLowerCase();

    if (tool == 'chkrootkit') {
      if (RegExp(r'\bnot\s+(infected|found|detected)\b').hasMatch(lower) ||
          lower.contains('nothing found') ||
          lower.contains('nothing deleted') ||
          lower.contains('no suspect')) {
        return _LineKind.ok;
      }
      if (RegExp(r'\binfected\b').hasMatch(lower) ||
          RegExp(r'\bsuspicious\b').hasMatch(lower) ||
          lower.contains('possible rootkit')) {
        return _LineKind.alert;
      }
      return _LineKind.info;
    }

    if (tool == 'rkhunter' || tool == 'lynis') {
      if (RegExp(
            r'\[\s*(warning|bad|fail(?:ed)?)\s*\]',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(
            r'^\s*(warning|error|failed?)\s*:',
            caseSensitive: false,
          ).hasMatch(value)) {
        return _LineKind.alert;
      }
      if (RegExp(
            r'\[\s*(ok|pass(?:ed)?|clean|not found|none found)\s*\]',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(
            r'\b(not found|none found|not detected|passed|clean)\b',
            caseSensitive: false,
          ).hasMatch(value)) {
        return _LineKind.ok;
      }
      return _LineKind.info;
    }

    if (tool == 'unhide') {
      if (RegExp(r'\b(found|hidden)\b', caseSensitive: false).hasMatch(value) &&
          !RegExp(
            r'\b(0|no)\s+(found|hidden)\b',
            caseSensitive: false,
          ).hasMatch(value)) {
        return _LineKind.alert;
      }
      if (RegExp(
            r'\b(no|0)\s+(hidden|suspicious|found)\b',
            caseSensitive: false,
          ).hasMatch(value) ||
          RegExp(
            r'\b(ok|clean|passed)\b',
            caseSensitive: false,
          ).hasMatch(value)) {
        return _LineKind.ok;
      }
      return _LineKind.info;
    }

    if (RegExp(
      r'^\s*(warning|error|failed?|infected|suspicious)\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return _LineKind.alert;
    }
    if (RegExp(
      r'^\s*(ok|clean|passed?)\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return _LineKind.ok;
    }
    return _LineKind.info;
  }
}

enum _LineKind { alert, ok, info }

class ScanTool {
  const ScanTool({
    required this.name,
    required this.command,
    required this.description,
    required this.icon,
    required this.packageName,
    this.args = const <String>[],
    this.versionArgs = const ['--version'],
  });
  final String name;
  final String command;
  final String description;
  final IconData icon;
  final String packageName;
  final List<String> args;
  final List<String> versionArgs;
}

class OfficialRelease {
  const OfficialRelease({required this.url, required this.archiveName});
  final String url;
  final String archiveName;
}

const officialReleases = <String, OfficialRelease>{
  'chkrootkit': OfficialRelease(
    url: 'https://github.com/DougBurks/chkrootkit/archive/refs/heads/master.tar.gz',
    archiveName: 'chkrootkit',
  ),
  'rkhunter': OfficialRelease(
    url: 'https://downloads.sourceforge.net/rkhunter/rkhunter-1.4.6.tar.gz',
    archiveName: 'rkhunter',
  ),
  'unhide': OfficialRelease(
    url: 'https://github.com/YJesus/Unhide/archive/refs/heads/master.tar.gz',
    archiveName: 'unhide',
  ),
  'lynis': OfficialRelease(
    url: 'https://github.com/CISOfy/lynis/archive/refs/heads/master.tar.gz',
    archiveName: 'lynis',
  ),
};

const scanTools = <ScanTool>[
  ScanTool(
    name: 'chkrootkit',
    command: 'chkrootkit',
    versionArgs: ['-V'],
    description: 'Сигнатуры, троянские бинарники и аномалии /proc',
    icon: Icons.radar,
    packageName: 'chkrootkit',
  ),
  ScanTool(
    name: 'rkhunter',
    command: 'rkhunter',
    args: [
      '--check',
      '--skip-keypress',
      '--report-warnings-only',
      '--nocolors',
    ],
    description:
        'Известные rootkit, изменённые файлы и подозрительные настройки',
    icon: Icons.policy_outlined,
    packageName: 'rkhunter',
  ),
  ScanTool(
    name: 'unhide',
    command: 'unhide',
    versionArgs: ['-V'],
    args: ['-u', '-H', 'quick'],
    description: 'Сверка процессов через /proc, ps и системные вызовы',
    icon: Icons.visibility_outlined,
    packageName: 'unhide',
  ),
  ScanTool(
    name: 'lynis',
    command: 'lynis',
    args: ['audit', 'system', '--quick', '--no-colors'],
    description: 'Аудит конфигурации и признаков компрометации хоста',
    icon: Icons.fact_check_outlined,
    packageName: 'lynis',
  ),
];

const _helperPath =
    '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';

/// Owns the independent headless process started through `pkexec`.
///
/// The Flutter window and this helper communicate over a small JSON protocol;
/// the helper is started lazily on the first privileged operation.
class PrivilegedSession {
  Process? _process;
  Future<void>? _startFuture;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;
  int _generation = 0;
  bool _ready = false;
  bool _disposed = false;
  bool _allowNonRootExecutable = false;
  bool _keepAlive = true;

  bool get isRunning => _process != null && _ready;

  bool get allowNonRootExecutable => _allowNonRootExecutable;

  bool get keepAlive => _keepAlive;

  void setAllowNonRootExecutable(bool value) {
    if (_allowNonRootExecutable == value) return;
    _allowNonRootExecutable = value;
    // The executable path is checked when the independent helper starts. A
    // running helper keeps its existing authorization until it exits.
  }

  void setKeepAlive(bool value) {
    if (_keepAlive == value) return;
    _keepAlive = value;
    if (!value && _process != null) stop();
  }

  Future<void> _start() async {
    if (_disposed) {
      throw const ProcessException('pkexec', [], 'Сеанс закрыт');
    }
    final existing = _startFuture;
    if (existing != null) return existing;
    final generation = ++_generation;
    final future = _startImpl(generation);
    _startFuture = future;
    try {
      await future;
    } on Object catch (error, stack) {
      if (identical(_startFuture, future)) _startFuture = null;
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> _startImpl(int generation) async {
    if (!Platform.isLinux) {
      throw const ProcessException(
        'pkexec',
        [],
        'Привилегированный сеанс поддерживается только в Linux',
      );
    }
    final executable = await _serviceExecutable();
    final executableStat = await FileStat.stat(executable);
    final home = Platform.environment['HOME'];
    final executableInHome =
        home != null && (executable == home || executable.startsWith('$home/'));
    if (executableStat.type != FileSystemEntityType.file ||
        (!_allowNonRootExecutable &&
            ((executableStat.mode & 0x92) != 0 || executableInHome))) {
      throw const ProcessException(
        'pkexec',
        [],
        'Для безопасного запуска установите приложение в системный каталог '
            'с владельцем root',
      );
    }
    final process = await Process.start(
      'pkexec',
      ['--disable-internal-agent', executable],
      environment: <String, String>{
        'PATH': _helperPath,
        'DISPLAY': ?Platform.environment['DISPLAY'],
        'WAYLAND_DISPLAY': ?Platform.environment['WAYLAND_DISPLAY'],
        'XAUTHORITY': ?Platform.environment['XAUTHORITY'],
        'XDG_RUNTIME_DIR': ?Platform.environment['XDG_RUNTIME_DIR'],
      },
    );
    if (_disposed || generation != _generation) {
      process.kill(ProcessSignal.sigterm);
      throw const ProcessException('pkexec', [], 'Запуск сеанса отменён');
    }
    _process = process;
    final ready = Completer<void>();
    process.stderr.transform(utf8.decoder).listen((_) {});
    process.exitCode.then((code) {
      if (!identical(_process, process)) return;
      _ready = false;
      _process = null;
      _startFuture = null;
      if (!ready.isCompleted) {
        ready.completeError(
          ProcessException(
            'pkexec',
            const [],
            code == 126
                ? 'Запрос прав отменён.'
                : code == 127
                ? 'Не удалось запустить сервис или авторизоваться через polkit. В сеансе Wayland/seatd проверьте агент polkit и D-Bus.'
                : 'Привилегированный сервис завершился (код $code).',
          ),
        );
      }
      for (final completer in _pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            const ProcessException(
              'pkexec',
              [],
              'Привилегированный сеанс завершился',
            ),
          );
        }
      }
      _pending.clear();
    });
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            try {
              final message = jsonDecode(line) as Map<String, dynamic>;
              if (message['ready'] == true) {
                _ready = true;
                if (!ready.isCompleted) ready.complete();
                return;
              }
              final id = message['id'];
              if (id is int) {
                _pending.remove(id)?.complete(message);
              }
            } on Object catch (error, stack) {
              if (!ready.isCompleted) ready.completeError(error, stack);
              _fail(error, stack, process);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!ready.isCompleted) ready.completeError(error, stack);
            _fail(error, stack, process);
          },
        );
    try {
      await ready.future.timeout(const Duration(seconds: 30));
    } on Object {
      if (identical(_process, process)) {
        _ready = false;
        _process = null;
        _startFuture = null;
        _generation++;
        process.kill(ProcessSignal.sigterm);
      }
      rethrow;
    }
  }

  Future<CommandResult> runScan(
    String tool, {
    required String executable,
    required String workingDirectory,
    String scanRoot = '/',
  }) async {
    final response = await _request({
      'op': 'scan',
      'tool': tool,
      'executable': executable,
      'workingDirectory': workingDirectory,
      'scanRoot': scanRoot,
    });
    return _resultFromResponse(response);
  }

  Future<CommandResult> install(String manager, String package) async {
    final response = await _request({
      'op': 'install',
      'manager': manager,
      'package': package,
    });
    return _resultFromResponse(response);
  }

  Future<String> _serviceExecutable() async {
    final appExecutable = File(Platform.resolvedExecutable);
    final bundled = File('${appExecutable.parent.path}/rootkit_guard_service');
    if (await bundled.exists()) return bundled.path;

    const systemPath = '/usr/libexec/rootkit_guard_service';
    if (await File(systemPath).exists()) return systemPath;
    throw const ProcessException(
      'rootkit_guard_service',
      [],
      'Headless-сервис не найден рядом с приложением или в /usr/libexec',
    );
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> payload) async {
    await _start();
    final process = _process;
    if (process == null || !_ready) {
      throw const ProcessException(
        'pkexec',
        [],
        'Не удалось запустить привилегированный сеанс',
      );
    }
    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    try {
      process.stdin.writeln(jsonEncode({'id': id, ...payload}));
      await process.stdin.flush();
      final response = await completer.future.timeout(
        const Duration(minutes: 10),
      );
      if (!_keepAlive) stop();
      return response;
    } on TimeoutException {
      _pending.remove(id);
      stop();
      rethrow;
    } on Object catch (error, stack) {
      _pending.remove(id);
      _fail(error, stack, process);
      Error.throwWithStackTrace(error, stack);
    }
  }

  CommandResult _resultFromResponse(Map<String, dynamic> response) {
    if (response['error'] case final error?) {
      throw ProcessException('privileged helper', [], error.toString());
    }
    final result = response['result'];
    if (result is! Map<String, dynamic>) {
      throw const FormatException('invalid helper response');
    }
    return CommandResult.fromJson(result);
  }

  void stop() {
    _generation++;
    final process = _process;
    _ready = false;
    _process = null;
    _startFuture = null;
    process?.kill(ProcessSignal.sigterm);
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ProcessException('pkexec', [], 'Сеанс закрыт'),
        );
      }
    }
    _pending.clear();
  }

  void _fail(Object error, StackTrace stack, Process process) {
    if (!identical(_process, process)) return;
    _generation++;
    _ready = false;
    _process = null;
    _startFuture = null;
    process.kill(ProcessSignal.sigterm);
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
    _pending.clear();
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}

class RootkitGuardApp extends StatefulWidget {
  const RootkitGuardApp({super.key});
  @override
  State<RootkitGuardApp> createState() => _RootkitGuardAppState();
}

class _RootkitGuardAppState extends State<RootkitGuardApp> {
  ThemeChoice _themeChoice = ThemeChoice.system;
  AccentChoice _accentChoice = AccentChoice.system;
  String _language = 'ru';
  int _appearanceRevision = 0;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    final revision = _appearanceRevision;
    try {
      final data = await AppearanceStore.load();
      if (!mounted || revision != _appearanceRevision) return;
      setState(() {
        _language = data['language'] == 'en' ? 'en' : 'ru';
        _themeChoice = ThemeChoice.values.firstWhere(
          (v) => v.name == data['theme'],
          orElse: () => ThemeChoice.system,
        );
        _accentChoice = AccentChoice.values.firstWhere(
          (v) => v.name == data['accent'],
          orElse: () => AccentChoice.system,
        );
      });
    } on Object {
      /* Invalid appearance preferences fall back to the default theme. */
    }
  }

  Future<void> _saveAppearance() async {
    _appearanceRevision++;
    try {
      await AppearanceStore.save(
        _themeChoice.name,
        _accentChoice.name,
        language: _language,
      );
    } on Object {
      _messenger.currentState?.showSnackBar(
        const SnackBar(content: TrText('Не удалось сохранить оформление.')),
      );
    }
  }

  ThemeMode get _themeMode => switch (_themeChoice) {
    ThemeChoice.system => ThemeMode.system,
    ThemeChoice.light => ThemeMode.light,
    ThemeChoice.dark => ThemeMode.dark,
  };

  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
    builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      final light =
          (_accentChoice == AccentChoice.system ? lightDynamic : null) ??
          ColorScheme.fromSeed(seedColor: _accentChoice.seed);
      final dark =
          (_accentChoice == AccentChoice.system ? darkDynamic : null) ??
          ColorScheme.fromSeed(
            seedColor: _accentChoice.seed,
            brightness: Brightness.dark,
          );
      return AppLanguage(
        code: _language,
        child: MaterialApp(
          scaffoldMessengerKey: _messenger,
          locale: Locale(_language),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          debugShowCheckedModeBanner: false,
          title: 'chkrootkit GUI',
          themeMode: _themeMode,
          theme: _theme(light),
          darkTheme: _theme(dark),
          home: RootkitDashboard(
            language: _language,
            onLanguageChanged: (language) {
              setState(() => _language = language);
              _saveAppearance();
            },
            themeChoice: _themeChoice,
            onThemeChanged: (choice) {
              setState(() => _themeChoice = choice);
              _saveAppearance();
            },
            accentChoice: _accentChoice,
            onAccentChanged: (choice) {
              setState(() => _accentChoice = choice);
              _saveAppearance();
            },
          ),
        ),
      );
    },
  );

  ThemeData _theme(ColorScheme scheme) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

class RootkitDashboard extends StatefulWidget {
  const RootkitDashboard({
    this.language = 'ru',
    this.onLanguageChanged,
    required this.themeChoice,
    required this.onThemeChanged,
    required this.accentChoice,
    required this.onAccentChanged,
    super.key,
  });
  final String language;
  final ValueChanged<String>? onLanguageChanged;
  final ThemeChoice themeChoice;
  final ValueChanged<ThemeChoice> onThemeChanged;
  final AccentChoice accentChoice;
  final ValueChanged<AccentChoice> onAccentChanged;
  @override
  State<RootkitDashboard> createState() => _RootkitDashboardState();
}

class _RootkitDashboardState extends State<RootkitDashboard> {
  ScanStatus _status = ScanStatus.idle;
  String _output = 'Выберите инструмент и запустите проверку.';
  String _selectedTool = scanTools.first.name;
  DateTime? _lastScan;
  ScanReport? _report;
  Process? _process;
  int _section = 0;
  int _scanId = 0;
  ResultView _resultView = ResultView.parsed;
  InstallTarget _installTarget = InstallTarget.system;
  bool _usePkexec = true;
  bool _allowNonRootExecutable = false;
  bool _keepPrivilegedService = true;
  bool _pkexecAvailable = false;
  String? _packageManager;
  bool _checkingTools = true;
  bool _installing = false;
  bool _startupDialogShown = false;
  Map<String, ToolState> _toolStates = const {};
  final PrivilegedSession _privilegedSession = PrivilegedSession();
  final _scanRoot = TextEditingController(text: '/');
  final _workingDirectories = {
    for (final tool in scanTools) tool.name: TextEditingController(),
  };
  ScanTool get _tool =>
      scanTools.firstWhere((tool) => tool.name == _selectedTool);

  ParsedScan get _parsed =>
      ParsedScan.fromRaw(_output, tool: _report?.tool ?? _tool.command);

  void _setAllowNonRootExecutable(bool value) {
    setState(() => _allowNonRootExecutable = value);
    _privilegedSession.setAllowNonRootExecutable(value);
  }

  void _setKeepPrivilegedService(bool value) {
    setState(() => _keepPrivilegedService = value);
    _privilegedSession.setKeepAlive(value);
  }

  @override
  void initState() {
    super.initState();
    _refreshToolAvailability();
  }

  Future<void> _refreshToolAvailability() async {
    final states = <String, ToolState>{};
    for (final tool in scanTools) {
      final path = await _commandPath(tool.command);
      String? version;
      if (path != null) {
        try {
          final result = await Process.run(path, tool.versionArgs);
          if (result.exitCode == 0) {
            final text = '${result.stdout}\n${result.stderr}'.trim();
            version = text
                .split('\n')
                .firstWhere(
                  (line) => line.trim().isNotEmpty,
                  orElse: () => path,
                );
          }
        } on ProcessException {
          /* Root-only scanners may deny unprivileged version probes. */
        }
      }
      states[tool.name] = ToolState(available: path != null, version: version);
    }
    final pkexec = await _commandPath('pkexec');
    final managers = ['apt-get', 'dnf', 'pacman', 'zypper'];
    String? manager;
    for (final candidate in managers) {
      if (await _commandPath(candidate) != null) {
        manager = candidate;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _toolStates = states;
      _pkexecAvailable = pkexec != null;
      _packageManager = manager;
      _checkingTools = false;
    });
    _showMissingToolsDialog();
  }

  void _showMissingToolsDialog() {
    if (!mounted || _startupDialogShown) return;
    final missing = scanTools
        .where((tool) => !(_toolStates[tool.name]?.available ?? false))
        .map((tool) => tool.name)
        .toList();
    if (missing.isEmpty && _pkexecAvailable) return;
    _startupDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const TrText('Нужны системные утилиты'),
          content: TrText(
            '${missing.isEmpty ? '' : 'Не найдены: ${missing.join(', ')}.\n'}'
            '${_pkexecAvailable ? '' : 'pkexec не найден — без него проверки могут не получить права root.\n'}'
            'Откройте вкладку «Инструменты», чтобы установить пакеты. Для ClamAV в РФ используйте зеркало Yandex или зеркало вашего дистрибутива.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TrText('Позже'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _section = 2);
              },
              child: const TrText('Открыть инструменты'),
            ),
          ],
        ),
      );
    });
  }

  Future<String?> _commandPath(String command) async {
    final home = Platform.environment['HOME'];
    for (final candidate in [
      if (home != null) '$home/.local/bin/$command',
      '/usr/local/bin/$command',
    ]) {
      if (await File(candidate).exists()) return candidate;
    }
    final result = await Process.run('sh', [
      '-c',
      'command -v -- "\$1"',
      'rootkit-guard',
      command,
    ]);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  @override
  void dispose() {
    _scanId++;
    _process?.kill();
    _scanRoot.dispose();
    _privilegedSession.dispose();
    for (final controller in _workingDirectories.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _exportLog() async {
    final report = _report;
    if (report == null) return;
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final stamp = report.time.toUtc().toIso8601String().replaceAll(':', '-');
    try {
      final path = await showDialog<String>(
        context: context,
        builder: (_) =>
            LogExportDialog(initialPath: '$home/${report.tool}-$stamp.log'),
      );
      if (path == null || path.isEmpty) return;
      final file = File(path.endsWith('.log') ? path : '$path.log');
      // Exclusive creation protects existing logs from accidental overwrites.
      await file.create(exclusive: true);
      await file.writeAsString(report.output, flush: true);
      _showSnack('Лог сохранён: ${file.path}');
    } on FileSystemException {
      _showSnack(
        'Не удалось сохранить лог. Проверьте каталог, права и отсутствие файла с таким именем.',
      );
    }
  }

  Future<void> _runScan() async {
    if (_status == ScanStatus.running) return;
    final scanId = ++_scanId;
    final scannedTool = _tool;
    setState(() {
      _status = ScanStatus.running;
      _output =
          'Запуск ${_tool.command}${_usePkexec ? ' через pkexec' : ''}…\nПроверка может потребовать права root.';
    });
    try {
      final toolPath = await _commandPath(_tool.command);
      if (toolPath == null) {
        if (mounted) {
          setState(() {
            _status = ScanStatus.error;
            _output =
                '${_tool.command} не найден. Установите его на вкладке «Инструменты».';
          });
        }
        return;
      }
      if (!mounted || scanId != _scanId) return;
      if (_usePkexec && !_pkexecAvailable) {
        if (mounted) {
          setState(() {
            _status = ScanStatus.error;
            _output = 'pkexec не найден. Установите polkit/pkexec и запустите агент аутентификации.';
          });
        }
        return;
      }
      final launch = await ScanLaunch.prepare(
        toolPath,
        _workingDirectories[scannedTool.name]!.text,
        home: Platform.environment['HOME'],
      );
      final scanRoot = ScanLaunch.scanRootFor(
        scannedTool.name,
        scannedTool.name == 'chkrootkit' ? _scanRoot.text : '/',
        home: Platform.environment['HOME'],
      );
      if (!mounted || scanId != _scanId) return;
      if (_usePkexec) {
        final result = await _privilegedSession.runScan(
          scannedTool.name,
          executable: toolPath,
          workingDirectory: launch.workingDirectory,
          scanRoot: scanRoot,
        );
        if (!mounted || scanId != _scanId) return;
        setState(() {
          _lastScan = DateTime.now();
          _report = ScanReport(
            tool: scannedTool.command,
            workingDirectory:
                result.workingDirectory ?? launch.workingDirectory,
            executable: result.executable ?? launch.executable,
            scanRoot: scanRoot,
            output: '${result.stdout}\n${result.stderr}',
            exitCode: result.exitCode,
            time: _lastScan!,
          );
          final text = '${result.stdout}\n${result.stderr}'.trim();
          _output = text.isEmpty
              ? 'Инструмент завершился без вывода (код ${result.exitCode}).'
              : text;
          _status = result.exitCode == 0
              ? ScanStatus.success
              : ScanStatus.warning;
        });
        return;
      }
      final process = await Process.start(launch.executable, [
        ...scannedTool.args,
        if (scannedTool.name == 'chkrootkit' && scanRoot != '/') ...[
          '-r',
          scanRoot,
        ],
      ], workingDirectory: launch.workingDirectory);
      _process = process;
      final buffer = StringBuffer();
      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .forEach(buffer.write);
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .forEach((line) => buffer.writeln(line));
      final exitCode = await Future.wait<int>([
        process.exitCode,
        stdoutDone.then((_) => 0),
        stderrDone.then((_) => 0),
      ]).then((values) => values.first).timeout(const Duration(minutes: 10));
      if (!mounted || scanId != _scanId) return;
      setState(() {
        _process = null;
        _lastScan = DateTime.now();
        _report = ScanReport(
          tool: scannedTool.command,
          workingDirectory: launch.workingDirectory,
          executable: launch.executable,
          scanRoot: scanRoot,
          output: buffer.toString(),
          exitCode: exitCode,
          time: _lastScan!,
        );
        final text = buffer.toString().trim();
        _output = text.isEmpty
            ? 'Инструмент завершился без вывода (код $exitCode).'
            : text;
        _status = exitCode == 0 ? ScanStatus.success : ScanStatus.warning;
      });
    } on ProcessException catch (error) {
      if (!mounted || scanId != _scanId) return;
      setState(() {
        _process = null;
        _status = ScanStatus.error;
        _output =
            'Не удалось запустить ${_tool.command}.\nУстановите пакет и повторите.\n$error';
      });
    } on TimeoutException {
      _process?.kill();
      if (_usePkexec) _privilegedSession.stop();
      if (!mounted || scanId != _scanId) return;
      setState(() {
        _process = null;
        _status = ScanStatus.error;
        _output = 'Проверка превысила лимит 10 минут и была остановлена.';
      });
    } on Object catch (error) {
      if (!mounted || scanId != _scanId) return;
      setState(() {
        _process = null;
        _status = ScanStatus.error;
        _output = 'Не удалось завершить проверку ${_tool.command}.\n$error';
      });
    }
  }

  void _cancelScan() {
    if (_usePkexec) {
      _privilegedSession.stop();
    } else {
      _process?.kill(ProcessSignal.sigterm);
    }
    _scanId++;
    setState(() {
      _process = null;
      _status = ScanStatus.idle;
      _output = 'Проверка остановлена пользователем.';
    });
  }

  Future<void> _installTool(ScanTool tool) async {
    if (_installing) return;
    setState(() => _installing = true);
    try {
      if (_installTarget == InstallTarget.user) {
        final availableInRepo = await _packageAvailable(tool.packageName);
        if (availableInRepo) {
          _showSnack(
            'Пакет ${tool.packageName} есть в репозитории. Выберите системную установку, чтобы получить обновления.',
          );
          return;
        }
        final release = officialReleases[tool.command];
        if (release == null) {
          _showSnack('Официальный релиз для ${tool.command} не настроен.');
          return;
        }
        final home = Platform.environment['HOME'];
        if (home == null) {
          throw const ProcessException('HOME', [], 'Переменная HOME не задана');
        }
        final directory = Directory('$home/.local/bin');
        await directory.create(recursive: true);
        await _installOfficialRelease(tool, release, directory.path);
        _showSnack(
          '${tool.command} установлен из официального релиза в ~/.local/bin.',
        );
      } else {
        if (_packageManager == null) {
          _showSnack('Поддерживаемый пакетный менеджер не найден.');
          return;
        }
        if (!_pkexecAvailable) {
          _showSnack('Для системной установки нужен pkexec/polkit.');
          return;
        }
        final manager = _packageManager!;
        final result = await _privilegedSession.install(
          manager,
          tool.packageName,
        );
        final output = '${result.stdout}\n${result.stderr}'.trim();
        if (result.exitCode != 0) {
          throw ProcessException(
            'pkexec',
            [manager, tool.packageName],
            output,
            result.exitCode,
          );
        }
        _showSnack('${tool.command} установлен через $manager.');
        await _refreshToolAvailability();
      }
    } on Object catch (error) {
      _showSnack('Установка не выполнена: $error');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<bool> _packageAvailable(String package) async {
    final manager = _packageManager;
    if (manager == null) return false;
    final checks = switch (manager) {
      'apt-get' => [
        'apt-cache',
        ['show', package],
      ],
      'dnf' => [
        'dnf',
        ['repoquery', '--qf', '%{name}', package],
      ],
      'pacman' => [
        'pacman',
        ['-Si', package],
      ],
      'zypper' => [
        'zypper',
        ['--non-interactive', 'info', package],
      ],
      _ => [
        manager,
        ['info', package],
      ],
    };
    final result = await Process.run(
      checks.first as String,
      checks.last as List<String>,
    );
    if (result.exitCode == 0) return true;
    if (manager == 'pacman') {
      for (final aur in ['yay', 'paru']) {
        if (await _commandPath(aur) == null) continue;
        final aurResult = await Process.run(aur, ['-Si', package]);
        if (aurResult.exitCode == 0) return true;
      }
    }
    return false;
  }

  Future<void> _installOfficialRelease(
    ScanTool tool,
    OfficialRelease release,
    String destination,
  ) async {
    final script = '''set -eu
tmp="\$(mktemp -d)"
trap 'rm -rf "\$tmp"' EXIT
curl --fail --location --silent --show-error "\$1" -o "\$tmp/release.tar.gz"
mkdir "\$tmp/src"
tar -xzf "\$tmp/release.tar.gz" -C "\$tmp/src"
candidate="\$(find "\$tmp/src" -type f -name "\$3" | head -n 1)"
test -n "\$candidate"
install -Dm755 "\$candidate" "\$2/\$3"
''';
    final result = await Process.run('sh', [
      '-c',
      script,
      'rootkit-guard',
      release.url,
      destination,
      tool.command,
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'official release',
        [],
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: TrText(message)));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 12),
            Expanded(
              child: TrText('chkrootkit GUI', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Language / Язык',
            icon: const Icon(Icons.language),
            initialValue: widget.language,
            onSelected: widget.onLanguageChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'ru', child: TrText('Русский')),
              PopupMenuItem(value: 'en', child: TrText('English')),
            ],
          ),
          AccentPicker(
            choice: widget.accentChoice,
            onChanged: widget.onAccentChanged,
          ),
          PopupMenuButton<ThemeChoice>(
            tooltip: tr(context, 'Тема'),
            icon: const Icon(Icons.brightness_6_outlined),
            initialValue: widget.themeChoice,
            onSelected: widget.onThemeChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ThemeChoice.system,
                child: TrText('Системная тема'),
              ),
              PopupMenuItem(
                value: ThemeChoice.light,
                child: TrText('Светлая тема'),
              ),
              PopupMenuItem(
                value: ThemeChoice.dark,
                child: TrText('Тёмная тема'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _section,
          children: [
            _buildScanPage(wide),
            _buildRootkitPage(),
            _buildToolsPage(),
            const DocumentationPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (index) => setState(() => _section = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.radar),
            label: tr(context, 'Проверка'),
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            label: tr(context, 'Находки'),
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            label: tr(context, 'Инструменты'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            label: tr(context, 'Справка'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanPage(bool wide) {
    final controls = Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              'Проверка хоста',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            TrText(
              'Запускайте установленные CLI-инструменты из одного окна.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _selectedTool,
              decoration: localizedDecoration(context, labelText: 'Инструмент'),
              items: scanTools
                  .map(
                    (tool) => DropdownMenuItem(
                      value: tool.name,
                      child: TrText(tool.name),
                    ),
                  )
                  .toList(),
              onChanged: _status == ScanStatus.running
                  ? null
                  : (value) => setState(() {
                      _selectedTool = value!;
                      if (value != 'lynis') _usePkexec = true;
                    }),
            ),
            const SizedBox(height: 12),
            TrText(_tool.description),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'Каталог сканирования',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_tool.name == 'chkrootkit')
                      TextField(
                        controller: _scanRoot,
                        enabled: _status != ScanStatus.running,
                        decoration: localizedDecoration(
                          context,
                          labelText: 'Корень проверяемой системы',
                          hintText: '/ или /mnt/system',
                          helperMaxLines: 4,
                          helperText: 'По умолчанию /. Для смонтированной системы будет передан chkrootkit -r <путь>. Проверки процессов относятся к работающему ядру.',
                        ),
                      )
                    else
                      TrText(
                        'Этот инструмент проверяет работающую систему. Выбор другого каталога для него не поддерживается.',
                      ),
                  ],
                ),
              ),
            ),
            ExpansionTile(
              title: const TrText('Дополнительные параметры запуска'),
              children: [
                WorkingDirectoryCard(
                  key: ValueKey(_tool.name),
                  controller: _workingDirectories[_tool.name]!,
                  tool: _tool.command,
                  arguments: _tool.args,
                  enabled: _status != ScanStatus.running,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  (_toolStates[_tool.name]?.available ?? false)
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: (_toolStates[_tool.name]?.available ?? false)
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TrText(
                    _checkingTools
                        ? 'Проверяю наличие бинарника…'
                        : (_toolStates[_tool.name]?.available ?? false)
                        ? 'Найден: ${_toolStates[_tool.name]?.version ?? _tool.command}'
                        : 'Не найден в PATH',
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const TrText('Права root через pkexec'),
              subtitle: TrText(
                _pkexecAvailable
                    ? (_tool.name == 'lynis'
                          ? 'Для полного аудита нужен root; без него аудит ограничен.'
                          : 'Требуется для запуска сканера, в том числе из ~/.local/bin.')
                    : 'pkexec не найден',
              ),
              value: _usePkexec,
              onChanged:
                  _tool.name == 'lynis' &&
                      _pkexecAvailable &&
                      _status != ScanStatus.running
                  ? (value) => setState(() => _usePkexec = value)
                  : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const TrText('Разрешить запуск без владельца root'),
              subtitle: TrText(
                _allowNonRootExecutable
                    ? 'Опасно: headless-сервис сможет стартовать из пользовательского каталога'
                    : 'Headless-сервис принимает только системный бинарник; настройка действует при его запуске',
              ),
              value: _allowNonRootExecutable,
              onChanged:
                  _pkexecAvailable &&
                      _status != ScanStatus.running &&
                      !_installing
                  ? _setAllowNonRootExecutable
                  : null,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const TrText('Оставлять headless-сервис запущенным'),
              subtitle: const TrText(
                'Выключите, чтобы завершать отдельный сервис после каждой операции',
              ),
              value: _keepPrivilegedService,
              onChanged:
                  _pkexecAvailable &&
                      _status != ScanStatus.running &&
                      !_installing
                  ? _setKeepPrivilegedService
                  : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _status == ScanStatus.running
                  ? FilledButton.tonalIcon(
                      onPressed: _cancelScan,
                      icon: const Icon(Icons.stop),
                      label: const TrText('Остановить'),
                    )
                  : FilledButton.icon(
                      onPressed: _runScan,
                      icon: const Icon(Icons.play_arrow),
                      label: const TrText('Запустить проверку'),
                    ),
            ),
          ],
        ),
      ),
    );
    final result = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(status: _status),
                const SizedBox(width: 12),
                Expanded(
                  child: TrText(
                    _statusLabel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_lastScan != null) TrText(_formatTime(_lastScan!)),
              ],
            ),
            if (_status == ScanStatus.running)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 16),
            SegmentedButton<ResultView>(
              segments: const [
                ButtonSegment(
                  value: ResultView.parsed,
                  label: TrText('Разбор'),
                  icon: Icon(Icons.summarize_outlined),
                ),
                ButtonSegment(
                  value: ResultView.raw,
                  label: TrText('Вывод'),
                  icon: Icon(Icons.subject_outlined),
                ),
              ],
              selected: {_resultView},
              onSelectionChanged: (selection) =>
                  setState(() => _resultView = selection.first),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _report == null ? null : _exportLog,
                icon: const Icon(Icons.save_alt),
                label: const TrText('Экспорт .log'),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 250),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _resultView == ResultView.raw
                  ? SelectableText(
                      _status == ScanStatus.success ||
                              _status == ScanStatus.warning
                          ? _output
                          : tr(context, _output),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    )
                  : _buildParsedResult(),
            ),
            const SizedBox(height: 12),
            TrText(
              'Результат сканера требует проверки администратором. Сигнатурные утилиты не гарантируют отсутствие неизвестного rootkit.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: controls),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: result),
                ],
              )
            : Column(children: [controls, const SizedBox(height: 20), result]),
      ),
    );
  }

  Widget _buildParsedResult() {
    if (_status == ScanStatus.idle ||
        _status == ScanStatus.running ||
        _status == ScanStatus.error) {
      return SelectableText(
        tr(context, _output),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrText(
          'Строк: ${_parsed.lines.length}  •  предупреждений: ${_parsed.alerts.length}  •  OK: ${_parsed.okLines.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (_parsed.alerts.isEmpty)
          TrText(
            'Явных предупреждений по простому разбору не найдено.',
            style: TextStyle(color: scheme.primary),
          ),
        ..._parsed.alerts
            .take(30)
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('⚠ $line', style: TextStyle(color: scheme.error)),
              ),
            ),
        if (_parsed.alerts.length > 30)
          TrText(
            'Показаны первые 30 предупреждений. Откройте «Вывод» для полного вывода.',
          ),
      ],
    );
  }

  String get _statusLabel => switch (_status) {
    ScanStatus.idle => 'Готово к проверке',
    ScanStatus.running => 'Проверка выполняется',
    ScanStatus.success => 'Проверка завершена',
    ScanStatus.warning => 'Есть предупреждения',
    ScanStatus.error => 'Ошибка запуска',
  };

  Widget _buildRootkitPage() => FindingsView(
    report: _report,
    alerts: _report == null
        ? const []
        : ParsedScan.fromRaw(_report!.output, tool: _report!.tool).alerts,
    onExport: _exportLog,
  );

  Widget _buildToolsPage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      TrText(
        'Рекомендуемый стек',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      _InfoTile(
        icon: Icons.desktop_windows_outlined,
        title: 'Wayland / seatd',
        text:
            '${Platform.environment['WAYLAND_DISPLAY'] != null
                ? 'Wayland'
                : Platform.environment['DISPLAY'] != null
                ? 'X11'
                : 'Графический сеанс не определён'}; '
            'D-Bus: ${Platform.environment['DBUS_SESSION_BUS_ADDRESS'] != null ? 'адрес задан' : 'адрес не задан'}. '
            'Интерфейс GTK работает в сеансе композитора, в том числе с seatd. Запросы прав root обрабатывает агент polkit.',
      ),
      const _InfoTile(
        icon: Icons.radar,
        title: 'chkrootkit + rkhunter',
        text: 'Комплементарные локальные проверки сигнатур, бинарников, модулей и файловых признаков.',
      ),
      const _InfoTile(
        icon: Icons.visibility_outlined,
        title: 'unhide',
        text: 'Сравнение представлений процессов помогает заметить сокрытие. Проверка портов требует отдельной утилиты unhide-tcp.',
      ),
      const _InfoTile(
        icon: Icons.security,
        title: 'Wazuh Rootcheck',
        text: 'Для постоянного мониторинга: скрытые процессы, файлы, порты и системные вызовы.',
      ),
      const _InfoTile(
        icon: Icons.timeline,
        title: 'Falco / Tetragon',
        text: 'Поведенческие правила на eBPF для загрузки модулей, неожиданных exec и сетевых действий.',
      ),
      const _InfoTile(
        icon: Icons.fact_check_outlined,
        title: 'Lynis',
        text: 'Аудит защиты и конфигурации системы помогает оценить обнаруженные предупреждения.',
      ),
      const _InfoTile(
        icon: Icons.coronavirus_outlined,
        title: 'ClamAV для РФ',
        text: 'Для обновления баз используйте зеркало Yandex (clamav-mirror.yandex.ru) или зеркало вашего дистрибутива; задайте его в freshclam.conf и проверьте доступность HTTPS.',
      ),
      const SizedBox(height: 12),
      TrText(
        'Установка отсутствующих инструментов',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      SegmentedButton<InstallTarget>(
        segments: const [
          ButtonSegment(
            value: InstallTarget.system,
            label: TrText('Репозиторий'),
            icon: Icon(Icons.inventory_2_outlined),
          ),
          ButtonSegment(
            value: InstallTarget.user,
            label: TrText('~/.local/bin'),
            icon: Icon(Icons.person_outline),
          ),
        ],
        selected: {_installTarget},
        onSelectionChanged: _installing
            ? null
            : (value) => setState(() => _installTarget = value.first),
      ),
      const SizedBox(height: 8),
      ...scanTools.map(
        (tool) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              (_toolStates[tool.name]?.available ?? false)
                  ? Icons.check_circle_outline
                  : Icons.download_outlined,
            ),
            title: TrText(tool.name),
            subtitle: TrText(
              (_toolStates[tool.name]?.available ?? false)
                  ? 'Найден в PATH'
                  : 'Не найден',
            ),
            trailing: FilledButton.tonal(
              onPressed:
                  _installing || (_toolStates[tool.name]?.available ?? false)
                  ? null
                  : () => _installTool(tool),
              child: const TrText('Установить'),
            ),
          ),
        ),
      ),
    ],
  );

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final ScanStatus status;
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      ScanStatus.success => (Icons.check_circle, Colors.green),
      ScanStatus.warning => (Icons.warning_amber, Colors.orange),
      ScanStatus.error => (Icons.error, Theme.of(context).colorScheme.error),
      ScanStatus.running => (Icons.sync, Theme.of(context).colorScheme.primary),
      ScanStatus.idle => (
        Icons.shield_outlined,
        Theme.of(context).colorScheme.primary,
      ),
    };
    return Icon(icon, color: color, size: 30);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(icon),
      title: TrText(title),
      subtitle: TrText(text),
    ),
  );
}
