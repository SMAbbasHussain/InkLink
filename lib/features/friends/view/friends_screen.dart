import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inklink/features/friends/view/widgets/friend_request_banner.dart';
import 'package:inklink/features/friends/view/widgets/friend_presence_avatar.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../../ui/widgets/status_chip.dart';
import '../bloc/friends_bloc.dart';
import '../../profile/view/profile_route.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start listening to Firestore streams
    context.read<FriendsBloc>().add(LoadFriendsInfo());
  }

  @override
  void dispose() {
    // FIX: Properly cleaning up listeners
    _searchController.dispose();
    _globalSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return BlocListener<FriendsBloc, FriendsState>(
      listener: (context, state) {
        if (state is FriendsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.ban, size: 16, color: tokens.danger),
                  const SizedBox(width: InkSpacing.s8),
                  Flexible(child: Text(state.message)),
                ],
              ),
            ),
          );
        }
      },
      child: Scaffold(
        body: DeskBackground(
          child: SafeArea(
            child: BlocBuilder<FriendsBloc, FriendsState>(
              builder: (context, state) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          InkSpacing.s16,
                          InkSpacing.s12,
                          InkSpacing.s16,
                          0,
                        ),
                        child: Row(
                          children: [
                            Text('Friends', style: InkType.headline(tokens.ink)),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Add collaborator',
                              icon: Icon(LucideIcons.userPlus, color: tokens.ink),
                              onPressed: () => _showAddFriendDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(InkSpacing.s16),
                        child: _buildSearchBar(),
                      ),
                    ),
                    if (state is FriendsLoaded && state.isOffline)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
                          child: GlassPanel(
                            radius: InkRadii.glassBar,
                            padding: const EdgeInsets.symmetric(
                              horizontal: InkSpacing.s16,
                              vertical: InkSpacing.s12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.wifiOff, size: 16, color: tokens.inkSecondary),
                                const SizedBox(width: InkSpacing.s8),
                                Text(
                                  'You are offline.',
                                  style: InkType.bodyStrong(tokens.inkSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // 2. Incoming Requests Banner
                    if (state is FriendsLoaded && state.incomingRequests.isNotEmpty)
                      SliverToBoxAdapter(
                        child: FriendRequestBanner(
                          count: state.incomingRequests.length,
                        ),
                      ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: InkSpacing.s16,
                          vertical: InkSpacing.s12,
                        ),
                        child: Text(
                          _searchController.text.isNotEmpty
                              ? "Search Results"
                              : "Collaborators",
                          style: InkType.label(tokens.inkMuted),
                        ),
                      ),
                    ),

                    _buildFriendsList(state),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList(FriendsState state) {
    final tokens = context.ink;

    if (state is FriendsLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CircularProgressIndicator(color: tokens.accent),
          ),
        ),
      );
    }

    if (state is FriendsLoaded) {
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      final filteredList = state.friends.where((f) {
        if (myUid != null && f['uid'] == myUid) return false;
        final name = f['displayName']?.toString().toLowerCase() ?? "";
        return name.contains(_searchController.text.toLowerCase());
      }).toList();

      if (filteredList.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: const EmptyState(
            icon: LucideIcons.users,
            text: 'No collaborators found',
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
        sliver: SliverToBoxAdapter(
          child: PaperCard(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Column(
              children: [
                for (var i = 0; i < filteredList.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: tokens.glassStroke),
                  _buildFriendRow(filteredList[i]),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverFillRemaining(
      hasScrollBody: false,
      child: const EmptyState(icon: LucideIcons.users, text: 'No collaborators found'),
    );
  }

  Widget _buildFriendRow(Map<String, dynamic> friendData) {
    final tokens = context.ink;
    final name = friendData['displayName'] ?? "User";
    final photoUrl = friendData['photoURL'];
    final userId = friendData['uid'] ?? '';

    return InkWell(
      onTap: () =>
          Navigator.push(context, buildProfileRoute(context, userId: userId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
        child: Row(
          children: [
            FriendPresenceAvatar(
              userId: userId,
              displayName: name,
              photoUrl: photoUrl,
            ),
            const SizedBox(width: InkSpacing.s16),
            Expanded(
              child: Text(name, style: InkType.bodyStrong(tokens.ink)),
            ),
            Icon(LucideIcons.messageCircle, color: tokens.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return InkTextField(
      controller: _searchController,
      hintText: "Search your friends...",
      leadingIcon: LucideIcons.search,
      onChanged: (value) => setState(() {}),
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              tooltip: 'Clear search',
              icon: Icon(LucideIcons.x, size: 18, color: context.ink.inkMuted),
              onPressed: () => setState(() => _searchController.clear()),
            )
          : null,
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final tokens = context.ink;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpacing.s16,
          InkSpacing.s8,
          InkSpacing.s16,
          InkSpacing.s24,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: GlassPanel(
            radius: InkRadii.bottomSheet,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24, vertical: InkSpacing.s20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: InkSpacing.s20),
                  decoration: BoxDecoration(
                    color: tokens.inkMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Text("Add Collaborator", style: InkType.headline(tokens.ink).copyWith(fontSize: 22)),
                const SizedBox(height: InkSpacing.s8),
                Text(
                  "Search for your teammates by their exact email",
                  textAlign: TextAlign.center,
                  style: InkType.body(tokens.inkMuted),
                ),
                const SizedBox(height: InkSpacing.s24),
                InkTextField(
                  controller: _globalSearchController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.search,
                  hintText: "example@email.com",
                  leadingIcon: LucideIcons.mail,
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    icon: Icon(LucideIcons.search, color: tokens.inkMuted),
                    onPressed: () {
                      if (_globalSearchController.text.isNotEmpty) {
                        context.read<FriendsBloc>().add(
                          SearchUserByEmailRequested(
                            _globalSearchController.text.trim(),
                          ),
                        );
                      }
                    },
                  ),
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      context.read<FriendsBloc>().add(
                        SearchUserByEmailRequested(val.trim()),
                      );
                    }
                  },
                ),
                const SizedBox(height: InkSpacing.s32 - 2),
                Expanded(
                  child: BlocBuilder<FriendsBloc, FriendsState>(
                    builder: (context, state) {
                      if (state is EmailSearchInProgress) {
                        return Center(child: CircularProgressIndicator(color: tokens.accent));
                      }

                      if (state is EmailSearchEmpty) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.search, size: 60, color: tokens.inkMuted),
                            const SizedBox(height: InkSpacing.s16),
                            Text(
                              "No user found with this email.",
                              style: InkType.body(tokens.inkMuted),
                            ),
                          ],
                        );
                      }

                      if (state is EmailSearchResultsLoaded) {
                        if (state.isOffline) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.wifiOff, size: 52, color: tokens.inkMuted),
                              const SizedBox(height: InkSpacing.s12),
                              Text('Offline mode', style: InkType.bodyStrong(tokens.ink)),
                              const SizedBox(height: InkSpacing.s4),
                              Text(
                                'Search requires internet. Cached friends and requests are still available.',
                                textAlign: TextAlign.center,
                                style: InkType.caption(tokens.inkMuted),
                              ),
                              const SizedBox(height: InkSpacing.s24),
                            ],
                          );
                        }

                        final user = state.result;
                        final String name = user['displayName'] ?? "Creator";
                        final String? photoUrl = user['photoURL'];
                        final isAlreadyFriend = state.friendUids.contains(user['uid']);
                        final isPending = state.pendingOutgoingUids.contains(user['uid']);
                        final isSending = state.sendingRequestTargetUids.contains(user['uid']);

                        return PaperCard(
                          padding: const EdgeInsets.all(InkSpacing.s16),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                buildProfileRoute(context, userId: user['uid']),
                              );
                            },
                            child: Row(
                              children: [
                                InkAvatar(
                                  imageUrl: photoUrl,
                                  initials: inkInitialsFor(name),
                                  id: user['uid']?.toString() ?? '',
                                  size: 55,
                                ),
                                const SizedBox(width: InkSpacing.s16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: InkType.bodyStrong(tokens.ink)),
                                      Text(
                                        user['email'] ?? "",
                                        style: InkType.caption(tokens.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                isPending
                                    ? const StatusChip(status: InkStatus.pending)
                                    : InkButton.primary(
                                        label: isSending
                                            ? ''
                                            : (isAlreadyFriend ? "Message" : "Add"),
                                        compact: true,
                                        expand: false,
                                        icon: isSending
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : null,
                                        onPressed: (isAlreadyFriend || isSending)
                                            ? null
                                            : () {
                                                context.read<FriendsBloc>().add(
                                                  SendFriendRequestRequested(user['uid']),
                                                );
                                              },
                                      ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (state is SearchResultsLoaded) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.userPlus, size: 80, color: tokens.inkMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: InkSpacing.s16),
                          Text(
                            "Ready to build together?",
                            style: InkType.bodyStrong(tokens.inkMuted),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
