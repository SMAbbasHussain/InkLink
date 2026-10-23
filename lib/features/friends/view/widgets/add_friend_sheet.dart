import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_initials.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../../../ui/widgets/paper_card.dart';
import '../../../../ui/widgets/status_chip.dart';
import '../../../chat/view/chat_thread_screen.dart';
import '../../../profile/view/profile_route.dart';
import '../../bloc/friends_bloc.dart';

/// Modal bottom sheet allowing users to search other users by email
/// and send friend requests (or message existing friends).
class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key});

  /// Static helper to display the sheet in [context].
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddFriendSheet(),
    );
  }

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    final query = _emailController.text.trim();
    if (query.isNotEmpty) {
      context.read<FriendsBloc>().add(SearchUserByEmailRequested(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s16,
        InkSpacing.s8,
        InkSpacing.s16,
        InkSpacing.s24 + bottomInset,
      ),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.s24,
            vertical: InkSpacing.s20,
          ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.userPlus, size: 22, color: tokens.accent),
                  const SizedBox(width: InkSpacing.s8),
                  Text(
                    'Add Collaborator',
                    style: InkType.headline(tokens.ink).copyWith(fontSize: 22),
                  ),
                ],
              ),
              const SizedBox(height: InkSpacing.s8),
              Text(
                'Search for teammates by their exact email to connect and collaborate.',
                textAlign: TextAlign.center,
                style: InkType.body(tokens.inkMuted),
              ),
              const SizedBox(height: InkSpacing.s24),
              InkTextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.search,
                hintText: 'example@email.com',
                leadingIcon: LucideIcons.mail,
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: Icon(LucideIcons.search, color: tokens.inkMuted),
                  onPressed: _triggerSearch,
                ),
                onSubmitted: (_) => _triggerSearch(),
              ),
              const SizedBox(height: InkSpacing.s24),
              Expanded(
                child: BlocBuilder<FriendsBloc, FriendsState>(
                  builder: (context, state) {
                    if (state is EmailSearchInProgress) {
                      return Center(
                        child: CircularProgressIndicator(color: tokens.accent),
                      );
                    }

                    if (state is EmailSearchEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.searchX, size: 56, color: tokens.inkMuted),
                          const SizedBox(height: InkSpacing.s16),
                          Text(
                            'No user found with this email.',
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
                          ],
                        );
                      }

                      final user = state.result;
                      final String name = user['displayName'] ?? 'Creator';
                      final String? photoUrl = user['photoURL'];
                      final isAlreadyFriend = state.friendUids.contains(user['uid']);
                      final isPending = state.pendingOutgoingUids.contains(user['uid']);
                      final isSending = state.sendingRequestTargetUids.contains(user['uid']);

                      return SingleChildScrollView(
                        child: PaperCard(
                          padding: const EdgeInsets.all(InkSpacing.s16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(InkRadii.card),
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
                                  size: 50,
                                ),
                                const SizedBox(width: InkSpacing.s16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: InkType.bodyStrong(tokens.ink)),
                                      Text(
                                        user['email'] ?? '',
                                        style: InkType.caption(tokens.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isPending)
                                  const StatusChip(status: InkStatus.pending)
                                else
                                  InkButton.primary(
                                    label: isSending
                                        ? ''
                                        : (isAlreadyFriend ? 'Message' : 'Add'),
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
                                    onPressed: isSending
                                        ? null
                                        : isAlreadyFriend
                                            ? () {
                                                Navigator.pop(context);
                                                final conv = ChatConversationModel(
                                                  id: user['uid'].toString(),
                                                  name: name,
                                                  avatarUrl: photoUrl,
                                                  isGroup: false,
                                                );
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ChatThreadScreen(conversation: conv),
                                                  ),
                                                );
                                              }
                                            : () {
                                                context.read<FriendsBloc>().add(
                                                      SendFriendRequestRequested(user['uid']),
                                                    );
                                              },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.userPlus,
                          size: 72,
                          color: tokens.inkMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: InkSpacing.s16),
                        Text(
                          'Ready to build together?',
                          style: InkType.bodyStrong(tokens.inkMuted),
                        ),
                        const SizedBox(height: InkSpacing.s4),
                        Text(
                          'Enter an email above to find collaborators',
                          style: InkType.caption(tokens.inkMuted),
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
    );
  }
}
