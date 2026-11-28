/// Account-level settings synced across web and mobile via `users/{uid}`
/// (Privacy toggles and Preferred Content Tags).
class WebAccountSettings {
  const WebAccountSettings({
    this.isProfilePublic = true,
    this.showOnlineStatus = true,
    this.showEmail = false,
    this.preferredTags = const [],
  });

  final bool isProfilePublic;
  final bool showOnlineStatus;
  final bool showEmail;
  final List<String> preferredTags;

  static const defaults = WebAccountSettings();

  /// The topics offered in the settings UI, matching mobile order.
  static const suggestedTags = [
    'Art',
    'Architecture',
    'Brainstorming',
    'Design',
    'Education',
    'Engineering',
    'Gaming',
    'Music',
    'Productivity',
    'Wireframing',
  ];

  /// Reads a `users/{uid}` document. Missing fields fall back to defaults and
  /// malformed tag entries are dropped cleanly.
  factory WebAccountSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final rawTags = data['preferredTags'];
    return WebAccountSettings(
      isProfilePublic: (data['isProfilePublic'] as bool?) ?? true,
      showOnlineStatus: (data['showOnlineStatus'] as bool?) ?? true,
      showEmail: (data['showEmail'] as bool?) ?? false,
      preferredTags: [
        for (final tag in rawTags is List ? rawTags : const [])
          if (tag is String && tag.trim().isNotEmpty) tag.trim(),
      ],
    );
  }

  /// The three fields `updatePrivacySettings` writes.
  Map<String, dynamic> privacyFields() => {
    'isProfilePublic': isProfilePublic,
    'showOnlineStatus': showOnlineStatus,
    'showEmail': showEmail,
  };

  WebAccountSettings copyWith({
    bool? isProfilePublic,
    bool? showOnlineStatus,
    bool? showEmail,
    List<String>? preferredTags,
  }) => WebAccountSettings(
    isProfilePublic: isProfilePublic ?? this.isProfilePublic,
    showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
    showEmail: showEmail ?? this.showEmail,
    preferredTags: preferredTags ?? this.preferredTags,
  );

  /// Adds [tag] when not already chosen and removes it when present
  /// (case-insensitive, trimmed).
  static List<String> toggleTag(List<String> tags, String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return List.of(tags);
    final lower = trimmed.toLowerCase();
    final without = [
      for (final existing in tags)
        if (existing.toLowerCase() != lower) existing,
    ];
    if (without.length != tags.length) return without;
    return [...tags, trimmed];
  }

  static bool _stringListsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebAccountSettings &&
          other.isProfilePublic == isProfilePublic &&
          other.showOnlineStatus == showOnlineStatus &&
          other.showEmail == showEmail &&
          _stringListsEqual(other.preferredTags, preferredTags);

  @override
  int get hashCode => Object.hash(
    isProfilePublic,
    showOnlineStatus,
    showEmail,
    Object.hashAll(preferredTags),
  );
}
