import 'package:cloud_firestore/cloud_firestore.dart';

class Board {
  static const String visibilityPublic = 'public';
  static const String visibilityPrivate = 'private';
  static const String policyOwnerOnlyInvite = 'owner_only_invite';
  static const String policyLinkCanJoin = 'link_can_join';

  final String id;
  final String title;
  final String ownerId;
  final List<String> members;
  final String? previewPath;
  final String visibility;
  final String privateJoinPolicy;
  final List<String> tags;
  final bool joinViaCodeEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Board({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.members,
    this.previewPath,
    this.visibility = visibilityPrivate,
    this.privateJoinPolicy = policyOwnerOnlyInvite,
    this.tags = const [],
    this.joinViaCodeEnabled = false,
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
      visibility: (map['visibility'] as String?) ?? visibilityPrivate,
      privateJoinPolicy:
          (map['privateJoinPolicy'] as String?) ?? policyOwnerOnlyInvite,
      tags: List<String>.from(map['tags'] ?? const []),
      joinViaCodeEnabled: (map['joinViaCodeEnabled'] as bool?) ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'title': title,
      'ownerId': ownerId,
      'members': members,
      'previewPath': previewPath,
      'visibility': visibility,
      'tags': tags,
      'joinViaCodeEnabled': joinViaCodeEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    if (visibility == visibilityPrivate) {
      data['privateJoinPolicy'] = privateJoinPolicy;
    }

    return data;
  }
}
