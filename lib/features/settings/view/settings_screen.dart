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
import '../../../ui/widgets/ink_chip.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_text_field.dart';
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
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthDeletingAccount) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting account...')),
              );
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: tokens.danger,
                ),
              );
            }
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
                    112,
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
                        trailing: Switch.adaptive(
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
                            trailing: Switch.adaptive(
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
                            trailing: Switch.adaptive(
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

                    _buildSectionHeader(tokens, 'Notifications'),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _row(
                            tokens,
                            icon: LucideIcons.bell,
                            title: 'Push Notifications',
                            subtitle: 'Receive real-time push notifications on this device',
                            trailing: Switch.adaptive(
                              value: settingsState.pushNotificationsEnabled,
                              onChanged: (value) {
                                context.read<SettingsBloc>().add(
                                  SettingsNotificationPreferencesChanged(
                                    pushNotificationsEnabled: value,
                                  ),
                                );
                              },
                            ),
                          ),
                          Divider(height: 1, color: tokens.glassStroke),
                          _row(
                            tokens,
                            icon: LucideIcons.mail,
                            title: 'Board Invite Alerts',
                            subtitle: 'Get notified when someone invites you to a board',
                            trailing: Switch.adaptive(
                              value: settingsState.inviteAlertsEnabled,
                              onChanged: settingsState.pushNotificationsEnabled
                                  ? (value) {
                                      context.read<SettingsBloc>().add(
                                        SettingsNotificationPreferencesChanged(
                                          inviteAlertsEnabled: value,
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          Divider(height: 1, color: tokens.glassStroke),
                          _row(
                            tokens,
                            icon: LucideIcons.userPlus,
                            title: 'Friend Request Alerts',
                            subtitle: 'Get notified when you receive or accept friend requests',
                            trailing: Switch.adaptive(
                              value: settingsState.friendAlertsEnabled,
                              onChanged: settingsState.pushNotificationsEnabled
                                  ? (value) {
                                      context.read<SettingsBloc>().add(
                                        SettingsNotificationPreferencesChanged(
                                          friendAlertsEnabled: value,
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader(tokens, 'Privacy'),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _row(
                            tokens,
                            icon: LucideIcons.globe,
                            title: 'Public Profile',
                            subtitle: 'Allow non-friends to view your profile and public boards',
                            trailing: Switch.adaptive(
                              value: settingsState.isProfilePublic,
                              onChanged: (value) {
                                context.read<SettingsBloc>().add(
                                  SettingsPrivacyChanged(isProfilePublic: value),
                                );
                              },
                            ),
                          ),
                          Divider(height: 1, color: tokens.glassStroke),
                          _row(
                            tokens,
                            icon: LucideIcons.activity,
                            title: 'Show Online Status',
                            subtitle: 'Let collaborators see when you are active on boards',
                            trailing: Switch.adaptive(
                              value: settingsState.showOnlineStatus,
                              onChanged: (value) {
                                context.read<SettingsBloc>().add(
                                  SettingsPrivacyChanged(showOnlineStatus: value),
                                );
                              },
                            ),
                          ),
                          Divider(height: 1, color: tokens.glassStroke),
                          _row(
                            tokens,
                            icon: LucideIcons.atSign,
                            title: 'Show Email Address',
                            subtitle: 'Display your email address on your public profile',
                            trailing: Switch.adaptive(
                              value: settingsState.showEmail,
                              onChanged: (value) {
                                context.read<SettingsBloc>().add(
                                  SettingsPrivacyChanged(showEmail: value),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader(tokens, 'Content Preferences'),
                    PaperCard(
                      padding: const EdgeInsets.all(InkSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: tokens.field,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(LucideIcons.tag, size: 18, color: tokens.ink),
                              ),
                              const SizedBox(width: InkSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Preferred Content Tags', style: InkType.body(tokens.ink)),
                                    Text(
                                      'Personalize your recommended boards and template feed',
                                      style: InkType.caption(tokens.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(LucideIcons.pen, size: 18, color: tokens.inkMuted),
                                tooltip: 'Edit tags',
                                onPressed: () => _showTagsDialog(
                                  context,
                                  settingsState.preferredTags,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: InkSpacing.s12),
                          if (settingsState.preferredTags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: settingsState.preferredTags.map((tag) {
                                return InkChip(
                                  label: '#$tag',
                                  selected: true,
                                  onDeleted: () {
                                    final updated = List<String>.from(settingsState.preferredTags)
                                      ..remove(tag);
                                    context.read<SettingsBloc>().add(
                                      SettingsPreferredTagsChanged(updated),
                                    );
                                  },
                                );
                              }).toList(),
                            )
                          else
                            InkButton.secondary(
                              label: 'Select Interest Tags',
                              icon: const Icon(LucideIcons.plus),
                              compact: true,
                              expand: false,
                              onPressed: () => _showTagsDialog(
                                context,
                                settingsState.preferredTags,
                              ),
                            ),
                        ],
                      ),
                    ),

                    _buildSectionHeader(tokens, 'Account'),
                    PaperCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(InkRadii.card)),
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
                                      color: tokens.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(LucideIcons.logOut, size: 18, color: tokens.accent),
                                  ),
                                  const SizedBox(width: InkSpacing.s12),
                                  Text(
                                    'Logout',
                                    style: InkType.bodyStrong(tokens.accent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 1, color: tokens.glassStroke),
                          InkWell(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(InkRadii.card)),
                            onTap: () => _showDeleteAccountDialog(
                              context,
                              isPasswordUser: authUser?.isPasswordProvider ?? false,
                            ),
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
                                      color: tokens.danger.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(LucideIcons.trash2, size: 18, color: tokens.danger),
                                  ),
                                  const SizedBox(width: InkSpacing.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delete Account',
                                          style: InkType.bodyStrong(tokens.danger),
                                        ),
                                        Text(
                                          'Permanently erase your account, boards, and data',
                                          style: InkType.caption(tokens.danger.withValues(alpha: 0.8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
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

  void _showDeleteAccountDialog(
    BuildContext context, {
    required bool isPasswordUser,
  }) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (innerContext) {
        final tokens = innerContext.ink;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return InkDialog(
              title: "Delete Account",
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Are you sure you want to permanently delete your account?\n\n"
                      "This action is irreversible. All your boards, workspaces, and profile will be permanently erased.",
                      style: InkType.body(tokens.ink),
                    ),
                    if (isPasswordUser) ...[
                      const SizedBox(height: InkSpacing.s16),
                      Text(
                        "Please enter your password to confirm:",
                        style: InkType.bodyStrong(tokens.ink),
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      InkTextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        hintText: "Your password",
                        leadingIcon: LucideIcons.lock,
                        trailingIcon: obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                        onTrailingIconPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: InkSpacing.s12),
                      Container(
                        padding: const EdgeInsets.all(InkSpacing.s8),
                        decoration: BoxDecoration(
                          color: tokens.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.circleAlert, color: tokens.danger, size: 18),
                            const SizedBox(width: InkSpacing.s8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: InkType.caption(tokens.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                InkButton.secondary(
                  label: "Cancel",
                  compact: true,
                  expand: false,
                  onPressed: () => Navigator.pop(innerContext),
                ),
                InkButton.dangerConfirm(
                  label: "Delete Permanently",
                  compact: true,
                  expand: false,
                  onPressed: () {
                    final passwordText = passwordController.text.trim();
                    if (isPasswordUser && passwordText.isEmpty) {
                      setDialogState(() {
                        errorMessage = "Password is required to confirm deletion.";
                      });
                      return;
                    }

                    Navigator.pop(dialogContext);
                    context.read<AuthBloc>().add(
                          DeleteAccountRequested(
                            password: passwordText.isNotEmpty ? passwordText : null,
                          ),
                        );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTagsDialog(BuildContext context, List<String> currentTags) {
    final availableSuggestions = [
      'Art',
      'Architecture',
      'Brainstorming',
      'Design',
      'Education',
      'Engineering',
      'Gaming',
      'Music',
      'Productivity',
      'Wireframing',
    ];

    final selectedTags = Set<String>.from(currentTags);
    final customTagController = TextEditingController();

    showDialog(
      context: context,
      builder: (innerContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tokens = innerContext.ink;
          return InkDialog(
            title: 'Preferred Content Tags',
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select topics that match your creative focus to personalize your InkLink experience:',
                      style: InkType.caption(tokens.inkMuted),
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSuggestions.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return InkChip(
                          label: '#$tag',
                          selected: isSelected,
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                selectedTags.remove(tag);
                              } else {
                                selectedTags.add(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    Row(
                      children: [
                        Expanded(
                          child: InkTextField(
                            controller: customTagController,
                            hintText: 'Add custom tag...',
                          ),
                        ),
                        const SizedBox(width: InkSpacing.s8),
                        InkButton.secondary(
                          label: 'Add',
                          compact: true,
                          expand: false,
                          onPressed: () {
                            final raw = customTagController.text.trim();
                            if (raw.isNotEmpty) {
                              setDialogState(() {
                                selectedTags.add(raw);
                                customTagController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              InkButton.secondary(
                label: 'Cancel',
                compact: true,
                expand: false,
                onPressed: () => Navigator.pop(innerContext),
              ),
              InkButton.primary(
                label: 'Save',
                compact: true,
                expand: false,
                onPressed: () {
                  Navigator.pop(innerContext);
                  context.read<SettingsBloc>().add(
                    SettingsPreferredTagsChanged(selectedTags.toList()),
                  );
                },
              ),
            ],
          );
        },
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
