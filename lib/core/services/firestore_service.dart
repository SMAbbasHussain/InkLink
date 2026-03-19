import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstract interface for Firestore operations
/// This enables dependency injection and easier testing (can mock implementations)
abstract class FirestoreService {
  /// Get reference to a collection
  CollectionReference<Map<String, dynamic>> collection(String path);

  /// Get Firestore instance (if direct access needed)
  FirebaseFirestore getInstance();
}

/// Production implementation using Firebase
class FirestoreServiceImpl implements FirestoreService {
  final FirebaseFirestore _firestore;

  /// Constructor accepting optional FirebaseFirestore instance for testability
  /// In production, uses FirebaseFirestore.instance
  FirestoreServiceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  @override
  FirebaseFirestore getInstance() {
    return _firestore;
  }
}
