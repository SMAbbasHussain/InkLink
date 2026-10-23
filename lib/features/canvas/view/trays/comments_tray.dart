import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_initials.dart';
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
    final tokens = context.ink;

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

        final topInset = MediaQuery.of(context).padding.top + 64;

        return Positioned(
          top: topInset,
          right: 16,
          bottom: 96,
          width: 350,
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
                        LucideIcons.messageSquareQuote,
                        size: 18,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: InkSpacing.s8),
                      Text(
                        'Comments',
                        style: InkType.subhead(tokens.ink),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.comments.length}',
                          style: InkType.caption(tokens.accent).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          state.isPlacingComment
                              ? LucideIcons.mapPin
                              : LucideIcons.mapPinPlus,
                          size: 18,
                          color: state.isPlacingComment
                              ? tokens.pending
                              : tokens.accent,
                        ),
                        tooltip: state.isPlacingComment
                            ? 'Cancel Pin Mode'
                            : 'Pin Comment on Canvas',
                        onPressed: () {
                          context.read<CanvasBloc>().add(
                                const CanvasToggleCommentPlacementMode(),
                              );
                        },
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, size: 18, color: tokens.inkMuted),
                        tooltip: 'Close comments',
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
                      horizontal: InkSpacing.s12,
                      vertical: InkSpacing.s8,
                    ),
                    color: tokens.pending.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        Icon(LucideIcons.hand, size: 16, color: tokens.pending),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap anywhere on canvas to drop pin',
                            style: InkType.caption(tokens.pending).copyWith(
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
                          child: Icon(LucideIcons.x, size: 16, color: tokens.pending),
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
                                  LucideIcons.messageSquareCode,
                                  size: 40,
                                  color: tokens.inkMuted.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No comments yet',
                                  style: InkType.bodyStrong(tokens.ink),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Drop a pin on canvas or write a board comment below. Use @name to mention collaborators.',
                                  textAlign: TextAlign.center,
                                  style: InkType.caption(tokens.inkMuted),
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
                              Divider(height: 16, color: tokens.glassStroke),
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
                              tokens: tokens,
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
                        color: tokens.glassStroke,
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
                          style: InkType.body(tokens.ink),
                          decoration: InputDecoration(
                            hintText: 'Add a comment... (use @name)',
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
                          onTap: _addBoardComment,
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

class _CommentThreadCard extends StatelessWidget {
  final CanvasComment comment;
  final bool isSelected;
  final bool canDelete;
  final bool isReplyExpanded;
  final TextEditingController replyController;
  final InkTokens tokens;
  final VoidCallback onToggleReply;
  final VoidCallback onSendReply;
  final VoidCallback onDelete;

  const _CommentThreadCard({
    required this.comment,
    required this.isSelected,
    required this.canDelete,
    required this.isReplyExpanded,
    required this.replyController,
    required this.tokens,
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

  Widget _buildFormattedText(String text) {
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
              color: tokens.accent,
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
        style: InkType.body(tokens.ink),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? tokens.accent.withValues(alpha: 0.08)
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
              InkAvatar(
                imageUrl: comment.authorPhotoUrl,
                initials: inkInitialsFor(comment.authorName),
                id: comment.authorUid,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: InkType.bodyStrong(tokens.ink),
                    ),
                    Text(
                      _formatTime(comment.createdAt),
                      style: InkType.caption(tokens.inkMuted).copyWith(fontSize: 10),
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
                    color: tokens.pending.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.mapPin, size: 10, color: tokens.pending),
                      const SizedBox(width: 2),
                      Text(
                        '(${comment.canvasPosition!.dx.toInt()}, ${comment.canvasPosition!.dy.toInt()})',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: tokens.pending,
                        ),
                      ),
                    ],
                  ),
                ),
              if (canDelete)
                IconButton(
                  icon: Icon(LucideIcons.trash2, size: 16, color: tokens.danger.withValues(alpha: 0.8)),
                  tooltip: 'Delete comment',
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Comment body with @mention highlighting
          _buildFormattedText(comment.text),
          const SizedBox(height: 6),

          // Actions: Reply button
          Row(
            children: [
              GestureDetector(
                onTap: onToggleReply,
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.reply,
                      size: 14,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      comment.replies.isNotEmpty
                          ? '${comment.replies.length} replies'
                          : 'Reply',
                      style: InkType.caption(tokens.accent).copyWith(
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
                        InkAvatar(
                          imageUrl: reply.authorPhotoUrl,
                          initials: inkInitialsFor(reply.authorName),
                          id: reply.authorUid,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.paper,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tokens.glassStroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      reply.authorName,
                                      style: InkType.caption(tokens.ink).copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatTime(reply.createdAt),
                                      style: InkType.caption(tokens.inkMuted).copyWith(
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                _buildFormattedText(reply.text),
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
                      style: InkType.body(tokens.ink),
                      decoration: InputDecoration(
                        hintText: 'Reply... (use @name)',
                        hintStyle: InkType.body(tokens.inkMuted),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        filled: true,
                        fillColor: tokens.field,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(LucideIcons.send, size: 16, color: tokens.accent),
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
