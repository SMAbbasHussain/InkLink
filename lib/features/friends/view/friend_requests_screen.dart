import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_segmented.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../profile/view/profile_route.dart';
import '../bloc/friends_bloc.dart';
import './widgets/request_card.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Text('Pending Requests', style: InkType.title(tokens.ink)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(InkSpacing.s16),
            child: InkSegmented(
              labels: const ['Incoming', 'Outgoing'],
              selectedIndex: _tabController.index,
              onChanged: (i) => _tabController.animateTo(i),
            ),
          ),
          Expanded(
            child: BlocBuilder<FriendsBloc, FriendsState>(
              builder: (context, state) {
                if (state is! FriendsLoaded) {
                  return const SizedBox.shrink();
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIncomingTab(context, state),
                    _buildOutgoingTab(context, state),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTab(BuildContext context, FriendsLoaded state) {
    final incoming = state.incomingRequests;
    if (incoming.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.mailCheck,
        text: 'All caught up!',
        subtitle: 'No incoming requests.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s16),
      children: [
        if (state.isOffline) _buildOfflineBanner(context),
        ...incoming.map((req) {
          final requestId = req['id']?.toString() ?? '';
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              buildProfileRoute(context, userId: req['fromUid']),
            ),
            child: RequestCard(
              request: req,
              isAccepting: state.acceptingRequestIds.contains(requestId),
              isDeclining: state.decliningRequestIds.contains(requestId),
              onAccept: () => context.read<FriendsBloc>().add(
                AcceptFriendRequestRequested(req['id'], req['fromUid']),
              ),
              onDecline: () => context.read<FriendsBloc>().add(
                DeclineFriendRequestRequested(req['id']),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOutgoingTab(BuildContext context, FriendsLoaded state) {
    final outgoing = state.outgoingRequests;
    if (outgoing.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.clock,
        text: 'Nothing pending',
        subtitle: 'No outgoing requests.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s16),
      children: [
        if (state.isOffline) _buildOfflineBanner(context),
        ...outgoing.map((req) {
          return _buildOutgoingRequestCard(context, req, state);
        }),
      ],
    );
  }

  Widget _buildOutgoingRequestCard(
    BuildContext context,
    Map<String, dynamic> request,
    FriendsLoaded state,
  ) {
    final tokens = context.ink;
    final toUid = request['toUid']?.toString() ?? '';
    final recipientName = request['recipientName']?.toString();
    final recipientPic = request['recipientPic']?.toString();
    final requestId =
        request['requestId']?.toString() ?? request['id']?.toString() ?? '';
    final isCanceling =
        requestId.isNotEmpty && state.cancelingRequestIds.contains(requestId);
    final displayName = recipientName?.isNotEmpty == true
        ? recipientName!
        : (toUid.isNotEmpty ? toUid : 'Unknown user');

    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s12),
      child: PaperCard(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: InkWell(
          onTap: toUid.isEmpty
              ? null
              : () => Navigator.push(
                  context,
                  buildProfileRoute(context, userId: toUid),
                ),
          child: Row(
            children: [
              InkAvatar(
                imageUrl: recipientPic,
                initials: inkInitialsFor(displayName),
                id: toUid,
                size: 48,
              ),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: InkType.bodyStrong(tokens.ink)),
                    Text('Request pending', style: InkType.caption(tokens.inkMuted)),
                  ],
                ),
              ),
              InkButton.secondary(
                label: 'Cancel',
                compact: true,
                expand: false,
                icon: isCanceling
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: tokens.ink),
                      )
                    : null,
                onPressed: toUid.isEmpty || isCanceling
                    ? null
                    : () async {
                        final shouldCancel = await showInkConfirmDialog(
                          context,
                          title: 'Cancel request?',
                          message: 'Cancel the request to $displayName?',
                          confirmLabel: 'Cancel request',
                          cancelLabel: 'Keep',
                        );

                        if (!context.mounted) return;
                        if (!shouldCancel) return;

                        context.read<FriendsBloc>().add(
                          CancelFriendRequestRequested(
                            request['requestId']?.toString() ??
                                request['id']?.toString() ??
                                '',
                            toUid,
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    final tokens = context.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s12),
      child: GlassPanel(
        radius: InkRadii.glassBar,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16, vertical: InkSpacing.s12),
        child: Row(
          children: [
            Icon(LucideIcons.wifiOff, size: 16, color: tokens.pending),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: Text(
                'Offline mode: pending requests are from local cache.',
                style: InkType.bodyStrong(tokens.pending),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
