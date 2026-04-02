import 'package:cloud_firestore/cloud_firestore.dart';

class Board {
  final String id;
  final String title;
  final String ownerId;
  final List<String> members;
  final String? previewPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Board({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.members,
    this.previewPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.fromMap(Map<String, dynamic> map, String id) {
    return Board(
      id: id,
      title: map['title'] ?? 'Untitled Board',
      ownerId: map['ownerId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      previewPath: map['previewPath'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'ownerId': ownerId,
      'members': members,
      'previewPath': previewPath,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
