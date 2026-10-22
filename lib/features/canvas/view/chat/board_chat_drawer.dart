import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../bloc/canvas_bloc.dart';
import '../../models/board_chat_message.dart';

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
    final tokens = context.ink;

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

        final topInset = MediaQuery.of(context).padding.top + 64;

        return Positioned(
          top: topInset,
          right: 16,
          bottom: 96,
          width: 340,
          child: GlassPanel(
            radius: InkRadii.card,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: InkSpacing.s16,
                    vertical: InkSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tokens.glassStroke,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.messageSquare,
                        size: 18,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: InkSpacing.s8),
                      Text(
                        'Board Chat',
                        style: InkType.subhead(tokens.ink),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(LucideIcons.x, size: 18, color: tokens.inkMuted),
                        tooltip: 'Close chat',
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
                                  LucideIcons.messagesSquare,
                                  size: 40,
                                  color: tokens.inkMuted.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No messages yet',
                                  style: InkType.bodyStrong(tokens.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Send a message to start real-time chat with collaborators.',
                                  textAlign: TextAlign.center,
                                  style: InkType.caption(tokens.inkMuted),
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
                              tokens: tokens,
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
                        color: tokens.glassStroke,
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
                          style: InkType.body(tokens.ink),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: InkType.body(tokens.inkMuted),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: tokens.field,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: tokens.accent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sendMessage,
                          child: const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Icon(LucideIcons.send, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
  final InkTokens tokens;

  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.tokens,
  });

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
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
                style: InkType.caption(tokens.accent).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? tokens.accent
                  : tokens.paper,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMe ? 14 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 14),
              ),
              boxShadow: tokens.paperShadow,
            ),
            child: Text(
              message.text,
              style: InkType.body(isMe ? Colors.white : tokens.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(message.timestamp),
              style: InkType.caption(tokens.inkMuted).copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
