import 'dart:io';

class ScanLaunch {
  const ScanLaunch({required this.executable, required this.workingDirectory});
  final String executable;
  final String workingDirectory;

  static String scanRootFor(String tool, String input, {String? home}) {
    var root = input.trim();
    if (root.isEmpty) root = '/';
    if (root == '~' || root.startsWith('~/')) {
      if (home == null) {
        throw const FormatException(
          'Укажите абсолютный путь каталога сканирования.',
        );
      }
      root = '$home${root.substring(1)}';
    }
    if (!root.startsWith('/') || root.contains('\u0000')) {
      throw const FormatException(
        'Укажите абсолютный путь каталога сканирования.',
      );
    }
    if (tool != 'chkrootkit' && root != '/') {
      throw const FormatException(
        'Этот сканер поддерживает только работающую систему.',
      );
    }
    return root;
  }

  static Future<ScanLaunch> prepare(
    String toolPath,
    String directory, {
    String? home,
  }) async {
    final executable = await File(toolPath).resolveSymbolicLinks();
    var cwd = directory.trim();
    if (cwd == '~' || cwd.startsWith('~/')) {
      if (home == null) {
        throw const FormatException(
          'Не удалось определить домашний каталог. Укажите полный путь.',
        );
      }
      cwd = '$home${cwd.substring(1)}';
    }
    if (cwd.isEmpty) cwd = File(executable).parent.path;
    if (!cwd.startsWith('/') || cwd.contains('\u0000')) {
      throw const FormatException(
        'Рабочий каталог должен быть абсолютным путём или начинаться с ~/',
      );
    }
    return ScanLaunch(executable: executable, workingDirectory: cwd);
  }
}
