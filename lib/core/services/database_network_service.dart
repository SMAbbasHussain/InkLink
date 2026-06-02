import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class DatabaseNetworkService {
  final FirebaseDatabase _database;

  DatabaseNetworkService({required FirebaseDatabase database})
      : _database = database;

  Future<void> enableNetwork() async {
    await FirebaseFirestore.instance.enableNetwork();
  }

  Future<void> disableNetwork() async {
    await FirebaseFirestore.instance.disableNetwork();
  }

  Future<void> goOnline() async {
    await _database.goOnline();
  }

  Future<void> goOffline() async {
    await _database.goOffline();
  }
}
