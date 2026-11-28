import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_logo.dart';
import '../../../core/web_formatters.dart';
import '../../../ui/theme/web_theme_controller.dart';
import '../../auth/bloc/web_auth_cubit.dart';
import '../../profile/bloc/web_profile_cubit.dart';
import 'web_shell_section.dart';

/// Desktop left sidebar displaying every section with live badge counts.
class WebSideNav extends StatelessWidget {
  final WebSection selected;
  final int Function(WebSection) badgeFor;
  final ValueChanged<WebSection> onSelect;

  const WebSideNav({
    super.key,
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

/// Top glass header: InkLink brand mark, light/dark toggle, notifications bell,
/// and account menu.
class WebTopHeader extends StatelessWidget {
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  /// Desktop layout displays the user's name next to their avatar.
  final bool showName;

  const WebTopHeader({
    super.key,
    required this.unread,
    required this.onNotifications,
    required this.onProfile,
    required this.onSettings,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final isDark = tokens.isDark;
    final authCubit = context.read<WebAuthCubit>();
    final currentUser = context.watch<WebAuthCubit>().state.user;
    final profile = context.watch<WebProfileCubit>().state.profile;
    final name = profile?.displayName ?? currentUser?.displayName ?? 'You';
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
              tooltip: unread > 0
                  ? 'Notifications, $unread new'
                  : 'Notifications',
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                backgroundColor: tokens.accent,
                textColor: Colors.white,
                child: Icon(LucideIcons.bell, color: tokens.ink),
              ),
              onPressed: onNotifications,
            ),
            const SizedBox(width: InkSpacing.s8),
            PopupMenuButton<String>(
              tooltip: 'Account',
              position: PopupMenuPosition.under,
              offset: const Offset(0, 8),
              onSelected: (value) {
                if (value == 'profile') onProfile();
                if (value == 'settings') onSettings();
                if (value == 'signout') authCubit.signOut();
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
                  child: _menuRow(LucideIcons.user, 'Your profile', tokens.ink),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: _menuRow(LucideIcons.settings, 'Settings', tokens.ink),
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
                    id: currentUser?.uid ?? 'me',
                    size: 36,
                    ring: true,
                  ),
                  if (showName) ...[
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
