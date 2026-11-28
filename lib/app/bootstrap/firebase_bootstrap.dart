import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../firebase_options.dart';

/// Loads environment variables from `.env`.
///
/// On mobile, missing `.env` files are tolerated with a debug warning so local
/// runs still boot. On web, `.env` carries public runtime configuration such as
/// `WEBSOCKET_URL`.
Future<void> loadAppEnvironment({
  String fileName = '.env',
  bool ignoreErrors = true,
}) async {
  if (!ignoreErrors) {
    await dotenv.load(fileName: fileName);
    return;
  }
  try {
    await dotenv.load(fileName: fileName);
  } catch (_) {
    debugPrint('Warning: Failed to load $fileName file');
  }
}

/// Initializes the default Firebase app once, safely ignoring duplicate-app
/// races during hot restart or platform re-entry.
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
    Firebase.app();
  }
}
