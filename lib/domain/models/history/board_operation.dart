/// A single per-element change derived server-side from the CRDT diff.
class ElementChange {
  final String elementId;
  /// `add` | `update` | `delete`
  final String kind;

  const ElementChange({required this.elementId, required this.kind});

  factory ElementChange.fromMap(Map<String, dynamic> map) {
    return ElementChange(
      elementId: (map['elementId'] as String?) ?? '',
      kind: (map['kind'] as String?) ?? 'update',
    );
  }

  Map<String, dynamic> toMap() => {'elementId': elementId, 'kind': kind};
}

/// One archived operation (an element of an R2 block array, §5.5).
class BoardOperation {
  final int version;
  final String updateId;
  final String userId;
  final String userDisplayName;
  final String? userPhotoUrl;
  final String? elementId;
  /// `upsert` | `delete` | `clear` | `revert` | `restore`
  final String action;
  final List<ElementChange> changes;
  final String payloadBase64;
  final DateTime? timestamp;
  final int? restoredFromVersion;

  const BoardOperation({
    required this.version,
    this.updateId = '',
    this.userId = '',
    this.userDisplayName = 'InkLink User',
    this.userPhotoUrl,
    this.elementId,
    this.action = 'upsert',
    this.changes = const [],
    this.payloadBase64 = '',
    this.timestamp,
    this.restoredFromVersion,
  });

  factory BoardOperation.fromMap(Map<String, dynamic> map) {
    final rawChanges = map['changes'];
    final changes = <ElementChange>[];
    if (rawChanges is List) {
      for (final entry in rawChanges) {
        if (entry is Map) {
          changes.add(ElementChange.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return BoardOperation(
      version: (map['version'] as num?)?.toInt() ?? 0,
      updateId: (map['updateId'] as String?) ?? '',
      userId: (map['userId'] as String?) ??
          (map['sourceClientId'] as String?) ??
          '',
      userDisplayName: (map['userDisplayName'] as String?) ?? 'InkLink User',
      userPhotoUrl: map['userPhotoUrl'] as String?,
      elementId: map['elementId'] as String?,
      action: (map['action'] as String?) ?? 'upsert',
      changes: changes,
      payloadBase64: (map['payloadBase64'] as String?) ?? '',
      timestamp: _parseOperationDate(map['timestamp']),
      restoredFromVersion: (map['restoredFromVersion'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'updateId': updateId,
    'userId': userId,
    'userDisplayName': userDisplayName,
    'userPhotoUrl': userPhotoUrl,
    'elementId': elementId,
    'action': action,
    'changes': changes.map((c) => c.toMap()).toList(growable: false),
    'payloadBase64': payloadBase64,
    'timestamp': timestamp?.toIso8601String(),
    if (restoredFromVersion != null)
      'restoredFromVersion': restoredFromVersion,
  };
}

DateTime? _parseOperationDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
