import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:developer' as developer;

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../bloc/workspace_bloc.dart';

class WorkspaceInvitesScreen extends StatefulWidget {
  const WorkspaceInvitesScreen({super.key});

  @override
  State<WorkspaceInvitesScreen> createState() => _WorkspaceInvitesScreenState();
}

class _WorkspaceInvitesScreenState extends State<WorkspaceInvitesScreen> {
  final Set<String> _localProcessingInviteIds = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<WorkspaceBloc>().add(LoadIncomingInvitesRequested());
  }

  void _submitDecision({
    required String inviteId,
    required String workspaceId,
    required String fromUid,
    required bool accept,
  }) {
    if (inviteId.isEmpty || _localProcessingInviteIds.contains(inviteId)) {
      return;
    }
    final workspaceBloc = context.read<WorkspaceBloc>();
    final state = workspaceBloc.state;
    if (state is WorkspaceLoaded &&
        state.processingInviteDecisionIds.contains(inviteId)) {
      return;
    }

    developer.log(
      '${accept ? 'Accept' : 'Reject'} invite tapped | inviteId=$inviteId | workspaceId=$workspaceId | fromUid=$fromUid',
      name: 'WorkspaceInvitesScreen',
    );

    setState(() {
      _localProcessingInviteIds.add(inviteId);
    });

    final notificationsBloc = context.read<NotificationsBloc>();
    void onCompleted(bool success, String? error) {
      if (!mounted) return;
      setState(() {
        _localProcessingInviteIds.remove(inviteId);
      });
      if (!success) {
        AppSnackBar.showError(
          context,
          error ?? 'Failed to ${accept ? 'accept' : 'reject'} invite.',
        );
        return;
      }
      notificationsBloc.add(
        NotificationWorkspaceInviteResolved(
          inviteId: inviteId,
          status: accept ? 'accepted' : 'declined',
        ),
      );
      AppSnackBar.showSuccess(
        context,
        accept ? 'Invite accepted.' : 'Invite rejected.',
      );
    }

    context.read<WorkspaceBloc>().add(
      accept
          ? AcceptWorkspaceInviteRequested(inviteId, onCompleted: onCompleted)
          : RejectWorkspaceInviteRequested(inviteId, onCompleted: onCompleted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Text('Workspace Invitations', style: InkType.title(tokens.ink)),
      ),
      body: SafeArea(
        child: BlocBuilder<WorkspaceBloc, WorkspaceState>(
          builder: (context, state) {
            if (state is! WorkspaceLoaded) {
              return Center(
                child: CircularProgressIndicator(color: tokens.accent),
              );
            }

            final pendingInvites = state.incomingInvites
                .where((i) => i.status == 'pending')
                .toList();

            if (pendingInvites.isEmpty) {
              return const EmptyState(
                icon: LucideIcons.mail,
                text: 'No pending invitations',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(InkSpacing.s16),
              itemCount: pendingInvites.length,
              itemBuilder: (context, index) {
                final invite = pendingInvites[index];
                final isProcessing =
                    state.processingInviteDecisionIds.contains(invite.id) ||
                    _localProcessingInviteIds.contains(invite.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: InkSpacing.s16),
                  child: PaperCard(
                    padding: const EdgeInsets.all(InkSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkAvatar(
                              imageUrl: invite.senderPhotoUrl,
                              initials: inkInitialsFor(invite.senderName),
                              id: invite.fromUid,
                              size: 48,
                            ),
                            const SizedBox(width: InkSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invite.senderName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: InkType.bodyStrong(tokens.ink),
                                  ),
                                  Text(
                                    'invited you to ${invite.workspaceName}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: InkType.caption(tokens.inkMuted),
                                  ),
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
                                label: isProcessing ? '' : 'Reject',
                                icon: isProcessing
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: tokens.ink,
                                        ),
                                      )
                                    : const Icon(LucideIcons.x),
                                onPressed: isProcessing
                                    ? null
                                    : () => _submitDecision(
                                        inviteId: invite.id,
                                        workspaceId: invite.workspaceId,
                                        fromUid: invite.fromUid,
                                        accept: false,
                                      ),
                              ),
                            ),
                            const SizedBox(width: InkSpacing.s8 + 2),
                            Expanded(
                              child: InkButton.primary(
                                label: isProcessing
                                    ? 'Processing...'
                                    : 'Accept',
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(LucideIcons.check),
                                onPressed: isProcessing
                                    ? null
                                    : () => _submitDecision(
                                        inviteId: invite.id,
                                        workspaceId: invite.workspaceId,
                                        fromUid: invite.fromUid,
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
            );
          },
        ),
      ),
    );
  }
}
