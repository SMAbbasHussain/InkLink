import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/auth/view/login_screen.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_event.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:inklink/features/settings/bloc/settings_bloc.dart';
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
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is Unauthenticated) {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
          },
        ),
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
                      title: const Text('Offline Database (Isar)'),
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
                    _buildSectionHeader('Account'),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _showLogoutDialog(context),
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
              // 5. Dispatch the logout event to the BLoC
              context.read<AuthBloc>().add(LogoutRequested());
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
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
