import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/user_model.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/ink_logo.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import 'boards_page.dart';
import 'friends_page.dart';
import 'invites_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';

class _Section {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  const _Section(this.label, this.icon, this.builder);
}

/// Signed-in layout: side rail on wide screens, bottom bar on narrow ones.
class WebHomeShell extends StatefulWidget {
  const WebHomeShell({super.key});

  @override
  State<WebHomeShell> createState() => _WebHomeShellState();
}

class _WebHomeShellState extends State<WebHomeShell> {
  int _index = 0;

  static final _sections = <_Section>[
    _Section('Boards', LucideIcons.layoutGrid, (_) => const WebBoardsPage()),
    _Section('Discover', LucideIcons.compass, (_) => const WebDiscoverPage()),
    _Section('Invites', LucideIcons.mailOpen, (_) => const WebInvitesPage()),
    _Section('Friends', LucideIcons.users, (_) => const WebFriendsPage()),
    _Section('Notifications', LucideIcons.bell, (_) => const WebNotificationsPage()),
    _Section('Profile', LucideIcons.user, (_) => const WebProfilePage()),
  ];

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final page = KeyedSubtree(
      key: ValueKey(_index),
      child: _sections[_index].builder(context),
    );

    return Scaffold(
      backgroundColor: ink.surfaceDesk,
      appBar: AppBar(
        backgroundColor: ink.paper,
        surfaceTintColor: Colors.transparent,
        titleSpacing: InkSpacing.s16,
        title: Row(
          children: [
            const InkLogo(size: 28),
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
        actions: const [_AccountMenu(), SizedBox(width: InkSpacing.s12)],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              backgroundColor: ink.paper,
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final s in _sections)
                  NavigationRailDestination(icon: Icon(s.icon), label: Text(s.label)),
              ],
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: page,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final s in _sections)
                  NavigationDestination(icon: Icon(s.icon), label: s.label),
              ],
            ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<WebCompanionRepository>();
    final ink = context.ink;
    return StreamBuilder<UserModel?>(
      stream: repo.watchMyProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ?? repo.currentUser?.displayName ?? 'You';
        return PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (value) {
            if (value == 'signout') repo.signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(name, style: InkType.bodyStrong(ink.ink)),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'signout',
              child: Row(children: [
                Icon(LucideIcons.logOut, size: 18, color: ink.danger),
                const SizedBox(width: InkSpacing.s8),
                Text('Sign out', style: InkType.body(ink.danger)),
              ]),
            ),
          ],
          child: InkAvatar(
            id: repo.currentUser?.uid ?? 'me',
            imageUrl: profile?.photoURL,
            initials: initialsOf(name),
            size: 34,
          ),
        );
      },
    );
  }
}
