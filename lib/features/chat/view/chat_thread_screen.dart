import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/models/chat/chat_message_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../profile/view/profile_route.dart';
import '../bloc/chat_thread_bloc.dart';
import '../bloc/chat_thread_event.dart';
import '../bloc/chat_thread_state.dart';
import '../theme/chat_theme.dart';
import 'group_settings_screen.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input_bar.dart';

class ChatThreadScreen extends StatelessWidget {
  final ChatConversationModel conversation;

  const ChatThreadScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthService>().getCurrentUserId() ?? '';
    return BlocProvider(
      create: (context) => ChatThreadBloc(
        chatService: context.read<ChatService>(),
        currentUid: currentUid,
      )..add(LoadChatThread(conversation.id)),
      child: _ChatThreadView(conversation: conversation),
    );
  }
}

class _ChatThreadView extends StatefulWidget {
  final ChatConversationModel conversation;

  const _ChatThreadView({required this.conversation});

  @override
  State<_ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<_ChatThreadView> {
  final ScrollController _scrollController = ScrollController();
  ChatMessageModel? _replyingTo;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    final currentUid = context.read<AuthService>().getCurrentUserId() ?? '';
    final conv = widget.conversation;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.accent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (conv.isGroup) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsScreen(groupId: conv.id),
                ),
              );
            } else {
              Navigator.push(context, buildProfileRoute(context, userId: conv.id));
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: colors.surfaceElevated,
                      backgroundImage: conv.avatarUrl != null && conv.avatarUrl!.isNotEmpty
                          ? NetworkImage(conv.avatarUrl!)
                          : null,
                      child: conv.avatarUrl == null || conv.avatarUrl!.isEmpty
                          ? Icon(
                              conv.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                              color: colors.textSecondary,
                              size: 20,
                            )
                          : null,
                    ),
                    if (!conv.isGroup)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: conv.isOnline ? colors.statusOnline : colors.statusOffline,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        conv.isGroup
                            ? '${conv.memberIds.length} members'
                            : (conv.isOnline ? 'Active now' : 'Offline'),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (conv.isGroup)
            IconButton(
              icon: Icon(Icons.info_outline_rounded, color: colors.accent),
              tooltip: 'Group Details',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupSettingsScreen(groupId: conv.id),
                  ),
                );
              },
            )
          else
            IconButton(
              icon: Icon(Icons.person_outline_rounded, color: colors.accent),
              tooltip: 'View Profile',
              onPressed: () {
                Navigator.push(context, buildProfileRoute(context, userId: conv.id));
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Message History List
          Expanded(
            child: BlocConsumer<ChatThreadBloc, ChatThreadState>(
              listener: (context, state) {
                if (state is ChatThreadLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                }
              },
              builder: (context, state) {
                if (state is ChatThreadLoading) {
                  return Center(child: CircularProgressIndicator(color: colors.accent));
                }

                if (state is ChatThreadLoaded) {
                  final messages = state.messages;
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.accent.withOpacity(0.12),
                              ),
                              child: Icon(
                                conv.isGroup ? Icons.groups_rounded : Icons.waving_hand_rounded,
                                size: 40,
                                color: colors.accent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              conv.isGroup
                                  ? 'Welcome to ${conv.name}!'
                                  : 'Say hello to ${conv.name}!',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This is the beginning of your conversation.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUid;

                      // Message grouping logic
                      final bool isFirstInGroup = index == 0 ||
                          messages[index - 1].senderId != message.senderId ||
                          message.timestamp.difference(messages[index - 1].timestamp).inMinutes > 5;

                      return ChatBubble(
                        key: ValueKey(message.id),
                        message: message,
                        isMe: isMe,
                        showHeader: isFirstInGroup,
                        currentUid: currentUid,
                        onReplyRequested: () {
                          setState(() => _replyingTo = message);
                        },
                        onReactionToggled: (emoji) {
                          context.read<ChatThreadBloc>().add(
                            ToggleReactionRequested(messageId: message.id, emoji: emoji),
                          );
                        },
                        onEditRequested: (newText) {
                          context.read<ChatThreadBloc>().add(
                            EditMessageRequested(messageId: message.id, newContent: newText),
                          );
                        },
                        onDeleteRequested: () {
                          context.read<ChatThreadBloc>().add(
                            DeleteMessageRequested(message.id),
                          );
                        },
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // iMessage-Style Chat Input Bar with WhatsApp-style Reply Banner
          ChatInputBar(
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
            onSendText: (text, {replyToId, replyToSender, replyToText}) {
              context.read<ChatThreadBloc>().add(
                SendTextMessageRequested(
                  text: text,
                  isGroup: conv.isGroup,
                  conversationName: conv.name,
                  conversationAvatar: conv.avatarUrl,
                  replyToId: replyToId,
                  replyToSender: replyToSender,
                  replyToText: replyToText,
                ),
              );
            },
            onSendImage: (filePath, {replyToId, replyToSender, replyToText}) {
              context.read<ChatThreadBloc>().add(
                SendImageMessageRequested(
                  filePath: filePath,
                  isGroup: conv.isGroup,
                  conversationName: conv.name,
                  conversationAvatar: conv.avatarUrl,
                  replyToId: replyToId,
                  replyToSender: replyToSender,
                  replyToText: replyToText,
                ),
              );
            },
            onSendGif: (gifUrl, {replyToId, replyToSender, replyToText}) {
              context.read<ChatThreadBloc>().add(
                SendGifMessageRequested(
                  gifUrl: gifUrl,
                  isGroup: conv.isGroup,
                  conversationName: conv.name,
                  conversationAvatar: conv.avatarUrl,
                  replyToId: replyToId,
                  replyToSender: replyToSender,
                  replyToText: replyToText,
                ),
              );
            },
            onSendSharePayload: (payload, {replyToId, replyToSender, replyToText}) {
              context.read<ChatThreadBloc>().add(
                SendShareCardRequested(
                  payload: payload,
                  isGroup: conv.isGroup,
                  conversationName: conv.name,
                  conversationAvatar: conv.avatarUrl,
                  replyToId: replyToId,
                  replyToSender: replyToSender,
                  replyToText: replyToText,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
