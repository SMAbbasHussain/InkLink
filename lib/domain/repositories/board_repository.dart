import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createNewBoard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Create a new document with an auto-generated ID
    final docRef = _db.collection('boards').doc();
    
    await docRef.set({
      'boardId': docRef.id,
      'name': 'Untitled Board',
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [user.uid], // Owner is the first member
      'lastEditedBy': user.uid,
    });

    return docRef.id;
  }
}