import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../domain/models/board_edit_request.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_segmented.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../notifications/bloc/notifications_bloc.dart';

/// Dedicated screen for board owners to view, filter by username, and resolve
/// edit access requests.
class BoardEditRequestsScreen extends StatefulWidget {
  final String boardId;
  final String? boardTitle;

  const BoardEditRequestsScreen({
    super.key,
    required this.boardId,
    this.boardTitle,
  });

  @override
  State<BoardEditRequestsScreen> createState() =>
      _BoardEditRequestsScreenState();
}

class _BoardEditRequestsScreenState extends State<BoardEditRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTabIndex = 0; // 0: Pending, 1: History
  final Set<String> _processingIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BoardEditRequest> _getRequests(NotificationsState notifState) {
    final Map<String, BoardEditRequest> requestMap = {};

    if (notifState is NotificationsLoaded) {
      for (final raw in notifState.notifications) {
        final type = raw['type']?.toString();
        final extraData = raw['extraData'] is Map
            ? (raw['extraData'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final bId =
            extraData['boardId']?.toString() ?? raw['targetId']?.toString();
        final reqType = extraData['requestType']?.toString() ??
            (type == 'board_edit_request' ? 'edit' : 'join');

        if ((type == 'board_edit_request' ||
                (type == 'board_access_request' && reqType == 'edit')) &&
            bId == widget.boardId) {
          final req = BoardEditRequest.fromNotificationMap(
            raw,
            fallbackBoardId: widget.boardId,
          );
          if (req.id.isNotEmpty) {
            requestMap[req.id] = req;
          }
        }
      }
    }

    final list = requestMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _handleAction({
    required BoardEditRequest request,
    required String action, // 'accept' or 'decline'
  }) async {
    final requesterName = request.requesterName;
    final notificationId = request.id;

    if (action == 'decline') {
      final confirmed = await showInkConfirmDialog(
        context,
        title: 'Decline Edit Request?',
        message:
            'Decline edit permissions for $requesterName? They will remain a viewer.',
        confirmLabel: 'Decline',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _processingIds.add(notificationId);
    });

    try {
      if (notificationId.isNotEmpty) {
        context.read<NotificationsBloc>().add(
              NotificationMarkReadRequested(notificationId),
            );
        context.read<NotificationsBloc>().add(
              NotificationRespondToAccessRequest(
                notificationId: notificationId,
                boardId: widget.boardId,
                requesterUid: request.requesterUid,
                action: action,
                requestType: 'edit',
              ),
            );
      }

      if (action == 'accept') {
        AppSnackBar.showSuccess(
          context,
          'Edit access granted to $requesterName.',
        );
      } else {
        AppSnackBar.showMessage(
          context,
          'Edit request from $requesterName declined.',
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(notificationId);
        });
      }
    }
  }

  String _formatTimeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 365) return "${(diff.inDays / 365).floor()}y ago";
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()}mo ago";
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Edit Requests', style: InkType.title(tokens.ink)),
            if (widget.boardTitle != null && widget.boardTitle!.isNotEmpty)
              Text(
                widget.boardTitle!,
                style: InkType.caption(tokens.inkSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, notifState) {
          final allRequests = _getRequests(notifState);
          final pendingRequests =
              allRequests.where((r) => r.isPending).toList();
          final historyRequests =
              allRequests.where((r) => !r.isPending).toList();

          final currentList =
              _selectedTabIndex == 0 ? pendingRequests : historyRequests;

          // Filter by username / query
          final query = _searchQuery.trim().toLowerCase();
          final filteredList = currentList.where((req) {
            if (query.isEmpty) return true;
            return req.requesterName.toLowerCase().contains(query) ||
                req.requesterUid.toLowerCase().contains(query) ||
                req.message.toLowerCase().contains(query);
          }).toList();

          return Column(
            children: [
              // Search & Filter header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  InkSpacing.s16,
                  InkSpacing.s12,
                  InkSpacing.s16,
                  InkSpacing.s8,
                ),
                child: InkTextField(
                  controller: _searchController,
                  hintText: 'Filter requests by username...',
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              // Segmented selector (Pending vs History)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.s16,
                  vertical: InkSpacing.s8,
                ),
                child: InkSegmented(
                  labels: [
                    'Pending (${pendingRequests.length})',
                    'History (${historyRequests.length})',
                  ],
                  selectedIndex: _selectedTabIndex,
                  onChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                ),
              ),

              // Request list or empty state
              Expanded(
                child: filteredList.isEmpty
                    ? _buildEmptyState(
                        tokens: tokens,
                        hasSearch: query.isNotEmpty,
                        isPendingTab: _selectedTabIndex == 0,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          InkSpacing.s16,
                          InkSpacing.s8,
                          InkSpacing.s16,
                          InkSpacing.s24,
                        ),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: InkSpacing.s12),
                        itemBuilder: (context, index) {
                          final request = filteredList[index];
                          return _buildRequestCard(
                            context: context,
                            tokens: tokens,
                            request: request,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required dynamic tokens,
    required bool hasSearch,
    required bool isPendingTab,
  }) {
    if (hasSearch) {
      return Center(
        child: EmptyState(
          icon: LucideIcons.searchX,
          text: 'No requests matching "$_searchQuery"',
          subtitle: 'Check the spelling or try searching for another username.',
        ),
      );
    }

    if (isPendingTab) {
      return const Center(
        child: EmptyState(
          icon: LucideIcons.userCheck,
          text: 'No pending edit requests',
          subtitle:
              'When viewers request edit permissions for this board, they will show up here.',
        ),
      );
    }

    return const Center(
      child: EmptyState(
        icon: LucideIcons.history,
        text: 'No request history',
        subtitle: 'Past approved or declined edit requests will appear here.',
      ),
    );
  }

  Widget _buildRequestCard({
    required BuildContext context,
    required dynamic tokens,
    required BoardEditRequest request,
  }) {
    final isProcessing = _processingIds.contains(request.id);
    final timeLabel = _formatTimeAgo(request.createdAt);

    return PaperCard(
      padding: const EdgeInsets.all(InkSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkAvatar(
                id: request.requesterUid.isNotEmpty
                    ? request.requesterUid
                    : request.id,
                initials: inkInitialsFor(request.requesterName),
                imageUrl: request.requesterPhotoUrl,
                size: 40,
              ),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName,
                      style: InkType.bodyStrong(tokens.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Requested $timeLabel',
                      style: InkType.caption(tokens.inkSecondary),
                    ),
                  ],
                ),
              ),
              _buildStatusPill(tokens, request.status),
            ],
          ),

          // Requester message if provided
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: InkSpacing.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(InkSpacing.s8),
              decoration: BoxDecoration(
                color: tokens.isDark
                    ? const Color(0x1FFFFFFF)
                    : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.glassStroke),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.messageSquare,
                    size: 14,
                    color: tokens.inkMuted,
                  ),
                  const SizedBox(width: InkSpacing.s8),
                  Expanded(
                    child: Text(
                      request.message,
                      style: InkType.body(tokens.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action buttons if pending
          if (request.isPending) ...[
            const SizedBox(height: InkSpacing.s16),
            Divider(height: 1, color: tokens.glassStroke),
            const SizedBox(height: InkSpacing.s12),
            if (isProcessing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.accent,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: InkButton.secondary(
                      label: 'Decline',
                      icon: const Icon(LucideIcons.x, size: 16),
                      compact: true,
                      onPressed: () => _handleAction(
                        request: request,
                        action: 'decline',
                      ),
                    ),
                  ),
                  const SizedBox(width: InkSpacing.s12),
                  Expanded(
                    child: InkButton.primary(
                      label: 'Grant Edit Access',
                      icon: const Icon(LucideIcons.check, size: 16),
                      compact: true,
                      onPressed: () => _handleAction(
                        request: request,
                        action: 'accept',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(dynamic tokens, String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'accepted':
        bg = tokens.success.withValues(alpha: 0.14);
        fg = tokens.success;
        label = 'Approved';
        icon = LucideIcons.check;
        break;
      case 'declined':
        bg = tokens.danger.withValues(alpha: 0.14);
        fg = tokens.danger;
        label = 'Declined';
        icon = LucideIcons.x;
        break;
      case 'pending':
      default:
        bg = tokens.accent.withValues(alpha: 0.14);
        fg = tokens.accent;
        label = 'Pending';
        icon = LucideIcons.clock;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

