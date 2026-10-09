import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_event.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/paper_card.dart';
import '../bloc/settings_bloc.dart';
import '../../theme/bloc/theme_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final isDark = tokens.isDark;

    return MultiBlocListener(
      listeners: [
        BlocListener<SettingsBloc, SettingsState>(
          listenWhen: (previous, current) =>
              current.message != null && current.message != previous.message,
          listener: (context, state) {
            final message = state.message;
            if (message == null) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: state.isError
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.ban, size: 16, color: tokens.danger),
                          const SizedBox(width: InkSpacing.s8),
                          Flexible(child: Text(message)),
                        ],
                      )
                    : Text(message),
              ),
            );
            context.read<SettingsBloc>().add(const SettingsConsumeMessage());
          },
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final authUser = authState is Authenticated ? authState : null;

          return BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) {
              return Scaffold(
                backgroundColor: tokens.surfaceDesk,
                appBar: AppBar(title: Text('Settings', style: InkType.headline(tokens.ink))),
                body: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    InkSpacing.s16,
                    InkSpacing.s8,
                    InkSpacing.s16,
                    InkSpacing.s32,
                  ),
                  children: [
                    _buildProfileHeader(tokens, authUser),
                    const SizedBox(height: InkSpacing.s24),
                    _buildSectionHeader(tokens, 'Appearance'),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: _row(
                        tokens,
                        icon: LucideIcons.moon,
                        title: 'Dark Mode',
                        trailing: Switch(
                          value: isDark,
                          onChanged: (_) =>
                              context.read<ThemeBloc>().add(ToggleTheme()),
                        ),
                      ),
                    ),
                    _buildSectionHeader(tokens, 'Canvas'),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _row(
                            tokens,
                            icon: LucideIcons.lightbulb,
                            title: 'Show Tray Tips Overlay',
                            subtitle:
                                'Show tray position helper when creating or joining a board',
                            trailing: Switch(
                              value: settingsState.showTrayTips,
                              onChanged: settingsState.isLoadingTrayTips
                                  ? null
                                  : (value) {
                                      context.read<SettingsBloc>().add(
                                        SettingsTrayTipsToggled(value),
                                      );
                                    },
                            ),
                          ),
                          Divider(height: 1, color: tokens.glassStroke),
                          _row(
                            tokens,
                            icon: LucideIcons.image,
                            title: 'Board Preview Quality',
                            subtitle: 'Used when saving board thumbnail after leaving canvas',
                            trailing: DropdownButton<String>(
                              value: settingsState.boardPreviewQuality,
                              underline: const SizedBox.shrink(),
                              icon: Icon(LucideIcons.chevronDown, size: 18, color: tokens.inkMuted),
                              onChanged: (value) {
                                if (value == null) return;
                                context.read<SettingsBloc>().add(
                                  SettingsBoardPreviewQualityChanged(value),
                                );
                              },
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Low')),
                                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                DropdownMenuItem(value: 'high', child: Text('High')),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: tokens.glassStroke),
                          _row(
                            tokens,
                            icon: LucideIcons.minimize2,
                            title: 'Compress Board Preview',
                            subtitle: 'Recommended ON. Defaults to medium compressed previews.',
                            trailing: Switch(
                              value: settingsState.boardPreviewCompressionEnabled,
                              onChanged: (value) {
                                context.read<SettingsBloc>().add(
                                  SettingsBoardPreviewCompressionToggled(value),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSectionHeader(tokens, 'Storage'),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: _row(
                        tokens,
                        icon: LucideIcons.database,
                        title: 'Offline Database (Isar Community)',
                        subtitle: 'Tap clear to remove local cached boards',
                        trailing: InkButton.secondary(
                          label: 'Clear Cache',
                          compact: true,
                          expand: false,
                          onPressed: () {
                            context.read<SettingsBloc>().add(
                              const SettingsClearCacheRequested(),
                            );
                          },
                        ),
                      ),
                    ),
                    _buildSectionHeader(tokens, 'Account'),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _showLogoutDialog(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: InkSpacing.s16,
                            vertical: InkSpacing.s12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: tokens.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(LucideIcons.logOut, size: 18, color: tokens.danger),
                              ),
                              const SizedBox(width: InkSpacing.s12),
                              Text(
                                'Logout',
                                style: InkType.bodyStrong(tokens.danger),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _row(
    InkTokens tokens, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16, vertical: InkSpacing.s12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tokens.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tokens.ink),
          ),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: InkType.body(tokens.ink)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: InkType.caption(tokens.inkMuted)),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: InkSpacing.s12), trailing],
        ],
      ),
    );
  }

  Widget _buildProfileHeader(InkTokens tokens, Authenticated? user) {
    return PaperCard(
      padding: const EdgeInsets.all(InkSpacing.s16),
      child: Row(
        children: [
          InkAvatar(
            imageUrl: user?.photoUrl,
            initials: inkInitialsFor(user?.userName),
            id: user?.uid ?? '',
            size: 56,
            ring: true,
          ),
          const SizedBox(width: InkSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.userName ?? 'InkLink Creator',
                  style: InkType.title(tokens.ink),
                ),
                Text(user?.email ?? '', style: InkType.caption(tokens.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (innerContext) => InkDialog(
        title: "Logout",
        content: Text(
          "Are you sure you want to sign out of InkLink?",
          style: InkType.body(innerContext.ink.inkSecondary),
        ),
        actions: [
          InkButton.secondary(
            label: "Cancel",
            expand: false,
            compact: true,
            onPressed: () => Navigator.pop(innerContext),
          ),
          InkButton.dangerConfirm(
            label: "Logout",
            expand: false,
            compact: true,
            onPressed: () {
              Navigator.pop(innerContext);
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(InkTokens tokens, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(title.toUpperCase(), style: InkType.label(tokens.inkMuted)),
    );
  }
}
