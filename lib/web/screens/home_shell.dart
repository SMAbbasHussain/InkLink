import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/user_model.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../glass/glass_background.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';
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

/// Below this width the sidebar becomes a bottom tab bar.
const double _sidebarMinWidth = 768;

/// Signed-in layout in the "dark glass" style: aurora background, floating
/// glass top bar and sidebar (bottom tab bar on narrow screens), live badges
/// for waiting invites, friend requests and unread notifications.
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Glass.theme(),
      child: WebShellNav(
        goTo: _goTo,
        child: GlassBackground(
          child: Builder(builder: _buildScaffold),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= _sidebarMinWidth;
    final reduce = Glass.reduceMotion(context);

    final page = AnimatedSwitcher(
      duration: reduce ? Duration.zero : Glass.ui,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - animation.value)), // 8px rise
            child: child,
          ),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: _sections[_section]!.builder(context),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _TopBar(compact: !wide),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                      child: _SideRail(
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
                        child: page,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: _BottomTabs(
                  selected: _section,
                  badgeFor: _badgeFor,
                  onSelect: _goTo,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool compact;
  const _TopBar({required this.compact});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: true,
      radius: Glass.r20,
      shadow: Glass.shadow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const WebLogoTile(size: 34),
          const SizedBox(width: 10),
          Text('InkLink', style: Glass.heading(size: 18)),
          const SizedBox(width: 8),
          const GlassPill(text: 'web', accent: true),
          const Spacer(),
          _AccountChip(showName: !compact),
        ],
      ),
    );
  }
}

class _AccountChip extends StatefulWidget {
  final bool showName;
  const _AccountChip({required this.showName});

  @override
  State<_AccountChip> createState() => _AccountChipState();
}

class _AccountChipState extends State<_AccountChip> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<UserModel?> _profile = _repo.watchMyProfile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ?? _repo.currentUser?.displayName ?? 'You';
        return PopupMenuButton<String>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
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
                  Text(name, style: Glass.strong()),
                  if (profile?.email != null) Text(profile!.email, style: Glass.small()),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(children: [
                const Icon(LucideIcons.user, size: 17, color: Glass.textSecondary),
                const SizedBox(width: 10),
                Text('Your profile', style: Glass.body(color: Glass.text)),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'signout',
              child: Row(children: [
                const Icon(LucideIcons.logOut, size: 17, color: Glass.danger),
                const SizedBox(width: 10),
                Text('Sign out', style: Glass.body(color: Glass.danger)),
              ]),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            decoration: BoxDecoration(
              color: Glass.bgStrong,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Glass.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassAvatarRing(
                  child: InkAvatar(
                    id: _repo.currentUser?.uid ?? 'me',
                    imageUrl: profile?.photoURL,
                    initials: initialsOf(name),
                    size: 28,
                  ),
                ),
                if (widget.showName) ...[
                  const SizedBox(width: 8),
                  Text(name, style: Glass.small(color: Glass.text, weight: FontWeight.w600)),
                ],
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronDown, size: 15, color: Glass.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Gradient ring with a soft glow around an avatar.
class GlassAvatarRing extends StatelessWidget {
  final Widget child;
  final double width;
  final bool glow;
  const GlassAvatarRing({super.key, required this.child, this.width = 1.6, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(width),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: Glass.accentGradient,
        boxShadow: glow ? Glass.glow(0.9) : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Glass.base),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

const double _railItemHeight = 64;
const double _railWidth = 100; // room for "Notifications"

class _SideRail extends StatelessWidget {
  final WebSection selected;
  final int Function(WebSection) badgeFor;
  final ValueChanged<WebSection> onSelect;

  const _SideRail({required this.selected, required this.badgeFor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final index = WebSection.values.indexOf(selected);
    return GlassPanel(
      blur: true,
      radius: Glass.r20,
      shadow: Glass.shadow,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: SizedBox(
        width: _railWidth,
        height: _railItemHeight * WebSection.values.length,
        child: Stack(
          children: [
            // Soft glass highlight with a thin gradient bar, sliding
            // between items (calmer than a solid gradient block).
            AnimatedPositioned(
              duration: Glass.reduceMotion(context) ? Duration.zero : Glass.ui,
              curve: Curves.easeOutCubic,
              top: index * _railItemHeight + 3,
              left: 0,
              right: 0,
              height: _railItemHeight - 6,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x148B5CF6),
                        borderRadius: BorderRadius.circular(Glass.r14),
                        border: Border.all(color: const Color(0x338B5CF6)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 14,
                    bottom: 14,
                    width: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Glass.accentA, Glass.accentB],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: Glass.glow(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                for (final s in WebSection.values)
                  SizedBox(
                    height: _railItemHeight,
                    child: _NavItem(
                      section: s,
                      selected: s == selected,
                      badge: badgeFor(s),
                      onTap: () => onSelect(s),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final WebSection section;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  final bool showLabel;

  const _NavItem({
    required this.section,
    required this.selected,
    required this.badge,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final info = _sections[section]!;
    final iconColor = selected ? Glass.accentText : Glass.textMuted;
    final labelColor = selected ? Glass.text : Glass.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: badge > 0 ? '${info.label}, $badge new' : info.label,
      excludeSemantics: true,
      child: Tooltip(
        message: info.label,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Glass.r14),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(info.icon, size: 20, color: iconColor),
                    if (badge > 0)
                      Positioned(right: -11, top: -7, child: GlassBadge(count: badge)),
                  ],
                ),
                if (showLabel) ...[
                  const SizedBox(height: 6),
                  Text(
                    info.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Glass.small(color: labelColor, weight: FontWeight.w600)
                        .copyWith(fontSize: 11.5, letterSpacing: 0.1),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom tab bar (narrow screens)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomTabs extends StatelessWidget {
  final WebSection selected;
  final int Function(WebSection) badgeFor;
  final ValueChanged<WebSection> onSelect;

  const _BottomTabs({required this.selected, required this.badgeFor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sections = WebSection.values;
    final index = sections.indexOf(selected);
    return GlassPanel(
      blur: true,
      radius: Glass.r20,
      shadow: Glass.shadow,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 52,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / sections.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: Glass.reduceMotion(context) ? Duration.zero : Glass.ui,
                  curve: Curves.easeOutCubic,
                  left: index * itemWidth + 3,
                  width: itemWidth - 6,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x148B5CF6),
                      borderRadius: BorderRadius.circular(Glass.r14),
                      border: Border.all(color: const Color(0x338B5CF6)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final s in sections)
                      SizedBox(
                        width: itemWidth,
                        child: _NavItem(
                          section: s,
                          selected: s == selected,
                          badge: badgeFor(s),
                          onTap: () => onSelect(s),
                          showLabel: false,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
