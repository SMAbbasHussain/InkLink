import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/user_model.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/desk_background.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import 'boards_page.dart';
import 'friends_page.dart';
import 'invites_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'sign_in_screen.dart' show WebLogoTile;
import 'web_shell_nav.dart';

class _SectionInfo {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  const _SectionInfo(this.label, this.icon, this.builder);
}

final _sections = <WebSection, _SectionInfo>{
  WebSection.boards: _SectionInfo('Boards', LucideIcons.layoutGrid, (_) => const WebBoardsPage()),
  WebSection.discover: _SectionInfo('Discover', LucideIcons.compass, (_) => const WebDiscoverPage()),
  WebSection.invites: _SectionInfo('Invites', LucideIcons.mailOpen, (_) => const WebInvitesPage()),
  WebSection.friends: _SectionInfo('Friends', LucideIcons.users, (_) => const WebFriendsPage()),
  WebSection.notifications:
      _SectionInfo('Notifications', LucideIcons.bell, (_) => const WebNotificationsPage()),
  WebSection.profile: _SectionInfo('Profile', LucideIcons.user, (_) => const WebProfilePage()),
};

/// Signed-in layout: side rail on wide screens, bottom bar on narrow ones,
/// with live badges for waiting invites, friend requests and unread
/// notifications.
class WebHomeShell extends StatefulWidget {
  const WebHomeShell({super.key});

  @override
  State<WebHomeShell> createState() => _WebHomeShellState();
}

class _WebHomeShellState extends State<WebHomeShell> {
  WebSection _section = WebSection.boards;
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
      _subs.add(stream.listen(
        (items) {
          if (mounted) setState(() => onData(items));
        },
        onError: (_) {}, // Badges are optional; pages show errors themselves.
      ));
    }

    listen(repo.watchBoardInvites(), (l) => _boardInvites = l.length);
    listen(repo.watchWorkspaceInvites(), (l) => _workspaceInvites = l.length);
    listen(repo.watchIncomingFriendRequests(), (l) => _friendRequests = l.length);
    listen(repo.watchNotifications(), (l) => _unread = l.where((n) => !n.read).length);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  int _badgeFor(WebSection s) => switch (s) {
        WebSection.invites => _boardInvites + _workspaceInvites,
        WebSection.friends => _friendRequests,
        WebSection.notifications => _unread,
        _ => 0,
      };

  void _goTo(WebSection section) => setState(() => _section = section);

  Widget _icon(WebSection s) {
    final count = _badgeFor(s);
    final icon = Icon(_sections[s]!.icon);
    if (count == 0) return icon;
    return Badge(
      label: Text(count > 9 ? '9+' : '$count'),
      backgroundColor: context.ink.accent,
      textColor: Colors.white,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final sections = WebSection.values;
    final index = sections.indexOf(_section);

    final page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: _sections[_section]!.builder(context),
      ),
    );

    return WebShellNav(
      goTo: _goTo,
      child: Scaffold(
        backgroundColor: ink.surfaceDesk,
        appBar: AppBar(
          backgroundColor: ink.paper,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: ink.glassStroke)),
          titleSpacing: InkSpacing.s16,
          title: Row(
            children: [
              const WebLogoTile(size: 34),
              const SizedBox(width: InkSpacing.s8),
              Text('InkLink', style: InkType.title(ink.ink)),
              const SizedBox(width: InkSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ink.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('web', style: InkType.caption(ink.accentText)),
              ),
            ],
          ),
          actions: [
            _AccountMenu(showName: wide),
            const SizedBox(width: InkSpacing.s12),
          ],
        ),
        body: Row(
          children: [
            if (wide)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ink.paper,
                  border: Border(right: BorderSide(color: ink.glassStroke)),
                ),
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: index,
                  labelType: NavigationRailLabelType.all,
                  minWidth: 88,
                  groupAlignment: -0.95,
                  indicatorColor: ink.accentSoft,
                  selectedIconTheme: IconThemeData(color: ink.accentText),
                  unselectedIconTheme: IconThemeData(color: ink.inkSecondary),
                  selectedLabelTextStyle: InkType.label(ink.accentText),
                  unselectedLabelTextStyle: InkType.label(ink.inkSecondary),
                  onDestinationSelected: (i) => _goTo(sections[i]),
                  destinations: [
                    for (final s in sections)
                      NavigationRailDestination(
                        icon: _icon(s),
                        label: Text(_sections[s]!.label),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: DeskBackground(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: page,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                backgroundColor: ink.paper,
                indicatorColor: ink.accentSoft,
                selectedIndex: index,
                onDestinationSelected: (i) => _goTo(sections[i]),
                labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  for (final s in sections)
                    NavigationDestination(icon: _icon(s), label: _sections[s]!.label),
                ],
              ),
      ),
    );
  }
}

class _AccountMenu extends StatefulWidget {
  final bool showName;
  const _AccountMenu({required this.showName});

  @override
  State<_AccountMenu> createState() => _AccountMenuState();
}

class _AccountMenuState extends State<_AccountMenu> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<UserModel?> _profile = _repo.watchMyProfile();

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return StreamBuilder<UserModel?>(
      stream: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ?? _repo.currentUser?.displayName ?? 'You';
        return PopupMenuButton<String>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          onSelected: (value) {
            if (value == 'profile') WebShellNav.maybeOf(context)?.goTo(WebSection.profile);
            if (value == 'signout') _repo.signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: InkType.bodyStrong(ink.ink)),
                  if (profile?.email != null)
                    Text(profile!.email, style: InkType.caption(ink.inkMuted)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(children: [
                Icon(LucideIcons.user, size: 18, color: ink.inkSecondary),
                const SizedBox(width: InkSpacing.s8),
                Text('Your profile', style: InkType.body(ink.ink)),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'signout',
              child: Row(children: [
                Icon(LucideIcons.logOut, size: 18, color: ink.danger),
                const SizedBox(width: InkSpacing.s8),
                Text('Sign out', style: InkType.body(ink.danger)),
              ]),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ink.glassStroke),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkAvatar(
                  id: _repo.currentUser?.uid ?? 'me',
                  imageUrl: profile?.photoURL,
                  initials: initialsOf(name),
                  size: 30,
                ),
                if (widget.showName) ...[
                  const SizedBox(width: 8),
                  Text(name, style: InkType.label(ink.ink)),
                ],
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, size: 16, color: ink.inkMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}
