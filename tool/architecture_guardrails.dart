import 'dart:io';

/// InkLink Architecture Guardrails
///
/// Enforces the mandatory 5-layer dependency flow across both mobile and web:
///
///   UI (Screens / Widgets)
///     -> BLoC / Cubit
///       -> Domain Services
///         -> Repository Abstractions -> Repository Implementations
///           -> Backend / Database
///
/// Run locally or in CI with:
///   dart run tool/architecture_guardrails.dart
void main() {
  final repoRoot = Directory.current;
  final libDir = Directory('${repoRoot.path}${Platform.pathSeparator}lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Guardrail check: lib/ folder not found.');
    exit(2);
  }

  final files = <String, _ParsedFile>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;

    final relativePath = _toRelativePath(repoRoot.path, entity.path);
    final rawSource = entity.readAsStringSync();
    final strippedSource = _stripComments(rawSource);
    final directives = _parseDirectives(strippedSource, relativePath);
    files[relativePath] = _ParsedFile(
      path: relativePath,
      strippedSource: strippedSource,
      directives: directives,
    );
  }

  final violations = <String>[];

  for (final file in files.values) {
    _checkFirebaseSingletonUsage(file, violations);
    _checkDomainModelPurity(file, violations);
    _checkDomainToPresentationIsolation(file, violations);
    _checkServiceDataAccessBoundaries(file, violations);
    _checkBlocLayerBoundaries(file, violations);
    _checkRepositoryLayerBoundaries(file, violations);
    _checkRepositoryUsageInViews(file, violations);
    _checkScreenLayerBoundaries(file, violations);
    _checkWebScreenBoundaries(file, violations);
    _checkRouteLayerBoundaries(file, violations);
    _checkCrossFeatureImports(file, violations);
    _checkScreenDirectBlocCalls(file, violations);
    _checkPlatformIsolationDirectImports(file, violations);
    _checkNoDummyCodeInProductionWeb(file, violations);
  }

  _checkWebTransitivePlatformIsolation(files, violations);
  _checkCircularDependencies(files, violations);

  if (violations.isEmpty) {
    stdout.writeln(
      'Architecture guardrails passed (${files.length} Dart files checked).',
    );
    return;
  }

  stderr.writeln(
    'Architecture guardrails failed (${violations.length} violation(s)):',
  );
  for (final violation in violations) {
    stderr.writeln(' - $violation');
  }
  exit(1);
}

// ---------------------------------------------------------------------------
// Documented architectural exceptions (narrow, explicitly scoped)
// ---------------------------------------------------------------------------

/// `AuthSessionServiceImpl` wipes the local Isar cache during logout/account
/// purge on mobile.
const _allowedServiceLocalDbFiles = {
  'lib/domain/services/auth/auth_session_service.dart',
};

/// Legacy canvas geometry re-export shims kept so existing callers compiling
/// against `lib/features/canvas/` continue to resolve without a breaking move.
const _allowedDomainCanvasGeometryShims = {
  'lib/domain/models/canvas/canvas_element.dart',
  'lib/domain/services/canvas/canvas_geometry.dart',
};

/// Mobile `AuthBloc` currently reads Firebase's `User` type returned by
/// `AuthSessionService` (`AuthEmailUnverified` passes `User?`). Narrowly
/// allowed until mobile auth wraps `User` in a domain `AuthAccount` model.
const _allowedFirebaseAuthBlocFiles = {'lib/features/auth/bloc/auth_bloc.dart'};

// ---------------------------------------------------------------------------
// Rule checks
// ---------------------------------------------------------------------------

void _checkFirebaseSingletonUsage(_ParsedFile file, List<String> violations) {
  final isAllowedPath =
      file.path.startsWith('lib/core/services/') ||
      file.path.startsWith('lib/core/firebase/') ||
      file.path == 'lib/firebase_options.dart';
  if (isAllowedPath) return;

  const forbidden = [
    'FirebaseAuth.instance',
    'FirebaseFirestore.instance',
    'FirebaseFunctions.instance',
    'FirebaseFunctions.instanceFor(',
  ];

  for (final token in forbidden) {
    if (file.strippedSource.contains(token)) {
      violations.add('${file.path} uses forbidden Firebase singleton: $token');
    }
  }
}

void _checkDomainModelPurity(_ParsedFile file, List<String> violations) {
  final isDomainModel =
      file.path.startsWith('lib/domain/models/') ||
      file.path.startsWith('lib/web/domain/models/');
  if (!isDomainModel) return;
  if (_allowedDomainCanvasGeometryShims.contains(file.path)) return;

  for (final uri in file.allTargetUris) {
    if (uri.startsWith('package:cloud_firestore/') ||
        uri.startsWith('package:firebase_') ||
        uri.startsWith('package:cloud_functions/') ||
        uri.startsWith('package:isar') ||
        uri.startsWith('package:agora_')) {
      violations.add(
        '${file.path} leaks backend/SDK package ($uri) into domain models.',
      );
    }
    final isOuter = file.path.startsWith('lib/domain/')
        ? (uri.startsWith('lib/features/') ||
              uri.startsWith('lib/web/') ||
              uri.startsWith('lib/ui/') ||
              uri.startsWith('lib/app/'))
        : (uri.startsWith('lib/features/') ||
              uri.startsWith('lib/ui/') ||
              uri.startsWith('lib/app/') ||
              uri.startsWith('lib/web/features/') ||
              uri.startsWith('lib/web/ui/'));
    if (isOuter) {
      violations.add(
        '${file.path} imports outer layer ($uri) into domain models.',
      );
    }
  }
}

void _checkDomainToPresentationIsolation(
  _ParsedFile file,
  List<String> violations,
) {
  if (!file.path.startsWith('lib/domain/')) return;
  if (_allowedDomainCanvasGeometryShims.contains(file.path)) return;

  for (final uri in file.allTargetUris) {
    if (uri.startsWith('lib/features/') ||
        uri.startsWith('lib/web/') ||
        uri.startsWith('lib/ui/') ||
        uri.startsWith('lib/app/')) {
      violations.add(
        '${file.path} imports outer/presentation layer ($uri). Domain must not depend on features/ui/web/app.',
      );
    }
  }
}

void _checkServiceDataAccessBoundaries(
  _ParsedFile file,
  List<String> violations,
) {
  final isServiceFile =
      file.path.startsWith('lib/domain/services/') ||
      file.path.startsWith('lib/web/domain/services/');
  if (!isServiceFile) return;

  for (final uri in file.allTargetUris) {
    final forbiddenPackage =
        uri.startsWith('package:cloud_firestore/') ||
        uri.startsWith('package:firebase_database/') ||
        uri.startsWith('package:isar_community/');
    final forbiddenFirestoreWrapper =
        uri == 'lib/core/services/firestore_service.dart';
    final forbiddenLocalDb =
        !_allowedServiceLocalDbFiles.contains(file.path) &&
        uri == 'lib/core/database/local_database_service.dart';
    final forbiddenConcreteRepo =
        (uri.startsWith('lib/domain/repositories/') ||
            uri.startsWith('lib/web/domain/repositories/')) &&
        (uri.endsWith('_impl.dart') ||
            uri.endsWith('_data_source.dart') ||
            uri ==
                'lib/web/domain/repositories/firebase_web_companion_repository.dart');

    if (forbiddenPackage || forbiddenFirestoreWrapper || forbiddenLocalDb) {
      violations.add(
        '${file.path} imports direct database access ($uri) in domain service layer. Use repository abstractions.',
      );
      break;
    }
    if (forbiddenConcreteRepo) {
      violations.add(
        '${file.path} imports concrete repository implementation ($uri). Depend on repository abstractions instead.',
      );
      break;
    }
  }

  final forbiddenDbCallPatterns = <RegExp>[
    RegExp(r'\.collection\s*\('),
    RegExp(r'\.doc\s*\('),
    RegExp(r'\.ref\s*\('),
  ];

  for (final callPattern in forbiddenDbCallPatterns) {
    if (callPattern.hasMatch(file.strippedSource)) {
      violations.add(
        '${file.path} appears to execute direct database calls in service layer. Move DB access to repositories.',
      );
      break;
    }
  }
}

void _checkBlocLayerBoundaries(_ParsedFile file, List<String> violations) {
  final isFeatureBloc =
      file.path.startsWith('lib/features/') && file.path.endsWith('_bloc.dart');
  final isWebBloc =
      file.path.startsWith('lib/web/features/') &&
      file.path.contains('/bloc/') &&
      (file.path.endsWith('_cubit.dart') || file.path.endsWith('_bloc.dart'));
  if (!isFeatureBloc && !isWebBloc) return;

  for (final uri in file.allTargetUris) {
    final forbiddenRepo =
        uri.startsWith('lib/domain/repositories/') ||
        uri.startsWith('lib/web/domain/repositories/');
    final forbiddenSdk =
        uri.startsWith('package:isar_community/') ||
        uri.startsWith('package:cloud_firestore/') ||
        uri.startsWith('package:firebase_database/') ||
        (uri.startsWith('package:firebase_auth/') &&
            !_allowedFirebaseAuthBlocFiles.contains(file.path)) ||
        uri.startsWith('package:shared_preferences/');
    final forbiddenCoreDb =
        uri == 'lib/core/database/local_database_service.dart' ||
        (uri.startsWith('lib/core/services/') &&
            uri != 'lib/core/services/cloud_functions_service.dart');

    if (forbiddenRepo || forbiddenSdk || forbiddenCoreDb) {
      violations.add(
        '${file.path} crosses BLoC boundary by importing $uri. BLoCs/Cubits must depend on domain services only.',
      );
      break;
    }
  }
}

void _checkRepositoryLayerBoundaries(
  _ParsedFile file,
  List<String> violations,
) {
  final isDomainRepo = file.path.startsWith('lib/domain/repositories/');
  final isWebRepo = file.path.startsWith('lib/web/domain/repositories/');
  if (!isDomainRepo && !isWebRepo) return;

  for (final uri in file.allTargetUris) {
    final forbiddenFunctions =
        uri.startsWith('package:cloud_functions/') ||
        uri == 'lib/core/services/cloud_functions_service.dart';
    // Repositories may import pure board_rules helpers, but never domain services.
    final forbiddenService =
        (uri.startsWith('lib/domain/services/') &&
            uri != 'lib/domain/services/board/board_rules.dart') ||
        uri.startsWith('lib/web/domain/services/');

    if (forbiddenFunctions || forbiddenService) {
      violations.add(
        '${file.path} crosses repository boundary with forbidden import ($uri). Repositories must stay data-access only.',
      );
      break;
    }
  }

  final forbiddenCallPatterns = <RegExp>[
    RegExp(r'\.httpsCallable\s*\('),
    RegExp(r'\.getHttpsCallable\s*\('),
  ];

  for (final callPattern in forbiddenCallPatterns) {
    if (callPattern.hasMatch(file.strippedSource)) {
      violations.add(
        '${file.path} calls Cloud Functions directly. Move callable orchestration to domain services.',
      );
      break;
    }
  }
}

void _checkRepositoryUsageInViews(_ParsedFile file, List<String> violations) {
  final isViewFile =
      file.path.contains('/view/') || file.path.contains('/views/');
  if (!isViewFile) return;

  final forbiddenMutationPattern = RegExp(
    r'(?:context|this\.context)\.read<[^>]*Repository[^>]*>\(\)\.(?:create|join|rename|delete|update|send|accept|decline)\w*\(',
  );
  for (final match in forbiddenMutationPattern.allMatches(
    file.strippedSource,
  )) {
    final token =
        match.group(0) ?? 'context.read<...Repository>().<mutation>()';
    violations.add('${file.path} directly mutates repository in view: $token');
  }
}

void _checkScreenLayerBoundaries(_ParsedFile file, List<String> violations) {
  final isScreenFile =
      file.path.startsWith('lib/features/') &&
      file.path.endsWith('_screen.dart');
  if (!isScreenFile) return;

  final forbiddenContextDependencyPattern = RegExp(
    r'(?:context|this\.context)\.(?:read|watch|select)<[^>]*(?:Repository|Service)[^>]*>',
  );

  for (final match in forbiddenContextDependencyPattern.allMatches(
    file.strippedSource,
  )) {
    final token =
        match.group(0) ?? 'context.read/watch/select<...Repository|Service>';
    violations.add(
      '${file.path} accesses data dependency directly in screen: $token',
    );
  }

  for (final uri in file.allTargetUris) {
    if (uri.startsWith('lib/core/services/') ||
        uri.startsWith('lib/domain/repositories/') ||
        uri.startsWith('package:cloud_firestore/') ||
        uri.startsWith('package:firebase_database/')) {
      violations.add(
        '${file.path} imports service/repository/database ($uri) directly. Keep screen UI-only.',
      );
      break;
    }
  }
}

void _checkWebScreenBoundaries(_ParsedFile file, List<String> violations) {
  final isWebView =
      file.path.startsWith('lib/web/features/') &&
      file.path.contains('/view/') &&
      file.path != 'lib/web/features/canvas/view/web_canvas_route.dart';
  if (!isWebView) return;

  for (final uri in file.allTargetUris) {
    final forbiddenDomainService =
        uri.startsWith('lib/domain/services/') &&
        uri != 'lib/domain/services/board/board_rules.dart';
    if (uri.startsWith('lib/domain/repositories/') ||
        forbiddenDomainService ||
        uri.startsWith('lib/web/domain/services/') ||
        uri.startsWith('lib/web/domain/repositories/') ||
        uri.startsWith('package:cloud_firestore/') ||
        uri.startsWith('package:firebase_') ||
        uri.startsWith('package:shared_preferences/')) {
      violations.add(
        '${file.path} bypasses web BLoC/Cubit layer by importing $uri. Communicate through web Cubits.',
      );
      break;
    }
  }

  final directContextBypass = RegExp(
    r'context\.(?:read|watch|select)<[^>]*WebCompanion(?:Repository|Service)[^>]*>',
  );
  for (final match in directContextBypass.allMatches(file.strippedSource)) {
    violations.add(
      '${file.path} reads ${match.group(0)} directly instead of a web Cubit/BLoC.',
    );
  }
}

void _checkRouteLayerBoundaries(_ParsedFile file, List<String> violations) {
  final isRouteFile =
      file.path.startsWith('lib/features/') &&
      file.path.endsWith('_route.dart');
  if (!isRouteFile) return;

  for (final uri in file.allTargetUris) {
    if (uri.startsWith('lib/domain/repositories/')) {
      violations.add(
        '${file.path} imports repository directly ($uri). Route files should use domain services.',
      );
      break;
    }
  }

  final forbiddenContextRepoRead = RegExp(
    r'context\.read<[^>]*Repository[^>]*>',
  );
  if (forbiddenContextRepoRead.hasMatch(file.strippedSource)) {
    violations.add(
      '${file.path} reads repository via context. Route files should read domain services, not repositories.',
    );
  }
}

void _checkCrossFeatureImports(_ParsedFile file, List<String> violations) {
  if (!file.path.startsWith('lib/features/')) return;
  final featureMatch = RegExp(r'^lib/features/([^/]+)/').firstMatch(file.path);
  if (featureMatch == null) return;
  final currentFeature = featureMatch.group(1)!;

  final crossFeaturePattern = RegExp(
    r"import\s+'package:inklink/features/([^/]+)/",
  );
  for (final match in crossFeaturePattern.allMatches(file.strippedSource)) {
    final importedFeature = match.group(1)!;
    if (importedFeature != currentFeature &&
        importedFeature != 'auth' &&
        importedFeature != 'navigation') {
      violations.add(
        '${file.path} imports features/$importedFeature/. Cross-feature package imports are discouraged. Extract shared logic to core/ or domain/.',
      );
    }
  }
}

void _checkScreenDirectBlocCalls(_ParsedFile file, List<String> violations) {
  final isScreenFile =
      file.path.startsWith('lib/features/') &&
      file.path.endsWith('_screen.dart');
  if (!isScreenFile) return;

  final directBlocCallPattern = RegExp(
    r'context\.read<[^>]*Bloc[^>]*>\(\)\.(?!add\()',
  );
  for (final match in directBlocCallPattern.allMatches(file.strippedSource)) {
    final token = match.group(0) ?? 'context.read<...Bloc>().<method>()';
    violations.add(
      '${file.path} calls BLoC method directly: $token. Screens should only dispatch events via .add().',
    );
  }
}

void _checkPlatformIsolationDirectImports(
  _ParsedFile file,
  List<String> violations,
) {
  final isMobileOnlyEntry =
      file.path == 'lib/main.dart' ||
      file.path == 'lib/app/composition/mobile_dependencies.dart';
  if (isMobileOnlyEntry) {
    for (final uri in file.allTargetUris) {
      if (uri.startsWith('lib/web/') ||
          uri == 'lib/app/composition/web_dependencies.dart') {
        violations.add(
          '${file.path} imports web-only module ($uri) into mobile composition.',
        );
      }
    }
  }
}

void _checkNoDummyCodeInProductionWeb(
  _ParsedFile file,
  List<String> violations,
) {
  if (!file.path.startsWith('lib/web/')) return;
  final fileName = file.path.split('/').last;
  final isDummyPath =
      file.path.contains('/preview/') ||
      fileName.startsWith('sample_') ||
      fileName.startsWith('fake_') ||
      fileName.startsWith('mock_') ||
      fileName.startsWith('dummy_');
  if (isDummyPath) {
    violations.add(
      '${file.path} belongs under test/web/, not production lib/web/.',
    );
  }
}

void _checkWebTransitivePlatformIsolation(
  Map<String, _ParsedFile> files,
  List<String> violations,
) {
  bool isForbiddenOnWeb(String uri) =>
      uri.startsWith('package:isar') ||
      uri.startsWith('lib/core/database/') ||
      uri.startsWith('package:path_provider') ||
      uri.startsWith('package:agora_chat_sdk') ||
      uri.startsWith('package:agora_rtc_engine') ||
      uri == 'lib/app/composition/mobile_dependencies.dart';

  final webRoots = files.keys.where(
    (p) =>
        p.startsWith('lib/web/') ||
        p == 'lib/app/composition/web_dependencies.dart' ||
        p == 'lib/app/composition/shared_canvas_dependencies.dart',
  );

  final visited = <String>{};
  void visit(String path, List<String> chain) {
    if (!visited.add(path)) return;
    final parsed = files[path];
    if (parsed == null) return;
    for (final uri in parsed.webResolvedUris) {
      if (isForbiddenOnWeb(uri)) {
        violations.add(
          'Web platform isolation violated: ${[...chain, path, uri].join(' -> ')}',
        );
      } else if (files.containsKey(uri)) {
        visit(uri, [...chain, path]);
      }
    }
  }

  for (final root in webRoots) {
    visit(root, const []);
  }
}

void _checkCircularDependencies(
  Map<String, _ParsedFile> files,
  List<String> violations,
) {
  // Scope cycle checks to app/, web/, and domain/ (where clean DAGs are
  // mandatory; part/part-of directives are excluded).
  bool inScope(String path) =>
      path.startsWith('lib/app/') ||
      path.startsWith('lib/web/') ||
      path.startsWith('lib/domain/');

  final state = <String, int>{}; // 0 = unvisited, 1 = visiting, 2 = done
  final stack = <String>[];
  final reported = <String>{};

  void dfs(String node) {
    state[node] = 1;
    stack.add(node);
    final parsed = files[node];
    if (parsed != null) {
      for (final d in parsed.directives) {
        // Check `import` edges only; Dart barrel files legitimately `export`
        // sub-libraries that `import` shared types declared in the barrel.
        if (d.kind != _DirectiveKind.importDir) {
          continue;
        }
        final target = d.webResolvedUri;
        if (!inScope(target) || !files.containsKey(target)) continue;
        final targetState = state[target] ?? 0;
        if (targetState == 1) {
          final startIdx = stack.indexOf(target);
          final cycle = [...stack.sublist(startIdx), target];
          final key = (List<String>.of(cycle)..sort()).join('|');
          if (reported.add(key)) {
            violations.add(
              'Circular dependency detected: ${cycle.join(' -> ')}',
            );
          }
        } else if (targetState == 0) {
          dfs(target);
        }
      }
    }
    stack.removeLast();
    state[node] = 2;
  }

  for (final path in files.keys.where(inScope)) {
    if ((state[path] ?? 0) == 0) {
      dfs(path);
    }
  }
}

// ---------------------------------------------------------------------------
// Lightweight comment-aware Dart directive parser
// ---------------------------------------------------------------------------

enum _DirectiveKind { importDir, exportDir, part, partOf }

class _DirectiveInfo {
  final _DirectiveKind kind;
  final String defaultUri;
  final String webResolvedUri;

  const _DirectiveInfo({
    required this.kind,
    required this.defaultUri,
    required this.webResolvedUri,
  });
}

class _ParsedFile {
  final String path;
  final String strippedSource;
  final List<_DirectiveInfo> directives;

  const _ParsedFile({
    required this.path,
    required this.strippedSource,
    required this.directives,
  });

  Iterable<String> get allTargetUris sync* {
    for (final d in directives) {
      if (d.kind == _DirectiveKind.partOf) continue;
      yield d.defaultUri;
      if (d.webResolvedUri != d.defaultUri) yield d.webResolvedUri;
    }
  }

  Iterable<String> get webResolvedUris sync* {
    for (final d in directives) {
      if (d.kind == _DirectiveKind.partOf) continue;
      yield d.webResolvedUri;
    }
  }
}

/// Strips `//`, `///`, and nested `/* ... */` comments while preserving string
/// literals so commented-out examples never trigger false positives.
String _stripComments(String source) {
  final out = StringBuffer();
  final len = source.length;
  var i = 0;

  while (i < len) {
    final c = source.codeUnitAt(i);
    final next = i + 1 < len ? source.codeUnitAt(i + 1) : 0;

    // Single-line comment
    if (c == 0x2F /* / */ && next == 0x2F /* / */ ) {
      i += 2;
      while (i < len && source.codeUnitAt(i) != 0x0A /* \n */ ) {
        i++;
      }
      continue;
    }

    // Block comment (supports Dart nested /* /* */ */ comments)
    if (c == 0x2F /* / */ && next == 0x2A /* * */ ) {
      var depth = 1;
      i += 2;
      while (i < len && depth > 0) {
        final cc = source.codeUnitAt(i);
        final nn = i + 1 < len ? source.codeUnitAt(i + 1) : 0;
        if (cc == 0x2F && nn == 0x2A) {
          depth++;
          i += 2;
        } else if (cc == 0x2A && nn == 0x2F) {
          depth--;
          i += 2;
        } else {
          if (cc == 0x0A) out.writeCharCode(0x0A);
          i++;
        }
      }
      continue;
    }

    // String literals (raw, triple-quoted, single/double quoted)
    final isRaw =
        (c == 0x72 /* r */ ) && (next == 0x27 /* ' */ || next == 0x22 /* " */ );
    if (isRaw || c == 0x27 || c == 0x22) {
      if (isRaw) {
        out.writeCharCode(c);
        i++;
      }
      final quote = source.codeUnitAt(i);
      final isTriple =
          i + 2 < len &&
          source.codeUnitAt(i + 1) == quote &&
          source.codeUnitAt(i + 2) == quote;
      if (isTriple) {
        out.write(source.substring(i, i + 3));
        i += 3;
        while (i < len) {
          if (!isRaw && source.codeUnitAt(i) == 0x5C /* \ */ && i + 1 < len) {
            out.write(source.substring(i, i + 2));
            i += 2;
            continue;
          }
          if (i + 2 < len &&
              source.codeUnitAt(i) == quote &&
              source.codeUnitAt(i + 1) == quote &&
              source.codeUnitAt(i + 2) == quote) {
            out.write(source.substring(i, i + 3));
            i += 3;
            break;
          }
          out.writeCharCode(source.codeUnitAt(i));
          i++;
        }
      } else {
        out.writeCharCode(quote);
        i++;
        while (i < len) {
          final ch = source.codeUnitAt(i);
          if (!isRaw && ch == 0x5C /* \ */ && i + 1 < len) {
            out.write(source.substring(i, i + 2));
            i += 2;
            continue;
          }
          out.writeCharCode(ch);
          i++;
          if (ch == quote || ch == 0x0A) break;
        }
      }
      continue;
    }

    out.writeCharCode(c);
    i++;
  }

  return out.toString();
}

final _directiveRegex = RegExp(
  r'''(?:^|\n)\s*(import|export|part\s+of|part)\s+['"]([^'"]+)['"]([^;]*);''',
);
final _conditionalBranchRegex = RegExp(
  r'''if\s*\(\s*([^)]+?)\s*\)\s*['"]([^'"]+)['"]''',
);

List<_DirectiveInfo> _parseDirectives(String strippedSource, String fromPath) {
  final out = <_DirectiveInfo>[];
  for (final match in _directiveRegex.allMatches(strippedSource)) {
    final keyword = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
    final kind = switch (keyword) {
      'import' => _DirectiveKind.importDir,
      'export' => _DirectiveKind.exportDir,
      'part of' => _DirectiveKind.partOf,
      _ => _DirectiveKind.part,
    };
    final rawDefault = match.group(2)!;
    final tail = match.group(3) ?? '';

    var rawWeb = rawDefault;
    for (final branch in _conditionalBranchRegex.allMatches(tail)) {
      final condition = branch.group(1)!.trim();
      if (condition == 'dart.library.js_interop' ||
          condition == 'dart.library.html' ||
          condition == 'dart.library.js') {
        rawWeb = branch.group(2)!;
      }
    }

    out.add(
      _DirectiveInfo(
        kind: kind,
        defaultUri: _resolveUri(fromPath, rawDefault),
        webResolvedUri: _resolveUri(fromPath, rawWeb),
      ),
    );
  }
  return out;
}

String _resolveUri(String fromFile, String uri) {
  if (uri.startsWith('package:inklink/')) {
    return 'lib/${uri.substring('package:inklink/'.length)}';
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    return uri;
  }
  final segments = fromFile.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}

String _toRelativePath(String rootPath, String fullPath) {
  var relative = fullPath.replaceFirst(rootPath, '');
  if (relative.startsWith(Platform.pathSeparator)) {
    relative = relative.substring(1);
  }
  return relative.replaceAll('\\', '/');
}
