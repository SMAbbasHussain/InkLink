import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ui/theme/ink_theme.dart';
import 'ui/widgets/desk_background.dart';
import 'ui/widgets/ink_logo.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/view/login_screen.dart';
import 'features/auth/view/email_verification_screen.dart';
import 'features/navigation/view/main_wrapper.dart';
import 'features/dashboard/bloc/dashboard_bloc.dart';
import 'features/workspaces/bloc/workspace_bloc.dart';
import 'features/notifications/bloc/notifications_bloc.dart';
import 'features/board_invitations/bloc/board_invitations_bloc.dart';
import 'features/friends/bloc/friends_bloc.dart';
import 'core/services/data_prefetch_service.dart';
import 'core/services/deep_link_service.dart';
import 'domain/services/auth/auth_session_service.dart';
import 'domain/services/chat/chat_service.dart';

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  AuthSessionService? _authSessionService;
  String? _initializedAuthUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AuthSessionService>();
    if (_authSessionService != service) {
      _authSessionService?.unregisterPreSignOutCallback(_stopBlocsForLogout);
      _authSessionService = service;
      _authSessionService?.registerPreSignOutCallback(_stopBlocsForLogout);
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _initializeAuthenticatedSession(authState.uid);
    }
  }

  @override
  void dispose() {
    _authSessionService?.unregisterPreSignOutCallback(_stopBlocsForLogout);
    super.dispose();
  }

  void _initializeAuthenticatedSession(String uid) {
    if (_initializedAuthUid == uid) return;
    _initializedAuthUid = uid;

    // Phase 4E: Prefetch data on auth
    context.read<DataPrefetchService>().prefetchInitialData(uid);

    // Start global syncs when authenticated (both on cold start and after login)
    context.read<DashboardBloc>().add(LoadDashboardRequested());
    context.read<WorkspaceBloc>().add(LoadWorkspacesRequested());
    context.read<NotificationsBloc>().add(
      const NotificationsLoadRequested(),
    );
    context.read<BoardInvitationsBloc>().add(
      const BoardInvitationsLoadRequested(),
    );
    context.read<FriendsBloc>().add(LoadFriendsInfo());
    context.read<ChatService>().login(uid).catchError((e, st) {
      developer.log('ChatService login notice: $e', error: e, stackTrace: st, name: 'AppView');
    });

    // Route to pending deep-linked board if user launched with a deep link
    final pendingBoardId = DeepLinkService.instance.consumePendingBoardId();
    if (pendingBoardId != null && pendingBoardId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          DeepLinkService.instance.navigateToBoard(pendingBoardId, context: context);
        }
      });
    }
  }

  Future<void> _stopBlocsForLogout() async {
    _initializedAuthUid = null;
    if (!mounted) return;
    final friendsBloc = context.read<FriendsBloc>();
    final workspaceBloc = context.read<WorkspaceBloc>();
    final dashboardBloc = context.read<DashboardBloc>();
    final notificationsBloc = context.read<NotificationsBloc>();
    final boardInvitationsBloc = context.read<BoardInvitationsBloc>();
    final chatService = context.read<ChatService>();

    await Future.wait([
      friendsBloc.stopForLogout(),
      workspaceBloc.stopForLogout(),
      dashboardBloc.stopForLogout(),
      notificationsBloc.stopForLogout(),
      boardInvitationsBloc.stopForLogout(),
      chatService.logout(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          (previous is! Authenticated && current is Authenticated) ||
          (previous is Authenticated && current is! Authenticated) ||
          current is AuthEmailUnverified ||
          current is AuthDeletingAccount,
      listener: (context, state) async {
        if (state is AuthDeletingAccount) {
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
        } else if (state is AuthEmailUnverified) {
          // Ensure we pop back to the root route so EmailVerificationScreen is displayed immediately
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
        } else if (state is Authenticated) {
          // Ensure we're at the root route so the declarative MainWrapper is visible.
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);

          _initializeAuthenticatedSession(state.uid);
        } else if (state is Unauthenticated) {
          // Extra safety in case logout happened outside standard authSessionService.signOut
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
          await _stopBlocsForLogout();
        }
      },
      builder: (context, state) {
        if (state is AuthDeletingAccount) {
          final tokens = context.ink;
          return Scaffold(
            body: DeskBackground(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: tokens.danger),
                    const SizedBox(height: 24),
                    Text(
                      "Deleting Account & Data...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Permanently purging boards, memberships, and profile",
                      style: TextStyle(fontSize: 13, color: tokens.inkSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is Authenticated) {
          return const MainWrapper();
        }

        if (state is AuthEmailUnverified) {
          return EmailVerificationScreen(
            user: state.user,
            email: state.email,
          );
        }

        if (state is Unauthenticated ||
            state is AuthError ||
            state is AuthLoading ||
            state is PasswordResetSent) {
          return const LoginScreen();
        }
        // While checking session or loading
        return Builder(
          builder: (context) {
            return Scaffold(
              body: DeskBackground(
                child: Center(
                  child: const InkLogo(size: 96),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
