import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/database/collections/local_profile.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../theme/chat_theme.dart';

class ReactorItem {
  final String uid;
  final String emoji;
  String displayName;
  String? photoURL;
  final bool isMe;

  ReactorItem({
    required this.uid,
    required this.emoji,
    required this.displayName,
    this.photoURL,
    required this.isMe,
  });
}

class MessageReactionsSheet extends StatefulWidget {
  final Map<String, List<String>> reactions;
  final String currentUid;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final Function(String emoji)? onReactionToggled;

  const MessageReactionsSheet({
    super.key,
    required this.reactions,
    required this.currentUid,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.onReactionToggled,
  });

  @override
  State<MessageReactionsSheet> createState() => _MessageReactionsSheetState();
}

class _MessageReactionsSheetState extends State<MessageReactionsSheet> {
  String? _selectedEmojiFilter; // null means "All"
  List<ReactorItem> _reactors = [];

  @override
  void initState() {
    super.initState();
    _initReactors();
  }

  Future<void> _initReactors() async {
    final authService = context.read<AuthService>();
    final localDb = context.read<LocalDatabaseService>();
    final firestore = context.read<FirestoreService>();
    final currentUser = authService.getCurrentUser();
    final currentUid = widget.currentUid;

    final List<ReactorItem> items = [];
    final Set<String> uidsToLookup = {};

    for (final entry in widget.reactions.entries) {
      final emoji = entry.key;
      for (final uid in entry.value) {
        final isMe = uid == currentUid || uid == 'me';
        String displayName = 'User';
        String? photoURL;

        if (isMe) {
          displayName = currentUser?.displayName ?? 'You';
          photoURL = currentUser?.photoURL;
        } else if (uid == widget.senderId && widget.senderName != null) {
          displayName = widget.senderName!;
          photoURL = widget.senderAvatar;
        } else {
          uidsToLookup.add(uid);
        }

        items.add(ReactorItem(
          uid: uid,
          emoji: emoji,
          displayName: displayName,
          photoURL: photoURL,
          isMe: isMe,
        ));
      }
    }

    // Sort so current user is at the top
    items.sort((a, b) {
      if (a.isMe && !b.isMe) return -1;
      if (!a.isMe && b.isMe) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    if (mounted) {
      setState(() {
        _reactors = items;
      });
    }

    if (uidsToLookup.isNotEmpty) {
      final Map<String, ({String name, String? photo})> resolved = {};

      // 1. Try resolving from local Isar database
      try {
        final isar = await localDb.database;
        final cached = await isar.localProfiles.getAllByUid(uidsToLookup.toList());
        for (final p in cached.whereType<LocalProfile>()) {
          resolved[p.uid] = (name: p.displayName, photo: p.photoURL);
        }
      } catch (_) {}

      // 2. For any still missing, try Firestore
      final remainingUids = uidsToLookup.where((id) => !resolved.containsKey(id)).toList();
      if (remainingUids.isNotEmpty) {
        try {
          for (final uid in remainingUids) {
            final doc = await firestore.collection('users').doc(uid).get();
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              final name = data['displayName']?.toString() ??
                  data['name']?.toString() ??
                  data['email']?.toString() ??
                  'User';
              final photo = data['photoURL']?.toString() ?? data['avatarUrl']?.toString();
              resolved[uid] = (name: name, photo: photo);
            }
          }
        } catch (_) {}
      }

      // Update items with resolved details
      if (mounted && resolved.isNotEmpty) {
        setState(() {
          for (final item in _reactors) {
            if (resolved.containsKey(item.uid)) {
              final r = resolved[item.uid]!;
              item.displayName = r.name;
              item.photoURL = r.photo;
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);

    final filteredReactors = _selectedEmojiFilter == null
        ? _reactors
        : _reactors.where((r) => r.emoji == _selectedEmojiFilter).toList();

    final totalCount = _reactors.length;
    final uniqueEmojis = widget.reactions.keys.toList();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header title and count
            Row(
              children: [
                Text(
                  'Reactions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Filter chips if multiple unique emojis
            if (uniqueEmojis.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All $totalCount',
                      isSelected: _selectedEmojiFilter == null,
                      onTap: () => setState(() => _selectedEmojiFilter = null),
                      colors: colors,
                    ),
                    const SizedBox(width: 8),
                    ...uniqueEmojis.map((emoji) {
                      final count = widget.reactions[emoji]?.length ?? 0;
                      final isSelected = _selectedEmojiFilter == emoji;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: '$emoji $count',
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedEmojiFilter = emoji),
                          colors: colors,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            const Divider(height: 1, thickness: 0.6),

            // List of reactors
            Expanded(
              child: filteredReactors.isEmpty
                  ? Center(
                      child: Text(
                        'No reactions found',
                        style: TextStyle(color: colors.textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredReactors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = filteredReactors[index];
                        final initial = item.displayName.isNotEmpty
                            ? item.displayName[0].toUpperCase()
                            : '?';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          onTap: item.isMe && widget.onReactionToggled != null
                              ? () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                  widget.onReactionToggled!(item.emoji);
                                }
                              : null,
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: colors.surfaceElevated,
                            backgroundImage: item.photoURL != null && item.photoURL!.isNotEmpty
                                ? NetworkImage(item.photoURL!)
                                : null,
                            child: item.photoURL == null || item.photoURL!.isEmpty
                                ? Text(
                                    initial,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.displayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: item.isMe
                              ? Text(
                                  'Tap to remove reaction',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.accent.withOpacity(0.85),
                                  ),
                                )
                              : null,
                          trailing: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.inputFill,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.divider.withOpacity(0.5),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              item.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ChatColors colors,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
