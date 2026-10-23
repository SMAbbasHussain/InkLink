import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../bloc/chat_inbox_bloc.dart';
import '../bloc/chat_inbox_event.dart';
import '../bloc/chat_inbox_state.dart';
import '../theme/chat_theme.dart';
import 'chat_thread_screen.dart';
import 'widgets/create_group_sheet.dart';

class ChatInboxScreen extends StatelessWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatInboxBloc(
        chatService: context.read<ChatService>(),
      )..add(const LoadChatInbox()),
      child: const _ChatInboxView(),
    );
  }
}

class _ChatInboxView extends StatefulWidget {
  const _ChatInboxView();

  @override
  State<_ChatInboxView> createState() => _ChatInboxViewState();
}

class _ChatInboxViewState extends State<_ChatInboxView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewDmSheet(ChatColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ChatTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Start Direct Message',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: ChatTheme.space12),
                Expanded(
                  child: BlocBuilder<FriendsBloc, FriendsState>(
                    builder: (_, friendsState) {
                      List<Map<String, dynamic>> friends = [];
                      if (friendsState is FriendsLoaded) {
                        friends = friendsState.friends;
                      }

                      if (friends.isEmpty) {
                        return Center(
                          child: Text(
                            'No friends found. Add friends to start chatting!',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: friends.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final f = friends[index];
                          final uid = f['uid'].toString();
                          final name = f['displayName']?.toString() ?? 'User';
                          final photo = f['photoURL']?.toString();

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: colors.surfaceElevated,
                              backgroundImage: photo != null && photo.isNotEmpty
                                  ? NetworkImage(photo)
                                  : null,
                              child: photo == null || photo.isEmpty
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              f['email']?.toString() ?? '',
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              final conv = ChatConversationModel(
                                id: uid,
                                name: name,
                                avatarUrl: photo,
                                isGroup: false,
                              );
                              await Navigator.push(
                                this.context,
                                MaterialPageRoute(
                                  builder: (_) => ChatThreadScreen(conversation: conv),
                                ),
                              );
                              if (mounted) {
                                this.context.read<ChatInboxBloc>().add(const LoadChatInbox());
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateGroupSheet() async {
    final createdGroup = await showModalBottomSheet<ChatConversationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateGroupSheet(),
    );

    if (createdGroup != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(conversation: createdGroup),
        ),
      );
      if (mounted) {
        context.read<ChatInboxBloc>().add(const LoadChatInbox());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0.5,
        title: Text(
          'Messages',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.group_add_outlined, color: colors.accent),
            tooltip: 'Create Group',
            onPressed: () => _showCreateGroupSheet(),
          ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: colors.accent),
            tooltip: 'New DM',
            onPressed: () => _showNewDmSheet(colors),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ChatTheme.space16,
              vertical: ChatTheme.space8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                context.read<ChatInboxBloc>().add(SearchConversations(val));
              },
              style: TextStyle(color: colors.inputText, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search chats & groups...',
                hintStyle: TextStyle(color: colors.inputHint, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: colors.textSecondary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ChatInboxBloc>().add(const SearchConversations(''));
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: colors.inputFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ChatTheme.space12,
                  vertical: ChatTheme.space8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.inputBorder, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.inputBorder, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.accent, width: 1.2),
                ),
              ),
            ),
          ),

          // Conversation List
          Expanded(
            child: BlocBuilder<ChatInboxBloc, ChatInboxState>(
              builder: (context, state) {
                if (state is ChatInboxLoading) {
                  return Center(child: CircularProgressIndicator(color: colors.accent));
                }

                if (state is ChatInboxLoaded) {
                  final conversations = state.filteredConversations;

                  if (conversations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(ChatTheme.space24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 56,
                              color: colors.textSecondary.withOpacity(0.4),
                            ),
                            const SizedBox(height: ChatTheme.space16),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Start a direct message with friends or create a new group chat to begin collaborating.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: ChatTheme.space24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                                  label: const Text('New Chat'),
                                  onPressed: () => _showNewDmSheet(colors),
                                ),
                                const SizedBox(width: ChatTheme.space12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.accent,
                                    side: BorderSide(color: colors.accent),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.groups_outlined, size: 16),
                                  label: const Text('New Group'),
                                  onPressed: () => _showCreateGroupSheet(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => Divider(
                      color: colors.divider,
                      height: 1,
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      final bool hasUnread = conv.unreadCount > 0;

                      return Dismissible(
                        key: Key(conv.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: colors.surface,
                              title: Text(
                                'Delete Conversation',
                                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                              ),
                              content: Text(
                                'Delete your chat with ${conv.name}?',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          context.read<ChatInboxBloc>().add(DeleteConversationRequested(conv.id));
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: ChatTheme.space16,
                            vertical: 6,
                          ),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: colors.surfaceElevated,
                                backgroundImage: conv.avatarUrl != null && conv.avatarUrl!.isNotEmpty
                                    ? NetworkImage(conv.avatarUrl!)
                                    : null,
                                child: conv.avatarUrl == null || conv.avatarUrl!.isEmpty
                                    ? Icon(
                                        conv.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                                        color: colors.textSecondary,
                                        size: 24,
                                      )
                                    : null,
                              ),
                              if (!conv.isGroup)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: conv.isOnline ? colors.statusOnline : colors.statusOffline,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colors.surface, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conv.name,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conv.lastMessageTimestamp != null)
                                Text(
                                  _formatTimestamp(conv.lastMessageTimestamp!),
                                  style: TextStyle(
                                    color: hasUnread ? colors.accent : colors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conv.lastMessage ?? 'No messages yet',
                                  style: TextStyle(
                                    color: hasUnread ? colors.textPrimary : colors.textSecondary,
                                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conv.isMuted) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.volume_off, color: colors.textSecondary, size: 14),
                              ],
                              if (conv.unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${conv.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () async {
                            context.read<ChatInboxBloc>().add(MarkConversationReadRequested(conv.id));
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatThreadScreen(conversation: conv),
                              ),
                            );
                            if (context.mounted) {
                              context.read<ChatInboxBloc>().add(const LoadChatInbox());
                            }
                          },
                        ),
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays == 0) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
