import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_view.dart';
import '../core/services/deep_link_service.dart';
import '../features/canvas/view/canvas_route.dart';
import '../features/theme/bloc/theme_bloc.dart';
import '../ui/theme/ink_theme.dart';
import '../ui/theme/ink_tokens.dart';
import '../ui/theme/ink_type.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'InkLink',
          theme: InkTheme.light(),
          darkTheme: InkTheme.dark(),
          // Respect System, Light, or Dark mode.
          themeMode: themeMode,
          home: const AppView(),
          onGenerateRoute: (settings) {
            final name = settings.name;
            if (name == null || name.isEmpty) return null;
            final boardId = DeepLinkService.instance.extractBoardId(name);
            if (boardId != null && boardId.isNotEmpty) {
              return buildCanvasRoute(
                appNavigatorKey.currentContext ?? context,
                boardId: boardId,
              );
            }
            return null;
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class InitializationErrorApp extends StatelessWidget {
  final String error;

  const InitializationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: Builder(
        builder: (context) {
          final tokens = context.ink;
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.circleAlert,
                      color: tokens.danger,
                      size: 60,
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    Text(
                      'Failed to initialize app',
                      style: InkType.title(tokens.ink),
                    ),
                    const SizedBox(height: InkSpacing.s8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: InkType.body(tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
