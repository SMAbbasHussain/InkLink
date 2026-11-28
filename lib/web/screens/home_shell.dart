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
import '../widgets/web_widgets.dart';
import 'boards_page.dart';
import 'friends_page.dart';
import 'invites_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'workspaces_page.dart';
import 'web_shell_nav.dart';

/// Sections in the bottom nav bar, in order. Notifications and Profile open
/// from the header, as on the phone.
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

/// Signed-in layout, styled like the mobile app: the desk background, a
/// glass header (logo, theme switch, notifications, avatar) and the
/// floating glass nav bar, with live badges for waiting invites, friend
/// requests and unread notifications.
class WebHomeShell extends StatefulWidget {
  /// Section shown first (the preview opens any section from the URL).
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
      repo.watchNotificationsWithReadState(),
      (l) => _unread = l.where((n) => !n.read).length,
    );

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

  int _badgeFor(WebSection s) => switch (s) {
    WebSection.invites => _boardInvites + _workspaceInvites,
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

  /// Desktop: a full-width top bar and a labelled sidebar, in the mobile
  /// app's colours and components.
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
          child: _Header(
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
                child: _SideNav(
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

  /// Small windows: the phone's header and floating nav bar.
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
                  child: _Header(
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
    );
  }
}

/// Left sidebar for wide windows: every section with its icon, label and
/// count, the selected one in the mobile nav bar's soft accent pill.
class _SideNav extends StatelessWidget {
  final WebSection selected;
  final int Function(WebSection) badgeFor;
  final ValueChanged<WebSection> onSelect;

  const _SideNav({
    required this.selected,
    required this.badgeFor,
    required this.onSelect,
  });

  static const _items = <(WebSection, IconData, String)>[
    (WebSection.boards, LucideIcons.house, 'Home'),
    (WebSection.workspaces, LucideIcons.briefcase, 'Workspaces'),
    (WebSection.discover, LucideIcons.compass, 'Discover'),
    (WebSection.invites, LucideIcons.mail, 'Invites'),
    (WebSection.friends, LucideIcons.users, 'Friends'),
    (WebSection.notifications, LucideIcons.bell, 'Notifications'),
    (WebSection.profile, LucideIcons.user, 'Profile'),
    (WebSection.settings, LucideIcons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SizedBox(
      width: 216,
      child: GlassPanel(
        radius: 20,
        padding: const EdgeInsets.all(InkSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (section, icon, label) in _items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _SideNavItem(
                  icon: icon,
                  label: label,
                  badge: badgeFor(section),
                  selected: section == selected,
                  onTap: () => onSelect(section),
                  tokens: tokens,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;
  final InkTokens tokens;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.accentText : tokens.inkSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge new' : label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            decoration: BoxDecoration(
              color: selected ? tokens.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: Text(
                    label,
                    style: selected
                        ? InkType.bodyStrong(color)
                        : InkType.body(color),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$badge', style: InkType.caption(Colors.white)),
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
  final VoidCallback onSettings;

  /// Desktop: show the name next to the avatar.
  final bool showName;

  const _Header({
    required this.unread,
    required this.onNotifications,
    required this.onProfile,
    required this.onSettings,
    this.showName = false,
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
                    if (value == 'settings') widget.onSettings();
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
                      value: 'settings',
                      child: _menuRow(
                        LucideIcons.settings,
                        'Settings',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkAvatar(
                        imageUrl: profile?.photoURL,
                        initials: initialsOf(name),
                        id: _repo.currentUser?.uid ?? 'me',
                        size: 36,
                        ring: true,
                      ),
                      if (widget.showName) ...[
                        const SizedBox(width: InkSpacing.s8),
                        Text(name, style: InkType.bodyStrong(tokens.ink)),
                        const SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: tokens.inkMuted,
                        ),
                      ],
                    ],
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
