import 'dart:io';

void main() {
  final repoRoot = Directory.current;
  final libDir = Directory('${repoRoot.path}${Platform.pathSeparator}lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Guardrail check: lib/ folder not found.');
    exit(2);
  }

  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final relativePath = _toRelativePath(repoRoot.path, entity.path);
    final source = entity.readAsStringSync();

    _checkFirebaseSingletonUsage(relativePath, source, violations);
    _checkRepositoryUsageInViews(relativePath, source, violations);
  }

  if (violations.isEmpty) {
    stdout.writeln('Architecture guardrails passed.');
    return;
  }

  stderr.writeln('Architecture guardrails failed:');
  for (final violation in violations) {
    stderr.writeln(' - $violation');
  }
  exit(1);
}

void _checkFirebaseSingletonUsage(
  String path,
  String source,
  List<String> violations,
) {
  final isAllowedPath =
      path.startsWith('lib/core/services/') ||
      path.startsWith('lib/core/firebase/') ||
      path.startsWith('lib/firebase_options.dart');
  if (isAllowedPath) return;

  final forbidden = [
    'FirebaseAuth.instance',
    'FirebaseFirestore.instance',
    'FirebaseFunctions.instance',
    'FirebaseFunctions.instanceFor(',
  ];

  for (final token in forbidden) {
    if (source.contains(token)) {
      violations.add('$path uses forbidden singleton: $token');
    }
  }
}

void _checkRepositoryUsageInViews(
  String path,
  String source,
  List<String> violations,
) {
  final isViewFile = path.contains('/view/') || path.contains('/views/');
  if (!isViewFile) return;

  final forbiddenMutationPattern = RegExp(
    r'(?:context|this\.context)\.read<[^>]*Repository[^>]*>\(\)\.(?:create|join|rename|delete|update|send|accept|decline)\w*\(',
  );
  final mutationMatches = forbiddenMutationPattern.allMatches(source);

  for (final match in mutationMatches) {
    final token =
        match.group(0) ?? 'context.read<...Repository>().<mutation>()';
    violations.add('$path directly mutates repository in view: $token');
  }
}

String _toRelativePath(String rootPath, String fullPath) {
  var relative = fullPath.replaceFirst(rootPath, '');
  if (relative.startsWith(Platform.pathSeparator)) {
    relative = relative.substring(1);
  }
  return relative.replaceAll('\\', '/');
}
