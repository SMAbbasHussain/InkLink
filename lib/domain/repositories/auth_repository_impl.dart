import 'package:cloud_firestore/cloud_firestore.dart'; // Ensure this is imported
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Add Firestore instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Stream<User?> get user => _auth.authStateChanges();

  @override
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // --- THIS PART SAVES TO FIRESTORE ---
        print("Checking Firestore for user: ${user.uid}");
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          print("New user detected. Registering in Firestore...");
          await registerUserInFirestore(user);
        } else {
          print("Existing user logged in. Updating last active...");
          await _firestore.collection('users').doc(user.uid).update({
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      }
      return user;
    } catch (e) {
      print("Error in signInWithGoogle: $e");
      throw Exception("Google Sign-In failed: $e");
    }
  }

  @override
  Future<void> registerUserInFirestore(User user) async {
    try {
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? "InkLink Creator",
        'photoURL': user.photoURL ?? '',
        'isOnline': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        // Add search keywords for your Friends search bar
        'searchKeywords': _generateSearchKeywords(user.displayName ?? ""),
      };

      await _firestore.collection('users').doc(user.uid).set(userData);
      print("User successfully saved to Firestore!");
    } catch (e) {
      print("Firestore Save Error: $e");
    }
  }

  // Helper to make the Friends search bar work later
  List<String> _generateSearchKeywords(String name) {
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < name.length; i++) {
      temp = temp + name[i].toLowerCase();
      keywords.add(temp);
    }
    return keywords;
  }

  // --- SIGN IN WITH EMAIL (Don't forget to add Firestore here too!) ---
  @override
  Future<User?> signUp(String name, String email, String password) async {
     final credential = await _auth.createUserWithEmailAndPassword(
      email: email, password: password,
    );
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(name);
      await registerUserInFirestore(user); // Save email user to Firestore
    }
    return user;
  }

  @override
  Future<User?> signIn(String email, String password) async => (await _auth.signInWithEmailAndPassword(email: email, password: password)).user;

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}