import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inklink/features/friends/view/widgets/friend_request_banner.dart';
import 'package:inklink/features/friends/view/widgets/friend_presence_avatar.dart';
import 'package:inklink/features/friends/view/widgets/add_friend_sheet.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
import '../bloc/friends_bloc.dart';
import '../../profile/view/profile_route.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();

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
      final myUid = context.select<AuthBloc, String?>(
        (b) => b.state is Authenticated ? (b.state as Authenticated).uid : null,
      );
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
    AddFriendSheet.show(context);
  }
}
