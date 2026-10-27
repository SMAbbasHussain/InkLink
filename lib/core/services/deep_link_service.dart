import 'dart:ui';
import 'package:flutter/material.dart';
import '../../features/canvas/view/canvas_route.dart';

class DeepLinkService with WidgetsBindingObserver {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  static DeepLinkService get instance => _instance;

  DeepLinkService._internal();

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingBoardId;
  bool _isInitialized = false;

  String? get pendingBoardId => _pendingBoardId;

  /// Initializes deep link listening with the app's root navigator key.
  void initialize({required GlobalKey<NavigatorState> navigatorKey}) {
    if (_isInitialized) return;
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    // Check cold-start launch URI if present
    final defaultRoute = PlatformDispatcher.instance.defaultRouteName;
    if (defaultRoute.isNotEmpty && defaultRoute != '/') {
      final boardId = extractBoardId(defaultRoute);
      if (boardId != null) {
        _pendingBoardId = boardId;
      }
    }
  }

  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
  }

  /// Sets or clears pending board ID (e.g. when unauthenticated on deep link open)
  void setPendingBoardId(String? boardId) {
    _pendingBoardId = boardId;
  }

  /// Consumes and clears the pending board ID (e.g. upon user authentication)
  String? consumePendingBoardId() {
    final id = _pendingBoardId;
    _pendingBoardId = null;
    return id;
  }

  /// Extracts the boardId from deep link URI strings.
  /// Supported schemes:
  /// - `inklink://board/<boardId>`
  /// - `https://inklink.web.app/board/<boardId>`
  /// - `https://inklink.app/board/<boardId>`
  /// - `/board/<boardId>`
  String? extractBoardId(String? rawUri) {
    if (rawUri == null || rawUri.trim().isEmpty) return null;
    final trimmed = rawUri.trim();

    try {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;

      String? boardId;

      // Case 1: Custom scheme inklink://board/<boardId>
      if (uri.scheme == 'inklink') {
        if (uri.host == 'board' && uri.pathSegments.isNotEmpty) {
          boardId = uri.pathSegments.first;
        } else if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'board' &&
            uri.pathSegments.length > 1) {
          boardId = uri.pathSegments[1];
        }
      }
      // Case 2: Web or app links (e.g. https://inklink.web.app/board/<id>)
      else if (uri.scheme == 'http' || uri.scheme == 'https') {
        final segments = uri.pathSegments;
        final boardIndex = segments.indexOf('board');
        if (boardIndex != -1 && boardIndex + 1 < segments.length) {
          boardId = segments[boardIndex + 1];
        }
      }
      // Case 3: Relative path (e.g. /board/<id> or board/<id>)
      else if (trimmed.startsWith('/board/') || trimmed.startsWith('board/')) {
        final sanitized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
        final segments = sanitized.split('/');
        if (segments.length >= 2 && segments[0] == 'board') {
          boardId = segments[1];
        }
      }

      if (boardId != null) {
        // Sanitize: strip query parameters or trailing slashes
        final cleanId = boardId.split('?').first.split('#').first.trim();
        if (cleanId.isNotEmpty) {
          return cleanId;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Directly routes to a board if navigator is ready and context is available
  bool navigateToBoard(String boardId, {BuildContext? context}) {
    final navContext = context ?? _navigatorKey?.currentContext;
    if (navContext == null) {
      _pendingBoardId = boardId;
      return false;
    }

    try {
      Navigator.of(navContext).push(
        buildCanvasRoute(navContext, boardId: boardId),
      );
      return true;
    } catch (_) {
      _pendingBoardId = boardId;
      return false;
    }
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final uri = routeInformation.uri.toString();
    final boardId = extractBoardId(uri);
    if (boardId != null) {
      return navigateToBoard(boardId);
    }
    return super.didPushRouteInformation(routeInformation);
  }

  @override
  Future<bool> didPushRoute(String route) async {
    final boardId = extractBoardId(route);
    if (boardId != null) {
      return navigateToBoard(boardId);
    }
    return super.didPushRoute(route);
  }
}
