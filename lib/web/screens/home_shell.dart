import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/user_model.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/desk_background.dart';
import '../../ui/widgets/glass_nav_bar.dart';
import '../../ui/widgets/glass_panel.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/ink_logo.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../web_theme.dart';
import 'boards_page.dart';
import 'friends_page.dart';
import 'invites_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'web_shell_nav.dart';

/// Sections in the bottom nav bar, in order. Notifications and Profile open
/// from the header, as on the phone.
const _navSections = [
  WebSection.boards,
  WebSection.discover,
  WebSection.invites,
  WebSection.friends,
];

Widget _pageFor(WebSection section) => switch (section) {
  WebSection.boards => const WebBoardsPage(),
  WebSection.discover => const WebDiscoverPage(),
  WebSection.invites => const WebInvitesPage(),
  WebSection.friends => const WebFriendsPage(),
  WebSection.notifications => const WebNotificationsPage(),
  WebSection.profile => const WebProfilePage(),
};

/// Signed-in layout, styled like the mobile app: the desk background, a
/// glass header (logo, theme switch, notifications, avatar) and the
/// floating glass nav bar, with live badges for waiting invites, friend
/// requests and unread notifications.
class WebHomeShell extends StatefulWidget {
  /// Section shown first (the preview opens any section from the URL).
  final WebSection initialSection;

  const WebHomeShell({super.key, this.initialSection = WebSection.boards});

  @override
  State<WebHomeShell> createState() => _WebHomeShellState();
}

class _WebHomeShellState extends State<WebHomeShell> {
  late WebSection _section = widget.initialSection;
  final _subs = <StreamSubscription<dynamic>>[];
  int _boardInvites = 0;
  int _workspaceInvites = 0;
  int _friendRequests = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    final repo = context.read<WebCompanionRepository>();
    void listen<T>(Stream<List<T>> stream, void Function(List<T>) onData) {
      _subs.add(
        stream.listen(
          (items) {
            if (mounted) setState(() => onData(items));
          },
          onError: (_) {}, // Badges are optional; pages show errors.
        ),
      );
    }

    listen(repo.watchBoardInvites(), (l) => _boardInvites = l.length);
    listen(repo.watchWorkspaceInvites(), (l) => _workspaceInvites = l.length);
    listen(
      repo.watchIncomingFriendRequests(),
      (l) => _friendRequests = l.length,
    );
    listen(
      repo.watchNotifications(),
      (l) => _unread = l.where((n) => !n.read).length,
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // The tab to keep highlighted while Notifications or Profile is open.
  late int _lastNavIndex = _navSections.contains(widget.initialSection)
      ? _navSections.indexOf(widget.initialSection)
      : 0;

  void _goTo(WebSection section) => setState(() {
    _section = section;
    final i = _navSections.indexOf(section);
    if (i >= 0) _lastNavIndex = i;
  });

  @override
  Widget build(BuildContext context) {
    final navIndex = _navSections.indexOf(_section);
    return WebShellNav(
      goTo: _goTo,
      child: Scaffold(
        body: DeskBackground(
          child: SafeArea(
            child: Stack(
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
                          child: _Header(
                            unread: _unread,
                            onNotifications: () =>
                                _goTo(WebSection.notifications),
                            onProfile: () => _goTo(WebSection.profile),
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
                          activeIcon: LucideIcons.compass,
                          inactiveIcon: LucideIcons.compass,
                          label: 'Discover',
                        ),
                        GlassNavItem(
                          activeIcon: LucideIcons.mailOpen,
                          inactiveIcon: LucideIcons.mail,
                          label: 'Invites',
                          badge: _boardInvites + _workspaceInvites,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone's home header: logo and name, then theme switch,
/// notifications and the profile avatar.
class _Header extends StatefulWidget {
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _Header({
    required this.unread,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<UserModel?> _profile = _repo.watchMyProfile();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final isDark = tokens.isDark;
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const InkLogo(size: 30),
            const SizedBox(width: InkSpacing.s8),
            Text(
              'InkLink',
              style: InkType.title(tokens.ink).copyWith(fontSize: 18),
            ),
            const SizedBox(width: InkSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(InkRadii.chip),
              ),
              child: Text('web', style: InkType.caption(tokens.accentText)),
            ),
            const Spacer(),
            IconButton(
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              icon: Icon(
                isDark ? LucideIcons.sun : LucideIcons.moon,
                color: tokens.ink,
              ),
              onPressed: () =>
                  context.read<WebThemeController>().toggle(isDark: isDark),
            ),
            IconButton(
              tooltip: widget.unread > 0
                  ? 'Notifications, ${widget.unread} new'
                  : 'Notifications',
              icon: Badge(
                isLabelVisible: widget.unread > 0,
                label: Text('${widget.unread}'),
                backgroundColor: tokens.accent,
                textColor: Colors.white,
                child: Icon(LucideIcons.bell, color: tokens.ink),
              ),
              onPressed: widget.onNotifications,
            ),
            const SizedBox(width: InkSpacing.s8),
            StreamBuilder<UserModel?>(
              stream: _profile,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final name =
                    profile?.displayName ??
                    _repo.currentUser?.displayName ??
                    'You';
                return PopupMenuButton<String>(
                  tooltip: 'Account',
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 8),
                  onSelected: (value) {
                    if (value == 'profile') widget.onProfile();
                    if (value == 'signout') _repo.signOut();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: InkType.bodyStrong(tokens.ink)),
                          if (profile?.email != null)
                            Text(
                              profile!.email,
                              style: InkType.caption(tokens.inkMuted),
                            ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: _menuRow(
                        LucideIcons.user,
                        'Your profile',
                        tokens.ink,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'signout',
                      child: _menuRow(
                        LucideIcons.logOut,
                        'Sign out',
                        tokens.danger,
                      ),
                    ),
                  ],
                  child: InkAvatar(
                    imageUrl: profile?.photoURL,
                    initials: initialsOf(name),
                    id: _repo.currentUser?.uid ?? 'me',
                    size: 36,
                    ring: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: InkType.body(color)),
    ],
  );
}
