import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves the WebSocket/HTTP server URL based on environment configuration
/// and build mode (debug vs release).
///
/// Security & Environment guarantees:
/// 1. In release mode, non-HTTPS/WSS URLs are strictly rejected to prevent
///    tokens from traveling in plaintext (Comment 1).
/// 2. In release mode, emulator and private loopback addresses (e.g. 10.0.2.2)
///    from `.env.example` are rejected so release builds fallback to
///    the secure production endpoint [defaultReleaseUrl] (Comment 4).
/// 3. In debug mode, custom URLs or local emulators are permitted.
String resolveWebSocketUrl([String? configuredUrl]) {
  final rawUrl = (configuredUrl ?? dotenv.env['WEBSOCKET_URL'])?.trim();
  const defaultReleaseUrl = 'https://inklink.app';
  const defaultDebugUrl = 'http://10.0.2.2:3000';

  if (kReleaseMode) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return defaultReleaseUrl;
    }

    final uri = Uri.tryParse(rawUrl);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    final isSecure = scheme == 'https' || scheme == 'wss';
    final host = uri?.host.toLowerCase() ?? '';
    final isLocalHost = host == '10.0.2.2' ||
        host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '10.0.3.2' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.');

    if (!isSecure || isLocalHost) {
      developer.log(
        'Insecure, non-HTTPS, or emulator WEBSOCKET_URL "$rawUrl" rejected in release mode. '
        'Falling back to secure endpoint: $defaultReleaseUrl.',
        name: 'NetworkConfig',
      );
      return defaultReleaseUrl;
    }

    return rawUrl;
  }

  if (rawUrl != null && rawUrl.isNotEmpty) {
    return rawUrl;
  }

  return defaultDebugUrl;
}
