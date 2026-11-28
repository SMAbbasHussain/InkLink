import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/widgets/desk_background.dart';
import '../../../../ui/widgets/glass_nav_bar.dart';
import '../../../ui/widgets/web_board_opener.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../../boards/view/web_boards_screen.dart';
import '../../boards/view/web_discover_screen.dart';
import '../../friends/bloc/web_friends_cubit.dart';
import '../../friends/view/web_friends_screen.dart';
import '../../invites/bloc/web_invites_cubit.dart';
import '../../invites/view/web_invites_screen.dart';
import '../../notifications/bloc/web_notifications_cubit.dart';
import '../../notifications/view/web_notifications_screen.dart';
import '../../profile/view/web_profile_screen.dart';
import '../../settings/view/web_settings_screen.dart';
import '../../workspaces/view/web_workspaces_screen.dart';
import 'web_navigation_chrome.dart';
import 'web_shell_section.dart';

/// Sections in the narrow floating nav bar, in order.
const _navSections = [
  WebSection.boards,
  WebSection.workspaces,
  WebSection.discover,
  WebSection.invites,
  WebSection.friends,
];

Widget _pageFor(WebSection section) => switch (section) {
  WebSection.boards => const WebBoardsPage(),
  WebSection.workspaces => const WebWorkspacesPage(),
  WebSection.discover => const WebDiscoverPage(),
  WebSection.invites => const WebInvitesPage(),
  WebSection.friends => const WebFriendsPage(),
  WebSection.notifications => const WebNotificationsPage(),
  WebSection.profile => const WebProfilePage(),
  WebSection.settings => const WebSettingsPage(),
};

/// Signed-in layout shell: Desk background, top header, desktop sidebar (or
/// narrow floating nav bar), and live section badge counts.
class WebHomeShell extends StatefulWidget {
  final WebSection initialSection;

  /// Board from a `/board/<id>` deep link, opened once after the first frame.
  final String? initialBoardId;

  const WebHomeShell({
    super.key,
    this.initialSection = WebSection.boards,
    this.initialBoardId,
  });

  @override
  State<WebHomeShell> createState() => _WebHomeShellState();
}

class _WebHomeShellState extends State<WebHomeShell> {
  late WebSection _section = widget.initialSection;

  @override
  void initState() {
    super.initState();
    final boardId = widget.initialBoardId?.trim();
    if (boardId != null && boardId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final opener = context.read<WebBoardOpener>();
        if (opener.openId != null) {
          opener.openId!(context, boardId);
        } else {
          showWebMessage(
            context,
            'Open this board in the InkLink app: $boardId',
          );
        }
      });
    }
  }

  late int _lastNavIndex = _navSections.contains(widget.initialSection)
      ? _navSections.indexOf(widget.initialSection)
      : 0;

  void _goTo(WebSection section) => setState(() {
    _section = section;
    final i = _navSections.indexOf(section);
    if (i >= 0) _lastNavIndex = i;
  });

  int get _unread => context.watch<WebNotificationsCubit>().state.unreadCount;
  int get _pendingInvites =>
      context.watch<WebInvitesCubit>().state.totalPendingInvites;
  int get _friendRequests =>
      context.watch<WebFriendsCubit>().state.friendRequests.length;

  int _badgeFor(WebSection s) => switch (s) {
    WebSection.invites => _pendingInvites,
    WebSection.friends => _friendRequests,
    WebSection.notifications => _unread,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= webSidebarMinWidth;
    return WebShellNav(
      goTo: _goTo,
      child: Scaffold(
        body: DeskBackground(
          child: SafeArea(child: wide ? _buildWide() : _buildNarrow()),
        ),
      ),
    );
  }

  Widget _buildWide() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            InkSpacing.s16,
            InkSpacing.s12,
            InkSpacing.s16,
            0,
          ),
          child: WebTopHeader(
            unread: _unread,
            showName: true,
            onNotifications: () => _goTo(WebSection.notifications),
            onProfile: () => _goTo(WebSection.profile),
            onSettings: () => _goTo(WebSection.settings),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  InkSpacing.s16,
                  InkSpacing.s16,
                  0,
                  InkSpacing.s16,
                ),
                child: WebSideNav(
                  selected: _section,
                  badgeFor: _badgeFor,
                  onSelect: _goTo,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_section),
                        child: _pageFor(_section),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow() {
    final navIndex = _navSections.indexOf(_section);
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                InkSpacing.s16,
                InkSpacing.s12,
                InkSpacing.s16,
                0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: WebTopHeader(
                    unread: _unread,
                    onNotifications: () => _goTo(WebSection.notifications),
                    onProfile: () => _goTo(WebSection.profile),
                    onSettings: () => _goTo(WebSection.settings),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_section),
                      child: _pageFor(_section),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassNavBar(
              currentIndex: navIndex < 0 ? _lastNavIndex : navIndex,
              onTap: (i) => _goTo(_navSections[i]),
              items: [
                const GlassNavItem(
                  activeIcon: LucideIcons.house,
                  inactiveIcon: LucideIcons.house,
                  label: 'Home',
                ),
                const GlassNavItem(
                  activeIcon: LucideIcons.briefcase,
                  inactiveIcon: LucideIcons.briefcase,
                  label: 'Workspaces',
                ),
                const GlassNavItem(
                  activeIcon: LucideIcons.compass,
                  inactiveIcon: LucideIcons.compass,
                  label: 'Discover',
                ),
                GlassNavItem(
                  activeIcon: LucideIcons.mailOpen,
                  inactiveIcon: LucideIcons.mail,
                  label: 'Invites',
                  badge: _pendingInvites,
                ),
                GlassNavItem(
                  activeIcon: LucideIcons.users,
                  inactiveIcon: LucideIcons.users,
                  label: 'Friends',
                  badge: _friendRequests,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
