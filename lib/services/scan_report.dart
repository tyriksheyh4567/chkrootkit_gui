class ScanReport {
  const ScanReport({
    required this.tool,
    required this.output,
    required this.exitCode,
    required this.time,
    this.workingDirectory,
    this.executable,
    this.scanRoot = '/',
  });
  final String tool;
  final String output;
  final int exitCode;
  final DateTime time;
  final String? workingDirectory;
  final String? executable;
  final String scanRoot;
}
