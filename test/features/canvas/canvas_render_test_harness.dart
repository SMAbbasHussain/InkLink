import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/canvas_screen.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hosts the real `CanvasScreen` for render tests.
///
/// The screen only needs its canvas bloc for drawing; the notifications bloc is
/// part of its widget contract, so it is supplied with fakes rather than
/// pulled in for real.
Widget canvasScreenHost({
  required CanvasBloc bloc,
  required SharedPreferences prefs,
}) {
  return MaterialApp(
    theme: InkTheme.light(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<CanvasBloc>.value(value: bloc),
        BlocProvider<NotificationsBloc>(
          create: (_) => NotificationsBloc(
            notificationService: FakeNotificationService(),
            notificationPreferences: NotificationPreferences(prefs: prefs),
          ),
        ),
      ],
      child: const CanvasScreen(boardId: 'board-1'),
    ),
  );
}

/// Stands in for the notification service; render tests never notify.
class FakeNotificationService extends Fake implements NotificationService {}

/// Leaves every font request pending.
///
/// google_fonts validates the fetched bytes against an expected hash, so a
/// substituted local font is rejected, and a failed fetch throws into the test
/// zone. A request that never completes simply leaves the app chrome on its
/// deterministic fallback face — nothing is fetched, nothing throws.
class PendingFontHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _PendingFontHttpClient();
}

class _PendingFontHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #openUrl || name == #getUrl || name == #postUrl) {
      return Completer<HttpClientRequest>().future;
    }
    if (name == #close) return null;
    return Future<dynamic>.value(null);
  }
}
