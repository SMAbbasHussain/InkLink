DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    return (value as dynamic).toDate() as DateTime? ?? DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
}

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
  final bool? _isArchived;
  bool get isArchived => _isArchived ?? false;
  final bool? _allowMembersToCopy;
  bool get allowMembersToCopy => _allowMembersToCopy ?? false;
  final int membersCount;
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
    bool isArchived = false,
    bool allowMembersToCopy = false,
    int? membersCount,
    required this.createdAt,
    required this.updatedAt,
  }) : _isArchived = isArchived,
       _allowMembersToCopy = allowMembersToCopy,
       membersCount = membersCount ?? members.length;

  factory Board.fromMap(Map<String, dynamic> map, String id) {
    final invitePolicy = map['invitePolicy'] as Map<String, dynamic>?;
    final membersList = List<String>.from(map['members'] ?? []);
    final rawCount = map['membersCount'] ?? map['memberCount'];
    final membersCount = rawCount is int
        ? rawCount
        : (rawCount is num ? rawCount.toInt() : membersList.length);

    return Board(
      id: id,
      title: map['title'] ?? 'Untitled Board',
      ownerId: map['ownerId'] ?? '',
      members: membersList,
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
      isArchived: (map['isArchived'] as bool?) ?? false,
      allowMembersToCopy: (map['allowMembersToCopy'] as bool?) ?? false,
      membersCount: membersCount,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Board copyWith({
    String? id,
    String? title,
    String? ownerId,
    List<String>? members,
    String? previewPath,
    String? visibility,
    String? privateJoinPolicy,
    List<String>? tags,
    bool? joinViaCodeEnabled,
    String? whoCanInvite,
    String? defaultLinkJoinRole,
    String? currentUserRole,
    bool? isArchived,
    bool? allowMembersToCopy,
    int? membersCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Board(
      id: id ?? this.id,
      title: title ?? this.title,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      previewPath: previewPath ?? this.previewPath,
      visibility: visibility ?? this.visibility,
      privateJoinPolicy: privateJoinPolicy ?? this.privateJoinPolicy,
      tags: tags ?? this.tags,
      joinViaCodeEnabled: joinViaCodeEnabled ?? this.joinViaCodeEnabled,
      whoCanInvite: whoCanInvite ?? this.whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole ?? this.defaultLinkJoinRole,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      isArchived: isArchived ?? this.isArchived,
      allowMembersToCopy: allowMembersToCopy ?? this.allowMembersToCopy,
      membersCount: membersCount ?? this.membersCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'title': title,
      'ownerId': ownerId,
      'members': members,
      'memberCount': membersCount,
      'membersCount': membersCount,
      'previewPath': previewPath,
      'visibility': visibility,
      'tags': tags,
      'joinViaCodeEnabled': joinViaCodeEnabled,
      'isArchived': isArchived,
      'allowMembersToCopy': allowMembersToCopy,
      'invitePolicy': {
        'whoCanInvite': whoCanInvite,
        'defaultLinkJoinRole': defaultLinkJoinRole,
      },
      'currentUserRole': currentUserRole,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
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

enum PublicBoardSort {
  recent,
  popular,
}

class PublicBoardsPage {
  final List<Board> boards;
  final dynamic lastDocCursor;
  final bool hasMore;

  const PublicBoardsPage({
    required this.boards,
    this.lastDocCursor,
    required this.hasMore,
  });
}
