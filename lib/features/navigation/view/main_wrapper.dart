import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/domain/services/presence/presence_service.dart';
import 'package:inklink/domain/services/settings/settings_service.dart';
import 'package:inklink/domain/services/profile/profile_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../ui/widgets/glass_nav_bar.dart';
import '../../friends/view/friends_screen.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/view/settings_screen.dart';
import '../../dashboard/view/home_screen.dart';
import '../../workspaces/view/workspaces_screen.dart';
import '../bloc/nav_bloc.dart';

const _navItems = [
  GlassNavItem(
    activeIcon: LucideIcons.house,
    inactiveIcon: LucideIcons.house,
    label: 'Home',
  ),
  GlassNavItem(
    activeIcon: LucideIcons.users,
    inactiveIcon: LucideIcons.users,
    label: 'Friends',
  ),
  GlassNavItem(
    activeIcon: LucideIcons.layoutGrid,
    inactiveIcon: LucideIcons.layoutGrid,
    label: 'Workspaces',
  ),
  GlassNavItem(
    activeIcon: LucideIcons.slidersHorizontal,
    inactiveIcon: LucideIcons.slidersHorizontal,
    label: 'Settings',
  ),
];

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver {
  bool _presenceActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnlineIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOfflineIfNeeded();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnlineIfNeeded();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOfflineIfNeeded();
        break;
    }
  }

  Future<void> _setOnlineIfNeeded() async {
    if (_presenceActive || !mounted) return;
    _presenceActive = true;
    try {
      await context.read<PresenceService>().setUserOnline();
    } catch (e, st) {
      developer.log(
        'Lifecycle presence online update failed: $e',
        name: 'MainWrapper',
        stackTrace: st,
      );
    }
  }

  Future<void> _setOfflineIfNeeded() async {
    if (!_presenceActive) return;
    _presenceActive = false;
    try {
      await context.read<PresenceService>().setUserOffline();
    } catch (e, st) {
      developer.log(
        'Lifecycle presence offline update failed: $e',
        name: 'MainWrapper',
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      const FriendsScreen(),
      const WorkspacesScreen(),
      BlocProvider(
        create: (context) =>
            SettingsBloc(
              settingsService: context.read<SettingsService>(),
              profileService: context.read<ProfileService>(),
            )
              ..add(const SettingsLoadRequested()),
        child: const SettingsScreen(),
      ),
    ];

    return BlocBuilder<NavBloc, NavState>(
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(index: state.index, children: screens),
              Align(
                alignment: Alignment.bottomCenter,
                child: GlassNavBar(
                  items: _navItems,
                  currentIndex: state.index,
                  onTap: (index) =>
                      context.read<NavBloc>().add(ChangeTab(index)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
