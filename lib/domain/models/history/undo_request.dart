/// `boards/{boardId}/undo_requests/{requestId}` (D5).
class UndoRequest {
  final String requestId;
  final String boardId;
  final String requesterUid;
  final String requesterName;
  final String? requesterPhotoUrl;
  final List<String> targetElementIds;
  final DateTime? timeRangeStart;
  final DateTime? timeRangeEnd;
  final String reason;
  /// `pending` | `approved` | `denied`
  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;
  final int? appliedVersion;

  const UndoRequest({
    required this.requestId,
    required this.boardId,
    required this.requesterUid,
    this.requesterName = 'InkLink User',
    this.requesterPhotoUrl,
    this.targetElementIds = const [],
    this.timeRangeStart,
    this.timeRangeEnd,
    this.reason = '',
    this.status = 'pending',
    this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
    this.appliedVersion,
  });

  factory UndoRequest.fromMap(String id, Map<String, dynamic> map) {
    return UndoRequest(
      requestId: (map['requestId'] as String?) ?? id,
      boardId: (map['boardId'] as String?) ?? '',
      requesterUid: (map['requesterUid'] as String?) ?? '',
      requesterName: (map['requesterName'] as String?) ?? 'InkLink User',
      requesterPhotoUrl: map['requesterPhotoUrl'] as String?,
      targetElementIds: (map['targetElementIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      timeRangeStart: _parseRequestDate(map['timeRangeStart']),
      timeRangeEnd: _parseRequestDate(map['timeRangeEnd']),
      reason: (map['reason'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pending',
      createdAt: _parseRequestDate(map['createdAt']),
      resolvedAt: _parseRequestDate(map['resolvedAt']),
      resolvedBy: map['resolvedBy'] as String?,
      resolutionNote: map['resolutionNote'] as String?,
      appliedVersion: (map['appliedVersion'] as num?)?.toInt(),
    );
  }

  bool get isPending => status == 'pending';

  Map<String, dynamic> toMap() => {
    'requestId': requestId,
    'boardId': boardId,
    'requesterUid': requesterUid,
    'requesterName': requesterName,
    'requesterPhotoUrl': requesterPhotoUrl,
    'targetElementIds': targetElementIds,
    'timeRangeStart': timeRangeStart?.toIso8601String(),
    'timeRangeEnd': timeRangeEnd?.toIso8601String(),
    'reason': reason,
    'status': status,
    'createdAt': createdAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'resolvedBy': resolvedBy,
    'resolutionNote': resolutionNote,
    'appliedVersion': appliedVersion,
  };
}

DateTime? _parseRequestDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return null;
}
