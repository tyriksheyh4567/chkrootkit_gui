import 'dart:convert';
import 'dart:io';

class AppearanceStore {
  static File get _file {
    final env = Platform.environment;
    final base =
        env['XDG_CONFIG_HOME'] ??
        '${env['HOME'] ?? Directory.current.path}/.config';
    return File('$base/chkrootkit_gui/appearance.json');
  }

  static Future<Map<String, dynamic>> load() async {
    if (!await _file.exists()) return {};
    return jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
  }

  static Future<void> _writes = Future.value();
  static Future<void> save(
    String theme,
    String accent, {
    String language = 'ru',
  }) {
    final next = _writes.catchError((Object _) {}).then((_) async {
      final file = _file;
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({'theme': theme, 'accent': accent, 'language': language}),
        flush: true,
      );
      await temporary.rename(file.path);
    });
    _writes = next;
    return next;
  }
}
