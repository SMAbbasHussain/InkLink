class VoiceParticipant {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int joinedAt;
  final bool isSpeaking;
  final bool isMuted;

  const VoiceParticipant({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.joinedAt,
    this.isSpeaking = false,
    this.isMuted = false,
  });

  VoiceParticipant copyWith({
    String? uid,
    String? displayName,
    String? photoUrl,
    int? joinedAt,
    bool? isSpeaking,
    bool? isMuted,
  }) {
    return VoiceParticipant(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'joinedAt': joinedAt,
      'isSpeaking': isSpeaking,
      'isMuted': isMuted,
    };
  }

  factory VoiceParticipant.fromMap(Map<String, dynamic> map) {
    return VoiceParticipant(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Anonymous',
      photoUrl: map['photoUrl'] as String?,
      joinedAt: (map['joinedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isSpeaking: map['isSpeaking'] as bool? ?? false,
      isMuted: map['isMuted'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceParticipant &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          isSpeaking == other.isSpeaking &&
          isMuted == other.isMuted;

  @override
  int get hashCode => uid.hashCode ^ isSpeaking.hashCode ^ isMuted.hashCode;
}
