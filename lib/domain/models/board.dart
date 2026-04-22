import 'package:cloud_firestore/cloud_firestore.dart';

class Board {
  static const String visibilityPublic = 'public';
  static const String visibilityPrivate = 'private';
  static const String policyOwnerOnlyInvite = 'owner_only_invite';
  static const String policyLinkCanJoin = 'link_can_join';
  static const String roleOwner = 'owner';
  static const String roleEditor = 'editor';
  static const String roleViewer = 'viewer';
  static const String inviteOwnerOnly = 'owner_only';
  static const String inviteOwnerEditor = 'owner_editor';
  static const String inviteAllMembers = 'all_members';

  final String id;
  final String title;
  final String ownerId;
  final List<String> members;
  final String? previewPath;
  final String visibility;
  final String privateJoinPolicy;
  final List<String> tags;
  final bool joinViaCodeEnabled;
  final String whoCanInvite;
  final String defaultLinkJoinRole;
  final String currentUserRole;
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
    this.whoCanInvite = inviteOwnerOnly,
    this.defaultLinkJoinRole = roleViewer,
    this.currentUserRole = roleViewer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.fromMap(Map<String, dynamic> map, String id) {
    final invitePolicy = map['invitePolicy'] as Map<String, dynamic>?;
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
      whoCanInvite:
          (invitePolicy?['whoCanInvite'] as String?) ?? inviteOwnerOnly,
      defaultLinkJoinRole:
          (invitePolicy?['defaultLinkJoinRole'] as String?) ?? roleViewer,
      currentUserRole: (map['currentUserRole'] as String?) ?? roleViewer,
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
      'invitePolicy': {
        'whoCanInvite': whoCanInvite,
        'defaultLinkJoinRole': defaultLinkJoinRole,
      },
      'currentUserRole': currentUserRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    if (visibility == visibilityPrivate) {
      data['privateJoinPolicy'] = privateJoinPolicy;
    }

    return data;
  }
}

class BoardMember {
  final String uid;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const BoardMember({
    required this.uid,
    required this.role,
    required this.status,
    this.joinedAt,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  String get label {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!;
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!;
    }
    return uid;
  }
}
