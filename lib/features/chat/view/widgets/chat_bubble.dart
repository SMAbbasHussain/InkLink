import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/chat/chat_message_model.dart';
import '../../../../domain/services/board/board_service.dart';
import '../../../canvas/view/canvas_route.dart';
import '../../../workspaces/view/workspace_detail_screen.dart';
import '../../theme/chat_theme.dart';

class AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  final bool isMe;

  const AnimatedMessageBubble({
    super.key,
    required this.child,
    required this.isMe,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isMe ? 0.05 : -0.05, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: widget.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
          child: widget.child,
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool showHeader;
  final String currentUid;
  final Function(String emoji) onReactionToggled;
  final Function(String newText)? onEditRequested;
  final VoidCallback? onDeleteRequested;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showHeader,
    required this.currentUid,
    required this.onReactionToggled,
    this.onEditRequested,
    this.onDeleteRequested,
  });

  BorderRadius _getBubbleRadius(bool isMe) {
    const rL = Radius.circular(18);
    const rS = Radius.circular(4); // signature iMessage corner nip

    if (isMe) {
      return const BorderRadius.only(
        topLeft: rL,
        topRight: rL,
        bottomLeft: rL,
        bottomRight: rS,
      );
    } else {
      return const BorderRadius.only(
        topLeft: rL,
        topRight: rL,
        bottomRight: rL,
        bottomLeft: rS,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);

    return AnimatedMessageBubble(
      isMe: isMe,
      child: Padding(
        padding: EdgeInsets.only(
          top: showHeader ? 8.0 : 2.0,
          bottom: 2.0,
          left: isMe ? 56.0 : 12.0,
          right: isMe ? 12.0 : 56.0,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Header (Avatar + Username + Timestamp for incoming)
            if (showHeader && !isMe) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: colors.surfaceElevated,
                      backgroundImage: message.senderAvatar != null && message.senderAvatar!.isNotEmpty
                          ? NetworkImage(message.senderAvatar!)
                          : null,
                      child: message.senderAvatar == null || message.senderAvatar!.isEmpty
                          ? Text(
                              message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                              style: TextStyle(fontSize: 10, color: colors.textPrimary, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      message.senderName,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        color: colors.textSecondary.withOpacity(0.8),
                        fontSize: 10,
                      ),
                    ),
                    if (message.isEdited && !message.isDeleted) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(edited)',
                        style: TextStyle(color: colors.textSecondary.withOpacity(0.8), fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Main Bubble with Long Press Context Menu
            GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showContextMenu(context, colors);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76,
                    ),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF6200EE), Color(0xFF7C4DFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe ? null : colors.incomingBubble,
                      borderRadius: _getBubbleRadius(isMe),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(colors.isDark ? 0.2 : 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    padding: _getPaddingForType(message.type),
                    child: _buildBubbleContent(context, colors),
                  ),

                  // Floating iMessage Reaction Pill on Corner
                  if (message.reactions.isNotEmpty)
                    Positioned(
                      top: -10,
                      right: isMe ? -4 : null,
                      left: isMe ? null : -4,
                      child: _buildFloatingReactions(colors),
                    ),
                ],
              ),
            ),

            // Status Indicator row (Timestamp + delivery checks for sent messages)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: colors.textSecondary.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    if (message.status == ChatMessageStatus.sending)
                      SizedBox(
                        width: 9,
                        height: 9,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.2,
                          color: colors.textSecondary,
                        ),
                      )
                    else if (message.status == ChatMessageStatus.read)
                      const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF00B0FF))
                    else
                      Icon(Icons.done_all_rounded, size: 13, color: colors.textSecondary.withOpacity(0.8)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  EdgeInsets _getPaddingForType(ChatMessageType type) {
    if (type == ChatMessageType.image || type == ChatMessageType.gif) {
      return EdgeInsets.zero;
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  Widget _buildBubbleContent(BuildContext context, ChatColors colors) {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 14, color: isMe ? Colors.white70 : colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: isMe ? Colors.white70 : colors.textSecondary,
            ),
          ),
        ],
      );
    }

    switch (message.type) {
      case ChatMessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: isMe ? Colors.white : colors.incomingText,
          ),
        );

      case ChatMessageType.image:
        return _buildImageWidget(context);

      case ChatMessageType.gif:
        return _buildGifWidget(context);

      case ChatMessageType.file:
        return _buildFileWidget(colors);

      case ChatMessageType.boardShare:
        return _buildBoardShareCard(context, colors);

      case ChatMessageType.workspaceShare:
        return _buildWorkspaceShareCard(context, colors);
    }
  }

  Widget _buildImageWidget(BuildContext context) {
    final isLocal = !message.content.startsWith('http');
    final ImageProvider imageProvider = isLocal
        ? FileImage(File(message.content)) as ImageProvider
        : NetworkImage(message.content);

    return GestureDetector(
      onTap: () => _openFullScreenImage(context, imageProvider),
      child: ClipRRect(
        borderRadius: _getBubbleRadius(isMe),
        child: isLocal
            ? Image.file(
                File(message.content),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildFallbackMedia('Image unavailable'),
              )
            : Image.network(
                message.content,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildFallbackMedia('Image unavailable'),
              ),
      ),
    );
  }

  Widget _buildGifWidget(BuildContext context) {
    return ClipRRect(
      borderRadius: _getBubbleRadius(isMe),
      child: Image.network(
        message.content,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackMedia('GIF failed to load'),
      ),
    );
  }

  Widget _buildFileWidget(ChatColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : colors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.insert_drive_file_rounded,
            color: isMe ? Colors.white : colors.accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.fileName ?? 'Attachment',
                style: TextStyle(
                  color: isMe ? Colors.white : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (message.fileSize != null)
                Text(
                  _formatFileSize(message.fileSize!),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoardShareCard(BuildContext context, ChatColors colors) {
    final payload = message.sharePayload;
    if (payload == null) {
      return Text('Shared Board', style: TextStyle(color: isMe ? Colors.white : colors.textPrimary));
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.palette_rounded, color: Colors.amber, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payload.title,
                  style: TextStyle(
                    color: isMe ? Colors.white : colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (payload.joinCode.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Join Code: ${payload.joinCode}',
                style: TextStyle(
                  color: isMe ? Colors.white70 : colors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isMe ? Colors.white : colors.accent,
                foregroundColor: isMe ? const Color(0xFF6200EE) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Open Board', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  buildCanvasRoute(
                    context,
                    boardId: payload.targetId,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceShareCard(BuildContext context, ChatColors colors) {
    final payload = message.sharePayload;
    if (payload == null) {
      return Text('Shared Workspace', style: TextStyle(color: isMe ? Colors.white : colors.textPrimary));
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.workspaces_rounded, color: Colors.teal, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payload.title,
                  style: TextStyle(
                    color: isMe ? Colors.white : colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (payload.memberCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${payload.memberCount} members',
              style: TextStyle(color: isMe ? Colors.white70 : colors.textSecondary, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isMe ? Colors.white : colors.accent,
                foregroundColor: isMe ? const Color(0xFF6200EE) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.workspaces_rounded, size: 14),
              label: const Text('Open Workspace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () {
                final boardService = context.read<BoardService>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkspaceDetailScreen(
                      workspaceId: payload.targetId,
                      ownedBoardsStream: boardService.getOwnedBoards(),
                      joinedBoardsStream: boardService.getJoinedBoards(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingReactions(ChatColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: message.reactions.entries.take(3).map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final hasReacted = users.contains(currentUid);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onReactionToggled(emoji);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      '${users.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasReacted ? colors.accent : colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showContextMenu(BuildContext context, ChatColors colors) {
    final emojis = ['❤️', '👍', '😂', '🔥', '🎉', '😮', '😢', '👏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick emoji reaction bar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.inputFill,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: emojis.map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(bottomContext);
                          onReactionToggled(emoji);
                        },
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // Copy Text
                if (message.type == ChatMessageType.text)
                  ListTile(
                    leading: Icon(Icons.copy_rounded, color: colors.textPrimary, size: 20),
                    title: Text('Copy Message', style: TextStyle(color: colors.textPrimary, fontSize: 15)),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Clipboard.setData(ClipboardData(text: message.content));
                      Navigator.pop(bottomContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message copied to clipboard')),
                      );
                    },
                  ),

                // Edit Message (Author only & text only)
                if (isMe && message.type == ChatMessageType.text && !message.isDeleted)
                  ListTile(
                    leading: Icon(Icons.edit_rounded, color: colors.textPrimary, size: 20),
                    title: Text('Edit Message', style: TextStyle(color: colors.textPrimary, fontSize: 15)),
                    onTap: () {
                      Navigator.pop(bottomContext);
                      _showEditDialog(context, colors);
                    },
                  ),

                // Delete Message (Author only)
                if (isMe && !message.isDeleted)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(bottomContext);
                      onDeleteRequested?.call();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, ChatColors colors) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Edit Message', style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter new message...',
            hintStyle: TextStyle(color: colors.textSecondary),
            filled: true,
            fillColor: colors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && onEditRequested != null) {
                onEditRequested!(newText);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image(image: imageProvider),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackMedia(String label) {
    return Container(
      width: 200,
      height: 120,
      color: Colors.grey.withOpacity(0.2),
      child: Center(
        child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
