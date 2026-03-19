import 'package:cloud_functions/cloud_functions.dart';

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
    return _functions.httpsCallable(functionName);
  }

  @override
  FirebaseFunctions getInstance() {
    return _functions;
  }
}
