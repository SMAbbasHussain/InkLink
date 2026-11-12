/// Per-contributor summary stored on an `activity_index` doc.
class ContributorSummary {
  final String name;
  final String? photoUrl;
  final int ops;
  final int adds;
  final int updates;
  final int deletes;

  const ContributorSummary({
    required this.name,
    this.photoUrl,
    this.ops = 0,
    this.adds = 0,
    this.updates = 0,
    this.deletes = 0,
  });

  factory ContributorSummary.fromMap(Map<String, dynamic> map) {
    return ContributorSummary(
      name: (map['name'] as String?) ?? 'InkLink User',
      photoUrl: map['photoUrl'] as String?,
      ops: (map['ops'] as num?)?.toInt() ?? 0,
      adds: (map['adds'] as num?)?.toInt() ?? 0,
      updates: (map['updates'] as num?)?.toInt() ?? 0,
      deletes: (map['deletes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'photoUrl': photoUrl,
    'ops': ops,
    'adds': adds,
    'updates': updates,
    'deletes': deletes,
  };
}

/// One archived block of operations (`boards/{boardId}/activity_index/{blockId}`).
class BoardActivityBlock {
  final String blockId;
  final int fromVersion;
  final int toVersion;
  final int operationCount;
  final DateTime? firstOpAt;
  final DateTime? lastOpAt;
  final List<String> contributorUids;
  final Map<String, ContributorSummary> summary;
  final String r2BlockKey;
  final int? milestoneVersion;
  final bool summaryTruncated;
  final List<RestoreSummary> restores;

  const BoardActivityBlock({
    required this.blockId,
    required this.fromVersion,
    required this.toVersion,
    this.operationCount = 0,
    this.firstOpAt,
    this.lastOpAt,
    this.contributorUids = const [],
    this.summary = const {},
    this.r2BlockKey = '',
    this.milestoneVersion,
    this.summaryTruncated = false,
    this.restores = const [],
  });

  factory BoardActivityBlock.fromMap(Map<String, dynamic> map) {
    final rawSummary = map['summary'];
    final summary = <String, ContributorSummary>{};
    if (rawSummary is Map) {
      rawSummary.forEach((key, value) {
        if (value is Map) {
          summary[key.toString()] = ContributorSummary.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    final rawRestores = map['restores'];
    final restores = <RestoreSummary>[];
    if (rawRestores is List) {
      for (final entry in rawRestores) {
        if (entry is Map) {
          restores.add(RestoreSummary.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return BoardActivityBlock(
      blockId: (map['blockId'] as String?) ?? '',
      fromVersion: (map['fromVersion'] as num?)?.toInt() ?? 0,
      toVersion: (map['toVersion'] as num?)?.toInt() ?? 0,
      operationCount: (map['operationCount'] as num?)?.toInt() ?? 0,
      firstOpAt: _parseDate(map['firstOpAt']),
      lastOpAt: _parseDate(map['lastOpAt']),
      contributorUids: (map['contributorUids'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      summary: summary,
      r2BlockKey: (map['r2BlockKey'] as String?) ?? '',
      milestoneVersion: (map['milestoneVersion'] as num?)?.toInt(),
      summaryTruncated: map['summaryTruncated'] == true,
      restores: restores,
    );
  }

  Map<String, dynamic> toMap() => {
    'blockId': blockId,
    'fromVersion': fromVersion,
    'toVersion': toVersion,
    'operationCount': operationCount,
    'firstOpAt': firstOpAt?.toIso8601String(),
    'lastOpAt': lastOpAt?.toIso8601String(),
    'contributorUids': contributorUids,
    'summary': summary.map((key, value) => MapEntry(key, value.toMap())),
    'r2BlockKey': r2BlockKey,
    'milestoneVersion': milestoneVersion,
    if (summaryTruncated) 'summaryTruncated': true,
    if (restores.isNotEmpty)
      'restores': restores.map((r) => r.toMap()).toList(growable: false),
  };
}

class RestoreSummary {
  final String? byUid;
  final int? restoredFromVersion;
  final int? atVersion;

  const RestoreSummary({
    this.byUid,
    this.restoredFromVersion,
    this.atVersion,
  });

  factory RestoreSummary.fromMap(Map<String, dynamic> map) {
    return RestoreSummary(
      byUid: map['byUid'] as String?,
      restoredFromVersion: (map['restoredFromVersion'] as num?)?.toInt(),
      atVersion: (map['atVersion'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'byUid': byUid,
    'restoredFromVersion': restoredFromVersion,
    'atVersion': atVersion,
  };
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return null;
}
