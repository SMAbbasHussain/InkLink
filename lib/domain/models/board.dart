import 'package:cloud_firestore/cloud_firestore.dart';

class Board {
  final String id;
  final String title;
  final String ownerId;
  final List<String> members;
  final String engine;
  final DateTime createdAt;
  final DateTime updatedAt;

  Board({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.members,
    required this.engine,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.fromMap(Map<String, dynamic> map, String id) {
    return Board(
      id: id,
      title: map['title'] ?? 'Untitled Board',
      ownerId: map['ownerId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      engine: map['engine'] ?? 'crdt_v1',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'ownerId': ownerId,
      'members': members,
      'engine': engine,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
