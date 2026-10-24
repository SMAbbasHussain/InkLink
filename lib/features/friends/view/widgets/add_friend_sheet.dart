import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/services/friends/friends_service.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_initials.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../../../ui/widgets/paper_card.dart';
import '../../../chat/view/chat_thread_route.dart';
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
  Map<String, dynamic>? _searchResult;
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _triggerSearch() async {
    final query = _emailController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final friendsService = context.read<FriendsService>();
      final results = await friendsService.searchUsersByEmail(query);
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResult = results.isNotEmpty ? results.first : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchError = e.toString().contains('offline')
              ? 'Offline mode: Search requires internet.'
              : 'Failed to search for user.';
        });
      }
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
                    if (_isSearching) {
                      return Center(
                        child: CircularProgressIndicator(color: tokens.accent),
                      );
                    }

                    if (_searchError != null) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.wifiOff, size: 52, color: tokens.inkMuted),
                          const SizedBox(height: InkSpacing.s12),
                          Text('Search unavailable', style: InkType.bodyStrong(tokens.ink)),
                          const SizedBox(height: InkSpacing.s4),
                          Text(
                            _searchError!,
                            textAlign: TextAlign.center,
                            style: InkType.caption(tokens.inkMuted),
                          ),
                        ],
                      );
                    }

                    if (_hasSearched && _searchResult == null) {
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

                    if (_searchResult != null) {
                      final user = _searchResult!;
                      final uid = user['uid']?.toString() ?? '';
                      final String name = user['displayName'] ?? 'Creator';
                      final String? photoUrl = user['photoURL'];

                      final friendUids = <String>{};
                      final pendingOutgoingUids = <String>{};
                      final sendingRequestTargetUids = <String>{};

                      if (state is FriendsLoaded) {
                        friendUids.addAll(
                          state.friends.map((f) => f['uid']?.toString() ?? ''),
                        );
                        pendingOutgoingUids.addAll(
                          state.outgoingRequests.map((r) => r['toUid']?.toString() ?? ''),
                        );
                        sendingRequestTargetUids.addAll(state.sendingRequestTargetUids);
                      } else if (state is EmailSearchResultsLoaded) {
                        friendUids.addAll(state.friendUids);
                        pendingOutgoingUids.addAll(state.pendingOutgoingUids);
                        sendingRequestTargetUids.addAll(state.sendingRequestTargetUids);
                      }

                      final isAlreadyFriend = friendUids.contains(uid);
                      final isPending = pendingOutgoingUids.contains(uid);
                      final isSending = sendingRequestTargetUids.contains(uid);

                      return SingleChildScrollView(
                        child: PaperCard(
                          padding: const EdgeInsets.all(InkSpacing.s16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(InkRadii.card),
                            onTap: () {
                              Navigator.push(
                                context,
                                buildProfileRoute(context, userId: uid),
                              );
                            },
                            child: Row(
                              children: [
                                InkAvatar(
                                  imageUrl: photoUrl,
                                  initials: inkInitialsFor(name),
                                  id: uid,
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
                                if (isAlreadyFriend)
                                  InkButton.primary(
                                    label: 'Message',
                                    compact: true,
                                    expand: false,
                                    onPressed: () {
                                      Navigator.pop(context);
                                      final conv = ChatConversationModel(
                                        id: uid,
                                        name: name,
                                        avatarUrl: photoUrl,
                                        isGroup: false,
                                      );
                                      Navigator.push(
                                        context,
                                        buildChatThreadRoute(context, conversation: conv),
                                      );
                                    },
                                  )
                                else if (isPending)
                                  const InkButton.success(
                                    label: 'Sent',
                                    compact: true,
                                    expand: false,
                                    icon: Icon(LucideIcons.check, color: Colors.white, size: 16),
                                    onPressed: null,
                                  )
                                else
                                  InkButton.primary(
                                    label: isSending ? '' : 'Add',
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
                                        : () {
                                            context.read<FriendsBloc>().add(
                                                  SendFriendRequestRequested(uid),
                                                );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 18),
                                                    const SizedBox(width: 8),
                                                    Text('Friend request sent to $name!'),
                                                  ],
                                                ),
                                                backgroundColor: const Color(0xFF16A34A),
                                                behavior: SnackBarBehavior.floating,
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
