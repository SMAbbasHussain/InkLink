import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Abstract interface for Firestore operations
/// This enables dependency injection and easier testing (can mock implementations)
abstract class FirestoreService {
  /// Get reference to a collection
  CollectionReference<Map<String, dynamic>> collection(String path);

  /// Get Firestore instance (if direct access needed)
  FirebaseFirestore getInstance();

  /// Get a callable Cloud Function by name
  HttpsCallable getHttpsCallable(String name);
}

/// Production implementation using Firebase
class FirestoreServiceImpl implements FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Constructor accepting optional FirebaseFirestore and FirebaseFunctions instances for testability
  /// In production, uses default Firebase instances
  FirestoreServiceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  @override
  FirebaseFirestore getInstance() {
    return _firestore;
  }

  @override
  HttpsCallable getHttpsCallable(String name) {
    return _functions.httpsCallable(name);
  }
}
