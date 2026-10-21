import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_event.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import '../bloc/settings_bloc.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                content: Text(message),
                backgroundColor: state.isError ? Colors.red : null,
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
                  backgroundColor: Colors.red,
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
                appBar: AppBar(title: const Text('Settings')),
                body: ListView(
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileHeader(authUser),
                    const SizedBox(height: 30),
                    _buildSectionHeader('Appearance'),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      secondary: const Icon(Icons.dark_mode),
                      value: isDark,
                      onChanged: (_) =>
                          context.read<ThemeBloc>().add(ToggleTheme()),
                    ),
                    _buildSectionHeader('Canvas'),
                    SwitchListTile(
                      title: const Text('Show Tray Tips Overlay'),
                      subtitle: const Text(
                        'Show tray position helper when creating or joining a board',
                      ),
                      secondary: const Icon(Icons.lightbulb_outline),
                      value: settingsState.showTrayTips,
                      onChanged: settingsState.isLoadingTrayTips
                          ? null
                          : (value) {
                              context.read<SettingsBloc>().add(
                                SettingsTrayTipsToggled(value),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.photo_size_select_large_outlined,
                      ),
                      title: const Text('Board Preview Quality'),
                      subtitle: const Text(
                        'Used when saving board thumbnail after leaving canvas',
                      ),
                      trailing: DropdownButton<String>(
                        value: settingsState.boardPreviewQuality,
                        onChanged: (value) {
                          if (value == null) return;
                          context.read<SettingsBloc>().add(
                            SettingsBoardPreviewQualityChanged(value),
                          );
                        },
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Compress Board Preview'),
                      subtitle: const Text(
                        'Recommended ON. Defaults to medium compressed previews.',
                      ),
                      secondary: const Icon(Icons.compress_outlined),
                      value: settingsState.boardPreviewCompressionEnabled,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                          SettingsBoardPreviewCompressionToggled(value),
                        );
                      },
                    ),
                    _buildSectionHeader('Storage'),
                    ListTile(
                      leading: const Icon(Icons.cloud_download),
                      title: const Text('Offline Database (Isar Community)'),
                      subtitle: const Text(
                        'Tap clear to remove local cached boards',
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          context.read<SettingsBloc>().add(
                            const SettingsClearCacheRequested(),
                          );
                        },
                        child: const Text('Clear Cache'),
                      ),
                    ),
                    _buildSectionHeader('Notifications'),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Push Notifications'),
                      subtitle: const Text(
                        'Receive real-time push notifications on this device',
                      ),
                      value: settingsState.pushNotificationsEnabled,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                          SettingsNotificationPreferencesChanged(
                            pushNotificationsEnabled: value,
                          ),
                        );
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.mail_outline),
                      title: const Text('Board Invite Alerts'),
                      subtitle: const Text(
                        'Get notified when someone invites you to a board',
                      ),
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
                    SwitchListTile(
                      secondary: const Icon(Icons.person_add_outlined),
                      title: const Text('Friend Request Alerts'),
                      subtitle: const Text(
                        'Get notified when you receive or accept friend requests',
                      ),
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
                    _buildSectionHeader('Privacy'),
                    SwitchListTile(
                      secondary: const Icon(Icons.public_outlined),
                      title: const Text('Public Profile'),
                      subtitle: const Text(
                        'Allow non-friends to view your profile and public boards',
                      ),
                      value: settingsState.isProfilePublic,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                          SettingsPrivacyChanged(isProfilePublic: value),
                        );
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.online_prediction),
                      title: const Text('Show Online Status'),
                      subtitle: const Text(
                        'Let collaborators see when you are active on boards',
                      ),
                      value: settingsState.showOnlineStatus,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                          SettingsPrivacyChanged(showOnlineStatus: value),
                        );
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.alternate_email),
                      title: const Text('Show Email Address'),
                      subtitle: const Text(
                        'Display your email address on your public profile',
                      ),
                      value: settingsState.showEmail,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(
                          SettingsPrivacyChanged(showEmail: value),
                        );
                      },
                    ),
                    _buildSectionHeader('Content Preferences'),
                    ListTile(
                      leading: const Icon(Icons.sell_outlined),
                      title: const Text('Preferred Content Tags'),
                      subtitle: const Text(
                        'Personalize your recommended boards and template feed',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showTagsDialog(
                          context,
                          settingsState.preferredTags,
                        ),
                      ),
                    ),
                    if (settingsState.preferredTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: settingsState.preferredTags.map((tag) {
                            return Chip(
                              label: Text('#$tag'),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                final updated = List<String>.from(settingsState.preferredTags)
                                  ..remove(tag);
                                context.read<SettingsBloc>().add(
                                  SettingsPreferredTagsChanged(updated),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: OutlinedButton.icon(
                          onPressed: () => _showTagsDialog(
                            context,
                            settingsState.preferredTags,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Select Interest Tags'),
                        ),
                      ),
                    _buildSectionHeader('Account'),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.amber),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _showLogoutDialog(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Permanently erase your account, boards, and data',
                      ),
                      onTap: () => _showDeleteAccountDialog(
                        context,
                        isPasswordUser: authUser?.isPasswordProvider ?? false,
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

  Widget _buildProfileHeader(Authenticated? user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: user?.photoUrl != null
              ? NetworkImage(user!.photoUrl!)
              : null,
          child: user?.photoUrl == null
              ? const Icon(Icons.person, size: 50, color: AppColors.primary)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          user?.userName ?? 'InkLink Creator',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          user?.email ?? '',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to sign out of InkLink?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(innerContext);
              context.read<AuthBloc>().add(LogoutRequested());
            },
            child: const Text("Logout", style: TextStyle(color: Colors.amber)),
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
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    "Delete Account",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Are you sure you want to permanently delete your account?\n\n"
                      "This action is irreversible. All your boards, workspaces, and profile will be permanently erased.",
                      style: TextStyle(fontSize: 14),
                    ),
                    if (isPasswordUser) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Please enter your password to confirm:",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          hintText: "Your password",
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
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
                TextButton(
                  onPressed: () => Navigator.pop(innerContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
                  child: const Text("Delete Permanently"),
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
          return AlertDialog(
            title: const Text('Preferred Content Tags'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select topics that match your creative focus to personalize your InkLink experience:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSuggestions.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text('#$tag'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customTagController,
                            decoration: const InputDecoration(
                              hintText: 'Add custom tag...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.add),
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
              TextButton(
                onPressed: () => Navigator.pop(innerContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(innerContext);
                  context.read<SettingsBloc>().add(
                    SettingsPreferredTagsChanged(selectedTags.toList()),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
