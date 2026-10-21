import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/auth_service.dart';
import '../../bloc/canvas_bloc.dart';

class BoardChatDrawer extends StatefulWidget {
  const BoardChatDrawer({super.key});

  @override
  State<BoardChatDrawer> createState() => _BoardChatDrawerState();
}

class _BoardChatDrawerState extends State<BoardChatDrawer> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    context.read<CanvasBloc>().add(CanvasSendChatMessageRequested(text));
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<CanvasBloc, CanvasState>(
      listenWhen: (prev, curr) =>
          prev.chatMessages.length != curr.chatMessages.length,
      listener: (context, state) {
        _scrollToBottom();
      },
      builder: (context, state) {
        if (!state.isChatDrawerOpen) {
          return const SizedBox.shrink();
        }

        final currentUserId = state.currentUserId.isNotEmpty
            ? state.currentUserId
            : (context.read<AuthService?>()?.getCurrentUserId() ??
                state.boardMembers
                    .where((m) => m.role == state.currentUserRole)
                    .map((m) => m.uid)
                    .firstOrNull);

        return Positioned(
          top: 70,
          right: 16,
          bottom: 90,
          width: 340,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Board Chat',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Close chat',
                          splashRadius: 18,
                          onPressed: () {
                            context
                                .read<CanvasBloc>()
                                .add(const CanvasToggleChatDrawer());
                          },
                        ),
                      ],
                    ),
                  ),

                  // Message List
                  Expanded(
                    child: state.chatMessages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 40,
                                    color: theme.hintColor.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No messages yet',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.hintColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Send a message to start real-time chat with collaborators.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            itemCount: state.chatMessages.length,
                            itemBuilder: (context, index) {
                              final msg = state.chatMessages[index];
                              final isMe = msg.senderUid == currentUserId;
                              return _ChatMessageBubble(
                                message: msg,
                                isMe: isMe,
                              );
                            },
                          ),
                  ),

                  // Input Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primary,
                          child: IconButton(
                            icon: const Icon(Icons.send, size: 16, color: Colors.white),
                            onPressed: _sendMessage,
                            tooltip: 'Send',
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final BoardChatMessage message;
  final bool isMe;

  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
  });

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                message.senderName,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? theme.colorScheme.primary
                  : (isDark
                      ? const Color(0xFF2B2B3D)
                      : const Color(0xFFF0F0F5)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMe ? 14 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 14),
              ),
            ),
            child: Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(message.timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
