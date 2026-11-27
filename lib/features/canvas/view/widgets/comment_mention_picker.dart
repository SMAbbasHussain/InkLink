import 'package:flutter/material.dart';

import '../../../../domain/models/board.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_initials.dart';

/// Represents an active `@query` token immediately preceding the text cursor.
class MentionQueryMatch {
  final int startIndex;
  final int endIndex;
  final String query;

  const MentionQueryMatch({
    required this.startIndex,
    required this.endIndex,
    required this.query,
  });
}

/// Returns the active `@query` at [value.selection], or `null` if the cursor
/// is not inside a valid mention token.
MentionQueryMatch? activeMentionQuery(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) return null;
  final cursor = selection.baseOffset;
  if (cursor <= 0 || cursor > value.text.length) return null;

  final prefix = value.text.substring(0, cursor);
  final atIndex = prefix.lastIndexOf('@');
  if (atIndex == -1) return null;

  // Require start-of-string or whitespace before `@` so emails like a@b.com
  // do not trigger the mention picker.
  if (atIndex > 0 && !RegExp(r'\s').hasMatch(prefix[atIndex - 1])) {
    return null;
  }

  final query = prefix.substring(atIndex + 1);
  if (RegExp(r'\s').hasMatch(query)) return null;

  return MentionQueryMatch(
    startIndex: atIndex,
    endIndex: cursor,
    query: query,
  );
}

/// Produces a stable, whitespace-free `@handle` for [member].
String mentionHandleFor(BoardMember member) {
  final raw = (member.displayName != null && member.displayName!.trim().isNotEmpty)
      ? member.displayName!.trim()
      : (member.email != null && member.email!.contains('@'))
          ? member.email!.split('@').first.trim()
          : member.uid;

  final normalized = raw
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_.\-]'), '');

  return normalized.isNotEmpty ? normalized : member.uid;
}

/// Filters active [members] by [query] (matching displayName, email, or handle),
/// excluding [excludeUid].
List<BoardMember> filterMentionMembers(
  List<BoardMember> members, {
  required String query,
  String? excludeUid,
}) {
  final q = query.trim().toLowerCase();
  return members.where((member) {
    if (member.status != 'active') return false;
    if (excludeUid != null && excludeUid.isNotEmpty && member.uid == excludeUid) {
      return false;
    }
    if (q.isEmpty) return true;

    final name = (member.displayName ?? '').toLowerCase();
    final email = (member.email ?? '').toLowerCase();
    final handle = mentionHandleFor(member).toLowerCase();
    return name.contains(q) || email.contains(q) || handle.contains(q);
  }).toList();
}

/// Tracks `@mention` selections made from the picker tiles for a [TextEditingController].
///
/// Only users explicitly chosen from a tile are returned by [selectedMentionUids],
/// and only if their `@handle` is still present in the controller text on submit.
class MentionSelectionTracker extends ChangeNotifier {
  final TextEditingController controller;
  final Map<String, String> _chosenUidByHandleLower = {};
  MentionQueryMatch? _activeMatch;

  MentionSelectionTracker(this.controller) {
    controller.addListener(_handleControllerChanged);
  }

  MentionQueryMatch? get activeMatch => _activeMatch;

  void _handleControllerChanged() {
    final next = activeMentionQuery(controller.value);
    final changed = _activeMatch?.startIndex != next?.startIndex ||
        _activeMatch?.endIndex != next?.endIndex ||
        _activeMatch?.query != next?.query;
    _activeMatch = next;
    if (changed) {
      notifyListeners();
    }
  }

  /// Inserts `@handle ` at the active `@query` position and records [member.uid]
  /// as an explicitly chosen mention.
  void selectMember(BoardMember member) {
    final match = activeMentionQuery(controller.value);
    if (match == null) return;

    final handle = mentionHandleFor(member);
    final insertion = '@$handle ';
    final text = controller.text;
    final nextText = text.replaceRange(match.startIndex, match.endIndex, insertion);
    final nextCursor = match.startIndex + insertion.length;

    _chosenUidByHandleLower[handle.toLowerCase()] = member.uid;
    _activeMatch = null;
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    notifyListeners();
  }

  /// Returns the deduplicated UIDs of members chosen from tiles whose `@handle`
  /// still appears in [controller.text].
  List<String> get selectedMentionUids {
    if (_chosenUidByHandleLower.isEmpty) return const [];
    final text = controller.text;
    final tokens = RegExp(r'@([a-zA-Z0-9_.\-]+)')
        .allMatches(text)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet();

    final uids = <String>[];
    for (final entry in _chosenUidByHandleLower.entries) {
      if (tokens.contains(entry.key) && !uids.contains(entry.value)) {
        uids.add(entry.value);
      }
    }
    return uids;
  }

  void clear() {
    _chosenUidByHandleLower.clear();
    _activeMatch = null;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    super.dispose();
  }
}

/// Compact filtered list of board members shown when typing `@` in a comment input.
class MentionMemberPicker extends StatelessWidget {
  final List<BoardMember> members;
  final InkTokens tokens;
  final ValueChanged<BoardMember> onSelectMember;

  const MentionMemberPicker({
    super.key,
    required this.members,
    required this.tokens,
    required this.onSelectMember,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 176),
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.glassStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: members.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                'No matching board members',
                style: InkType.caption(tokens.inkMuted),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: members.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: tokens.glassStroke,
              ),
              itemBuilder: (context, index) {
                final member = members[index];
                final handle = mentionHandleFor(member);
                return InkWell(
                  onTap: () => onSelectMember(member),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        InkAvatar(
                          imageUrl: member.photoUrl,
                          initials: inkInitialsFor(member.label),
                          id: member.uid,
                          size: 26,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                member.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: InkType.bodyStrong(tokens.ink)
                                    .copyWith(fontSize: 12.5),
                              ),
                              Text(
                                '@$handle',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: InkType.caption(tokens.inkMuted)
                                    .copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            member.role,
                            style: InkType.caption(tokens.accent)
                                .copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
