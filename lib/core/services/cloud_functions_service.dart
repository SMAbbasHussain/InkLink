import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Abstract interface for Firebase Cloud Functions operations
/// This enables dependency injection and easier testing (can mock implementations)
abstract class CloudFunctionsService {
  /// Get a callable Cloud Function
  HttpsCallable httpsCallable(String functionName);

  /// Get Firebase Functions instance (if direct access needed)
  FirebaseFunctions getInstance();
}

/// Production implementation using Firebase
class CloudFunctionsServiceImpl implements CloudFunctionsService {
  final FirebaseFunctions _functions;

  /// Constructor accepting optional FirebaseFunctions instance for testability
  /// In production, uses FirebaseFunctions.instanceFor(region: 'us-central1')
  CloudFunctionsServiceImpl({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  HttpsCallable httpsCallable(String functionName) {
    final emulatorUrl = _localEmulatorUrlFor(functionName);
    if (emulatorUrl != null) {
      return _functions.httpsCallableFromUrl(emulatorUrl);
    }
    return _functions.httpsCallable(functionName);
  }

  /// AI callables that may be sent to a local Functions emulator.
  static const Set<String> _emulatorFunctions = {
    'generateAiImage',
    'editAiImage',
    'inpaintAiImage',
  };

  /// DEBUG BUILDS ONLY. Lets a developer test the AI callables against the
  /// Functions emulator on their PC without deploying, by setting
  /// `USE_FUNCTIONS_EMULATOR=true` (and optionally `FUNCTIONS_EMULATOR_HOST`,
  /// `FUNCTIONS_EMULATOR_PORT`) in `.env`. Every other callable, and every
  /// release build, always uses the deployed functions.
  String? _localEmulatorUrlFor(String functionName) {
    if (!kDebugMode || !_emulatorFunctions.contains(functionName)) {
      return null;
    }
    try {
      final env = dotenv.env;
      final enabled = (env['USE_FUNCTIONS_EMULATOR'] ?? '').trim().toLowerCase();
      if (enabled != 'true') return null;
      final host = (env['FUNCTIONS_EMULATOR_HOST'] ?? '').trim();
      final port = (env['FUNCTIONS_EMULATOR_PORT'] ?? '').trim();
      final projectId = _functions.app.options.projectId;
      return 'http://${host.isEmpty ? '127.0.0.1' : host}'
          ':${port.isEmpty ? '5001' : port}'
          '/$projectId/us-central1/$functionName';
    } catch (_) {
      // .env not loaded (e.g. in tests): use the deployed functions.
      return null;
    }
  }

  @override
  FirebaseFunctions getInstance() {
    return _functions;
  }
}
