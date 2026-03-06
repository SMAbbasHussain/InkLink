import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/view/login_screen.dart';
import 'features/navigation/view/main_wrapper.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return const MainWrapper();
        }
        
        if (state is Unauthenticated || state is AuthInitial || state is AuthError || state is AuthLoading) {
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
