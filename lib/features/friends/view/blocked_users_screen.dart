import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/paper_card.dart';
import '../bloc/friends_bloc.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FriendsBloc>().add(LoadBlockedUsers());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Text('Blocked Users', style: InkType.title(tokens.ink)),
      ),
      body: BlocBuilder<FriendsBloc, FriendsState>(
        builder: (context, state) {
          final blockedUsers = state is FriendsLoaded
              ? state.blockedUsers
              : const <Map<String, dynamic>>[];

          if (state is FriendsInitial || state is FriendsLoading) {
            return Center(child: CircularProgressIndicator(color: tokens.accent));
          }

          if (blockedUsers.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.ban,
              text: 'No blocked users',
              subtitle: 'People you block will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(InkSpacing.s16),
            itemCount: blockedUsers.length,
            separatorBuilder: (_, _) => const SizedBox(height: InkSpacing.s12),
            itemBuilder: (context, index) {
              final user = blockedUsers[index];
              final blockedUid = user['blockedUid']?.toString() ?? '';
              final displayName =
                  user['displayName']?.toString().trim().isNotEmpty == true
                  ? user['displayName'].toString()
                  : 'User';
              final photoUrl = user['photoURL']?.toString();

              return PaperCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.s16,
                  vertical: InkSpacing.s12,
                ),
                child: Row(
                  children: [
                    InkAvatar(
                      imageUrl: photoUrl,
                      initials: inkInitialsFor(displayName),
                      id: blockedUid,
                      size: 44,
                    ),
                    const SizedBox(width: InkSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: InkType.bodyStrong(tokens.ink)),
                          Text(blockedUid, style: InkType.caption(tokens.inkMuted)),
                        ],
                      ),
                    ),
                    InkButton.secondary(
                      label: 'Unblock',
                      compact: true,
                      expand: false,
                      onPressed: blockedUid.isEmpty
                          ? null
                          : () {
                              context
                                  .read<FriendsBloc>()
                                  .add(UnblockUserRequested(blockedUid));
                            },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
