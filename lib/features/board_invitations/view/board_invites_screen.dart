import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_colors.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/sticky_note.dart';
import '../../../features/canvas/view/canvas_route.dart';
import '../../../core/utils/app_snackbar.dart';
import '../bloc/board_invitations_bloc.dart';

class BoardInvitesScreen extends StatefulWidget {
  final Route<void> Function(BuildContext context, String boardId)?
  canvasRouteBuilder;

  const BoardInvitesScreen({super.key, this.canvasRouteBuilder});

  @override
  State<BoardInvitesScreen> createState() => _BoardInvitesScreenState();
}

class _BoardInvitesScreenState extends State<BoardInvitesScreen> {
  bool _loadRequested = false;
  final Set<String> _localProcessingInviteIds = <String>{};

  @override
  void initState() {
    super.initState();
    _requestLoad();
  }

  void _requestLoad() {
    if (!_loadRequested) {
      _loadRequested = true;
      context.read<BoardInvitationsBloc>().add(
        const BoardInvitationsLoadRequested(),
      );
    }
  }

  void _handleDecision({
    required String inviteId,
    String? boardId,
    required bool accept,
  }) {
    if (inviteId.isEmpty || _localProcessingInviteIds.contains(inviteId)) {
      return;
    }
    if (accept && (boardId == null || boardId.isEmpty)) return;
    final boardInvitesBloc = context.read<BoardInvitationsBloc>();
    final state = boardInvitesBloc.state;
    if (state is BoardInvitationsLoaded &&
        state.processingInviteIds.contains(inviteId)) {
      return;
    }

    setState(() {
      _localProcessingInviteIds.add(inviteId);
    });

    void onCompleted(bool _, String? _) {
      if (!mounted) return;
      setState(() {
        _localProcessingInviteIds.remove(inviteId);
      });
    }

    context.read<BoardInvitationsBloc>().add(
      accept
          ? BoardInvitationAcceptRequested(
              inviteId,
              boardId: boardId,
              onCompleted: onCompleted,
            )
          : BoardInvitationDeclineRequested(
              inviteId,
              onCompleted: onCompleted,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoardInvitationsBloc, BoardInvitationsState>(
      listenWhen: (prev, curr) {
        if (curr is! BoardInvitationsLoaded || curr.message == null) {
          return false;
        }
        if (prev is! BoardInvitationsLoaded) return true;
        return prev.message != curr.message ||
            prev.openedBoardId != curr.openedBoardId;
      },
      listener: (context, state) {
        if (state is BoardInvitationsLoaded && state.message != null) {
          if (state.isError) {
            AppSnackBar.showError(context, state.message!);
          } else {
            AppSnackBar.showSuccess(context, state.message!);
          }

          if (state.openedBoardId != null && !state.isError) {
            final boardId = state.openedBoardId!;
            Navigator.push(
              context,
              widget.canvasRouteBuilder?.call(context, boardId) ??
                  buildCanvasRoute(
                    context,
                    boardId: boardId,
                    showTrayTipsOnEntry: true,
                  ),
            );
          }
        }
      },
      builder: (context, state) {
        final tokens = context.ink;

        if (state is BoardInvitationsInitial ||
            state is BoardInvitationsLoading) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: tokens.accent)),
          );
        }

        if (state is BoardInvitationsError) {
          return Scaffold(
            backgroundColor: tokens.paper,
            appBar: AppBar(
              backgroundColor: tokens.paper,
              title: Text('Board Invites', style: InkType.title(tokens.ink)),
            ),
            body: Center(child: Text(state.message, style: InkType.body(tokens.inkMuted))),
          );
        }

        final loaded = state as BoardInvitationsLoaded;
        return Scaffold(
          backgroundColor: tokens.paper,
          appBar: AppBar(
            backgroundColor: tokens.paper,
            title: Text('Board Invites', style: InkType.title(tokens.ink)),
          ),
          body: Column(
            children: [
              if (loaded.isOffline)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    InkSpacing.s16,
                    InkSpacing.s12,
                    InkSpacing.s16,
                    0,
                  ),
                  child: GlassPanel(
                    radius: InkRadii.glassBar,
                    padding: const EdgeInsets.symmetric(
                      horizontal: InkSpacing.s16,
                      vertical: InkSpacing.s12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.wifiOff, size: 16, color: tokens.pending),
                        const SizedBox(width: InkSpacing.s8),
                        Text(
                          'Offline mode: showing cached board invites.',
                          style: InkType.bodyStrong(tokens.pending),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: loaded.invites.isEmpty
                    ? const EmptyState(
                        icon: LucideIcons.mail,
                        text: 'No pending invites.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(InkSpacing.s16),
                        itemCount: loaded.invites.length,
                        separatorBuilder: (_, _) => const SizedBox(height: InkSpacing.s20),
                        itemBuilder: (context, index) {
                          final invite = loaded.invites[index];
                          final inviteId = invite['id']?.toString() ?? '';
                          final boardId = invite['boardId']?.toString() ?? '';
                          final boardTitle =
                              invite['boardTitle']?.toString() ??
                              'Untitled Board';
                          final senderName =
                              invite['senderName']?.toString() ??
                              'InkLink User';
                          final senderPic = invite['senderPic']?.toString();
                          final expiresAt = invite['expiresAt'];
                          final isProcessing =
                              loaded.processingInviteIds.contains(inviteId) ||
                              _localProcessingInviteIds.contains(inviteId);

                          final angleDeg = index.isEven ? 3.0 : -3.0;

                          return Transform.rotate(
                            angle: angleDeg * 3.1415926535 / 180,
                            child: StickyNote(
                              color: InkColors.stickyButter,
                              showTape: true,
                              padding: const EdgeInsets.all(InkSpacing.s16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      InkAvatar(
                                        imageUrl: senderPic,
                                        initials: inkInitialsFor(senderName),
                                        id: inviteId,
                                        size: 44,
                                      ),
                                      const SizedBox(width: InkSpacing.s12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              senderName,
                                              style: InkType.bodyStrong(
                                                InkColors.stickyInkFor(InkColors.stickyButter),
                                              ),
                                            ),
                                            Text(
                                              'invited you to "$boardTitle"',
                                              style: InkType.cardTitle(
                                                InkColors.stickyInkFor(InkColors.stickyButter),
                                              ),
                                            ),
                                            if (expiresAt != null) ...[
                                              const SizedBox(height: InkSpacing.s4),
                                              Text(
                                                'Invite has an expiration window',
                                                style: InkType.caption(
                                                  InkColors.stickyInkFor(InkColors.stickyButter),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: InkSpacing.s16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkButton.secondary(
                                          label: 'Decline',
                                          onPressed:
                                              inviteId.isEmpty || isProcessing
                                              ? null
                                              : () => _handleDecision(
                                                  inviteId: inviteId,
                                                  accept: false,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: InkSpacing.s12),
                                      Expanded(
                                        child: InkButton.primary(
                                          label: 'Accept',
                                          isLoading: isProcessing,
                                          onPressed:
                                              inviteId.isEmpty ||
                                                  boardId.isEmpty ||
                                                  isProcessing
                                              ? null
                                              : () => _handleDecision(
                                                  inviteId: inviteId,
                                                  boardId: boardId,
                                                  accept: true,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
