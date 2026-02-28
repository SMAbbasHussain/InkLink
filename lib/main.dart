import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this
import 'package:inklink/core/theme/app_theme.dart';
import 'package:inklink/domain/repositories/auth_repository_impl.dart'; // Ensure path is correct
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/view/login_screen.dart';
import 'package:inklink/features/navigation/bloc/nav_bloc.dart';
import 'package:inklink/features/theme/bloc/theme_bloc.dart';

// Import generated file (Run 'flutterfire configure' to get this)
// import 'firebase_options.dart'; 

void main() async {
  // 1. Required for any async setup before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  try {
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform, 
    );
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ThemeBloc()),
        BlocProvider(create: (context) => NavBloc()),
        // Inject the Repository into the BLoC
        BlocProvider(
          create: (context) => AuthBloc(
            authRepository: FirebaseAuthRepository(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'InkLink',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const LoginScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}