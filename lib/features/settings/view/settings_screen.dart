import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/core/database/database_service.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/core/utils/tray_tips_preferences.dart';
import 'package:inklink/features/auth/view/login_screen.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_event.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showTrayTips = true;
  bool _loadingTrayTipsPreference = true;

  @override
  void initState() {
    super.initState();
    _loadTrayTipsPreference();
  }

  Future<void> _loadTrayTipsPreference() async {
    final value = await TrayTipsPreferences.getShowTrayTips();
    if (!mounted) return;
    setState(() {
      _showTrayTips = value;
      _loadingTrayTipsPreference = false;
    });
  }

  Future<void> _onTrayTipsToggled(bool value) async {
    setState(() {
      _showTrayTips = value;
    });
    await TrayTipsPreferences.setShowTrayTips(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Canvas tray tips enabled.' : 'Canvas tray tips disabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Get real user data
    final user = context.read<AuthService>().getCurrentUser();

    return BlocListener<AuthBloc, AuthState>(
      // 2. Listen for the Unauthenticated state to navigate away
      listener: (context, state) {
        if (state is Unauthenticated) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: ListView(
          children: [
            const SizedBox(height: 20),

            // 3. Dynamic Profile Header
            _buildProfileHeader(user),

            const SizedBox(height: 30),

            _buildSectionHeader("Appearance"),
            SwitchListTile(
              title: const Text("Dark Mode"),
              secondary: const Icon(Icons.dark_mode),
              value: isDark,
              onChanged: (_) => context.read<ThemeBloc>().add(ToggleTheme()),
            ),

            _buildSectionHeader("Canvas"),
            SwitchListTile(
              title: const Text("Show Tray Tips Overlay"),
              subtitle: const Text(
                "Show tray position helper when creating or joining a board",
              ),
              secondary: const Icon(Icons.lightbulb_outline),
              value: _showTrayTips,
              onChanged: _loadingTrayTipsPreference ? null : _onTrayTipsToggled,
            ),

            _buildSectionHeader("Storage"),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text("Offline Database (Isar)"),
              subtitle: const Text("Tap clear to remove local cached boards"),
              trailing: TextButton(
                onPressed: () => _clearCache(context),
                child: const Text("Clear Cache"),
              ),
            ),

            _buildSectionHeader("Account"),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showLogoutDialog(context), // 4. Proper Logout flow
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: user?.photoURL != null
              ? NetworkImage(user!.photoURL!)
              : null,
          child: user?.photoURL == null
              ? const Icon(Icons.person, size: 50, color: AppColors.primary)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          user?.displayName ?? "InkLink Creator",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          user?.email ?? "",
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

  Future<void> _clearCache(BuildContext context) async {
    try {
      await context.read<DatabaseService>().clearLocalCache();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local cache cleared successfully.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to clear local cache.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
