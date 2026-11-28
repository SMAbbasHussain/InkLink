import 'package:flutter/foundation.dart';

/// The account-level settings the phone edits under Settings → Privacy and
/// Settings → Preferred Content Tags.
///
/// Nothing here is browser-local: all four values live on the `users/{uid}`
/// document (the same fields `ProfileService.updatePrivacySettings` and
/// `ProfileService.updatePreferredTags` write), so a change made on the web is
/// visible on the phone and vice versa.
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

  /// The topics the phone's settings dialog offers, in its order.
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

  /// Reads a `users/{uid}` document. Missing fields use the phone's defaults
  /// (`isProfilePublic` and `showOnlineStatus` on, `showEmail` off), and tags
  /// are trimmed with blanks and non-strings dropped, so a malformed document
  /// cannot break the settings page.
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

  /// Adds [tag] when it is not already chosen and removes it when it is.
  /// Matching ignores case and surrounding spaces; blank input is ignored.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebAccountSettings &&
          other.isProfilePublic == isProfilePublic &&
          other.showOnlineStatus == showOnlineStatus &&
          other.showEmail == showEmail &&
          listEquals(other.preferredTags, preferredTags);

  @override
  int get hashCode => Object.hash(
    isProfilePublic,
    showOnlineStatus,
    showEmail,
    Object.hashAll(preferredTags),
  );
}
