import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/view/login_screen.dart';
import 'features/navigation/view/main_wrapper.dart';
import 'features/dashboard/bloc/dashboard_bloc.dart';
import 'features/workspaces/bloc/workspace_bloc.dart';
import 'features/notifications/bloc/notifications_bloc.dart';
import 'features/board_invitations/bloc/board_invitations_bloc.dart';
import 'features/friends/bloc/friends_bloc.dart';
import 'core/services/data_prefetch_service.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous is! Authenticated && current is Authenticated,
      listener: (context, state) {
        // Ensure we're at the root route so the declarative MainWrapper is visible.
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);

        // Phase 4E: Prefetch data on auth
        final authState = state is Authenticated ? state : null;
        if (authState != null) {
          context.read<DataPrefetchService>().prefetchInitialData(
            authState.uid,
          );
        }

        // Restart global syncs when authenticated (crucial after logout/login cycle)
        context.read<DashboardBloc>().add(LoadDashboardRequested());
        context.read<WorkspaceBloc>().add(LoadWorkspacesRequested());
        context.read<NotificationsBloc>().add(
          const NotificationsLoadRequested(),
        );
        context.read<BoardInvitationsBloc>().add(
          const BoardInvitationsLoadRequested(),
        );
        context.read<FriendsBloc>().add(LoadFriendsInfo());
      },
      builder: (context, state) {
        print('[APPVIEW] builder: state=${state.runtimeType} ${state is Authenticated ? "Authenticated" : state is Unauthenticated ? "Unauthenticated" : state is AuthError ? "AuthError(${(state as AuthError).message})" : state is AuthLoading ? "AuthLoading" : state is AuthInitial ? "AuthInitial" : "other"}');
        if (state is Authenticated) {
          return const MainWrapper();
        }

        if (state is Unauthenticated ||
            state is AuthInitial ||
            state is AuthError ||
            state is AuthLoading) {
          return const LoginScreen();
        }
        // While checking session or loading
        return Scaffold(
          body: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
