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
    _checkRepositoryLayerBoundaries(relativePath, source, violations);
    _checkRepositoryUsageInViews(relativePath, source, violations);
    _checkScreenLayerBoundaries(relativePath, source, violations);
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

void _checkRepositoryLayerBoundaries(
  String path,
  String source,
  List<String> violations,
) {
  final isRepositoryFile = path.startsWith('lib/domain/repositories/');
  if (!isRepositoryFile) return;

  final forbiddenImportPatterns = <RegExp>[
    RegExp(r"import\s+'package:cloud_functions/cloud_functions\.dart'"),
    RegExp(
      r"import\s+'package:inklink/core/services/cloud_functions_service\.dart'",
    ),
    RegExp(
      r"import\s+'\.\./\.\./\.\./core/services/cloud_functions_service\.dart'",
    ),
    RegExp(r"import\s+'package:inklink/domain/services/"),
    RegExp(r"import\s+'\.\./\.\./services/"),
  ];

  for (final importPattern in forbiddenImportPatterns) {
    if (importPattern.hasMatch(source)) {
      violations.add(
        '$path crosses repository boundary with forbidden import. Repositories must stay data-access only.',
      );
      break;
    }
  }

  final forbiddenCallPatterns = <RegExp>[RegExp(r'\.httpsCallable\s*\(')];

  for (final callPattern in forbiddenCallPatterns) {
    if (callPattern.hasMatch(source)) {
      violations.add(
        '$path calls Cloud Functions directly. Move function orchestration to domain services.',
      );
      break;
    }
  }
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

void _checkScreenLayerBoundaries(
  String path,
  String source,
  List<String> violations,
) {
  final isScreenFile =
      path.startsWith('lib/features/') && path.endsWith('_screen.dart');
  if (!isScreenFile) return;

  final forbiddenContextDependencyPattern = RegExp(
    r'(?:context|this\.context)\.(?:read|watch|select)<[^>]*(?:Repository|Service)[^>]*>',
  );

  final dependencyMatches = forbiddenContextDependencyPattern.allMatches(
    source,
  );
  for (final match in dependencyMatches) {
    final token =
        match.group(0) ?? 'context.read/watch/select<...Repository|Service>';
    violations.add('$path accesses data dependency directly in screen: $token');
  }

  final forbiddenImportPatterns = <RegExp>[
    RegExp(r"import\s+'package:inklink/core/services/"),
    RegExp(r"import\s+'package:inklink/domain/repositories/"),
    RegExp(r"import\s+'\.\./\.\./\.\./core/services/"),
    RegExp(r"import\s+'\.\./\.\./\.\./domain/repositories/"),
  ];

  for (final importPattern in forbiddenImportPatterns) {
    if (importPattern.hasMatch(source)) {
      violations.add(
        '$path imports service/repository directly. Move composition to route/wrapper and keep screen UI-only.',
      );
      break;
    }
  }
}

String _toRelativePath(String rootPath, String fullPath) {
  var relative = fullPath.replaceFirst(rootPath, '');
  if (relative.startsWith(Platform.pathSeparator)) {
    relative = relative.substring(1);
  }
  return relative.replaceAll('\\', '/');
}
