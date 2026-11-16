/// One current-vs-desired field row in a revert plan item.
class RevertDiffField {
  final String label;
  final String before;
  final String after;

  const RevertDiffField({
    required this.label,
    required this.before,
    required this.after,
  });

  factory RevertDiffField.fromMap(Map<String, dynamic> map) {
    return RevertDiffField(
      label: (map['label'] as String?) ?? '',
      before: (map['before'] as String?) ?? '',
      after: (map['after'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'label': label,
    'before': before,
    'after': after,
  };
}

/// One element in a revert plan.
class RevertPlanItem {
  final String elementId;
  /// `add` | `update` | `delete` — what applying the revert does.
  final String kind;
  final bool conflict;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String? lastEditorUid;
  /// Human noun for the element, e.g. "blue rectangle".
  final String? label;
  /// Plain-English description of what applying the revert changes.
  final String? summary;
  /// Field-level current (`before`) vs desired (`after`) rows.
  final List<RevertDiffField> fields;

  const RevertPlanItem({
    required this.elementId,
    required this.kind,
    this.conflict = false,
    this.before,
    this.after,
    this.lastEditorUid,
    this.label,
    this.summary,
    this.fields = const [],
  });

  factory RevertPlanItem.fromMap(Map<String, dynamic> map) {
    final before = map['before'];
    final after = map['after'];
    final rawFields = map['fields'];
    final fields = <RevertDiffField>[];
    if (rawFields is List) {
      for (final entry in rawFields) {
        if (entry is Map) {
          fields.add(RevertDiffField.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return RevertPlanItem(
      elementId: (map['elementId'] as String?) ?? '',
      kind: (map['kind'] as String?) ?? 'update',
      conflict: map['conflict'] == true,
      before: before is Map ? Map<String, dynamic>.from(before) : null,
      after: after is Map ? Map<String, dynamic>.from(after) : null,
      lastEditorUid: map['lastEditorUid'] as String?,
      label: map['label'] as String?,
      summary: map['summary'] as String?,
      fields: fields,
    );
  }

  /// Element type string stored in the CRDT payload (stroke/shape/text/...).
  String get elementType {
    final source = after ?? before ?? const <String, dynamic>{};
    return (source['type'] as String?) ?? 'element';
  }

  Map<String, dynamic> toMap() => {
    'elementId': elementId,
    'kind': kind,
    'conflict': conflict,
    'before': before,
    'after': after,
    'lastEditorUid': lastEditorUid,
    'label': label,
    'summary': summary,
    'fields': fields.map((f) => f.toMap()).toList(growable: false),
  };
}

/// A server-built revert plan (cached server-side for `history_apply_revert`).
class RevertPlan {
  final String planId;
  /// `restore` | `user` | `ops`
  final String mode;
  final int baseVersion;
  final List<RevertPlanItem> items;
  final String? requestId;

  const RevertPlan({
    required this.planId,
    required this.mode,
    required this.baseVersion,
    this.items = const [],
    this.requestId,
  });

  factory RevertPlan.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = <RevertPlanItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map) {
          items.add(RevertPlanItem.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return RevertPlan(
      planId: (map['planId'] as String?) ?? '',
      mode: (map['mode'] as String?) ?? 'user',
      baseVersion: (map['baseVersion'] as num?)?.toInt() ?? 0,
      items: items,
      requestId: map['requestId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'planId': planId,
    'mode': mode,
    'baseVersion': baseVersion,
    'items': items.map((i) => i.toMap()).toList(growable: false),
    'requestId': requestId,
  };

  int get conflictCount => items.where((i) => i.conflict).length;
}