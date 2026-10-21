import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/auth_service.dart';
import '../../bloc/canvas_bloc.dart';

class CommentsTray extends StatefulWidget {
  const CommentsTray({super.key});

  @override
  State<CommentsTray> createState() => _CommentsTrayState();
}

class _CommentsTrayState extends State<CommentsTray> {
  final TextEditingController _newCommentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  String? _expandedReplyCommentId;

  @override
  void dispose() {
    _newCommentController.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addBoardComment() {
    final text = _newCommentController.text.trim();
    if (text.isEmpty) return;
    context.read<CanvasBloc>().add(
          CanvasAddCommentRequested(text: text),
        );
    _newCommentController.clear();
  }

  void _sendReply(String commentId) {
    final controller = _replyControllers[commentId];
    final text = controller?.text.trim() ?? '';
    if (text.isEmpty) return;
    context.read<CanvasBloc>().add(
          CanvasAddCommentReplyRequested(commentId: commentId, text: text),
        );
    controller?.clear();
    setState(() {
      _expandedReplyCommentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (prev, curr) =>
          prev.isCommentsTrayOpen != curr.isCommentsTrayOpen ||
          prev.comments != curr.comments ||
          prev.isPlacingComment != curr.isPlacingComment ||
          prev.activeCommentId != curr.activeCommentId,
      builder: (context, state) {
        if (!state.isCommentsTrayOpen) {
          return const SizedBox.shrink();
        }

        final currentUserId = state.currentUserId.isNotEmpty
            ? state.currentUserId
            : (context.read<AuthService?>()?.getCurrentUserId() ??
                state.boardMembers
                    .where((m) => m.role == state.currentUserRole)
                    .map((m) => m.uid)
                    .firstOrNull);
        final isOwner = state.currentUserRole == 'owner';

        return Positioned(
          top: 70,
          right: 16,
          bottom: 90,
          width: 350,
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
                          Icons.comment_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Comments',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${state.comments.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            state.isPlacingComment
                                ? Icons.pin_drop
                                : Icons.add_location_alt_outlined,
                            size: 20,
                            color: state.isPlacingComment
                                ? Colors.amber
                                : theme.colorScheme.primary,
                          ),
                          tooltip: state.isPlacingComment
                              ? 'Cancel Pin Mode'
                              : 'Pin Comment on Canvas',
                          splashRadius: 18,
                          onPressed: () {
                            context.read<CanvasBloc>().add(
                                  const CanvasToggleCommentPlacementMode(),
                                );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Close comments',
                          splashRadius: 18,
                          onPressed: () {
                            context
                                .read<CanvasBloc>()
                                .add(const CanvasToggleCommentsTray());
                          },
                        ),
                      ],
                    ),
                  ),

                  // Pin Placement Mode Banner
                  if (state.isPlacingComment)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      color: Colors.amber.withOpacity(0.15),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap anywhere on canvas to drop pin',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.read<CanvasBloc>().add(
                                    const CanvasToggleCommentPlacementMode(
                                      enable: false,
                                    ),
                                  );
                            },
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),

                  // Comments List
                  Expanded(
                    child: state.comments.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.insert_comment_outlined,
                                    size: 40,
                                    color: theme.hintColor.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No comments yet',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.hintColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Drop a pin on canvas or write a board comment below. Use @name to mention collaborators.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            itemCount: state.comments.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final comment = state.comments[index];
                              final isAuthor = comment.authorUid == currentUserId;
                              final canDelete = isAuthor || isOwner;
                              final isSelected =
                                  comment.id == state.activeCommentId;

                              return _CommentThreadCard(
                                comment: comment,
                                isSelected: isSelected,
                                canDelete: canDelete,
                                isReplyExpanded:
                                    _expandedReplyCommentId == comment.id,
                                replyController: _replyControllers.putIfAbsent(
                                  comment.id,
                                  () => TextEditingController(),
                                ),
                                onToggleReply: () {
                                  setState(() {
                                    if (_expandedReplyCommentId == comment.id) {
                                      _expandedReplyCommentId = null;
                                    } else {
                                      _expandedReplyCommentId = comment.id;
                                    }
                                  });
                                },
                                onSendReply: () => _sendReply(comment.id),
                                onDelete: () {
                                  context.read<CanvasBloc>().add(
                                        CanvasDeleteCommentRequested(
                                          comment.id,
                                        ),
                                      );
                                },
                              );
                            },
                          ),
                  ),

                  // Bottom Input Field (Board Comment)
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
                            controller: _newCommentController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _addBoardComment(),
                            decoration: InputDecoration(
                              hintText: 'Add a comment... (use @name)',
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
                            onPressed: _addBoardComment,
                            tooltip: 'Post Comment',
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

class _CommentThreadCard extends StatelessWidget {
  final CanvasComment comment;
  final bool isSelected;
  final bool canDelete;
  final bool isReplyExpanded;
  final TextEditingController replyController;
  final VoidCallback onToggleReply;
  final VoidCallback onSendReply;
  final VoidCallback onDelete;

  const _CommentThreadCard({
    required this.comment,
    required this.isSelected,
    required this.canDelete,
    required this.isReplyExpanded,
    required this.replyController,
    required this.onToggleReply,
    required this.onSendReply,
    required this.onDelete,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }

  Widget _buildFormattedText(String text, ThemeData theme) {
    final words = text.split(' ');
    final spans = <TextSpan>[];

    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.startsWith('@') && w.length > 1) {
        spans.add(
          TextSpan(
            text: '$w ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: '$w '));
      }
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author & Pin header
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                backgroundImage: comment.authorPhotoUrl != null
                    ? NetworkImage(comment.authorPhotoUrl!)
                    : null,
                child: comment.authorPhotoUrl == null
                    ? Text(
                        comment.authorName.isNotEmpty
                            ? comment.authorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatTime(comment.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (comment.canvasPosition != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pin_drop, size: 10, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        '(${comment.canvasPosition!.dx.toInt()}, ${comment.canvasPosition!.dy.toInt()})',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: Colors.redAccent.withOpacity(0.7),
                  tooltip: 'Delete comment',
                  splashRadius: 14,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Comment body with @mention highlighting
          _buildFormattedText(comment.text, theme),
          const SizedBox(height: 6),

          // Actions: Reply button
          Row(
            children: [
              GestureDetector(
                onTap: onToggleReply,
                child: Row(
                  children: [
                    Icon(
                      Icons.reply,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      comment.replies.isNotEmpty
                          ? '${comment.replies.length} replies'
                          : 'Reply',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Threaded Replies
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Column(
                children: comment.replies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.15),
                          backgroundImage: reply.authorPhotoUrl != null
                              ? NetworkImage(reply.authorPhotoUrl!)
                              : null,
                          child: reply.authorPhotoUrl == null
                              ? Text(
                                  reply.authorName.isNotEmpty
                                      ? reply.authorName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      reply.authorName,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatTime(reply.createdAt),
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 9,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                _buildFormattedText(reply.text, theme),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Reply Input (when expanded)
          if (isReplyExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSendReply(),
                      decoration: InputDecoration(
                        hintText: 'Reply... (use @name)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.send, size: 16),
                    color: theme.colorScheme.primary,
                    splashRadius: 16,
                    onPressed: onSendReply,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
