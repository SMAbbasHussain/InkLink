import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/domain/services/invitation/invitation_service.dart';
import 'package:inklink/domain/repositories/settings/settings_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../board_invitations/bloc/board_invitations_bloc.dart';
import '../../friends/view/friends_screen.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/view/settings_screen.dart';
import '../../dashboard/view/home_screen.dart';
import '../bloc/nav_bloc.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      BlocProvider(
        create: (context) => BoardInvitationsBloc(
          invitationService: context.read<InvitationService>(),
        )..add(const BoardInvitationsLoadRequested()),
        child: const HomeScreen(),
      ),
      const FriendsScreen(),
      BlocProvider(
        create: (context) =>
            SettingsBloc(settingsRepository: context.read<SettingsRepository>())
              ..add(const SettingsLoadRequested()),
        child: const SettingsScreen(),
      ),
    ];

    return BlocBuilder<NavBloc, NavState>(
      builder: (context, state) {
        return Scaffold(
          body: IndexedStack(index: state.index, children: screens),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              // This creates the capsule/pill behind the icon
              indicatorColor: AppColors.primary.withOpacity(0.2),
              labelTextStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            child: NavigationBar(
              selectedIndex: state.index,
              onDestinationSelected: (index) =>
                  context.read<NavBloc>().add(ChangeTab(index)),
              destinations: const [
                NavigationDestination(
                  selectedIcon: Icon(
                    Icons.home_filled,
                    color: AppColors.primary,
                  ),
                  icon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.people, color: AppColors.primary),
                  icon: Icon(Icons.people_outline),
                  label: 'Friends',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.settings, color: AppColors.primary),
                  icon: Icon(Icons.settings_outlined),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
