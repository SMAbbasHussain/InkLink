import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

/// User-facing error representation with a clear title and actionable message.
class AppErrorDetails {
  final String title;
  final String message;

  const AppErrorDetails({
    required this.title,
    required this.message,
  });

  @override
  String toString() => '$title: $message';
}

/// Centralized utility that converts raw Firebase, network, or platform
/// exceptions into clear, human-friendly titles and explanations.
///
/// Strips out all stack traces, raw error codes (e.g. `[firebase_auth/...]`),
/// and internal jargon across the entire application.
class AppErrorFormatter {
  const AppErrorFormatter._();

  /// Formats any error object or exception string into an [AppErrorDetails].
  static AppErrorDetails format(dynamic error) {
    if (error == null) {
      return const AppErrorDetails(
        title: 'Unknown Error',
        message: 'An unexpected issue occurred. Please try again.',
      );
    }

    // 1. Direct FirebaseAuthException
    if (error is FirebaseAuthException) {
      return _mapAuthCode(error.code, error.message);
    }

    // 2. Direct FirebaseException (Firestore, Storage, Functions, etc.)
    if (error is FirebaseException) {
      return _mapFirebaseCode(error.code, error.message);
    }

    // 3. PlatformException
    if (error is PlatformException) {
      return _mapPlatformException(error);
    }

    // 4. Network / Socket / Timeout exceptions
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return const AppErrorDetails(
        title: 'Connection Issue',
        message:
            'Unable to communicate with the server. Please check your internet connection and try again.',
      );
    }

    // 5. String-based parsing (when error has already been converted to string)
    final rawText = error.toString().trim();
    return _parseStringError(rawText);
  }

  /// Returns only the user-friendly message for SnackBars or inline displays.
  static String cleanMessage(dynamic error, {String? fallback}) {
    if (error == null && fallback != null) return fallback;
    final formatted = format(error);
    if (fallback != null &&
        (formatted.message.contains('unexpected issue occurred') ||
            formatted.message.contains('Something went wrong'))) {
      return fallback;
    }
    return formatted.message;
  }

  /// Returns only the title.
  static String cleanTitle(dynamic error) {
    return format(error).title;
  }

  // ──────────────────────────────────────────────
  // Firebase Auth Error Code Mapping
  // ──────────────────────────────────────────────

  static AppErrorDetails _mapAuthCode(String code, [String? rawMessage]) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
        return const AppErrorDetails(
          title: 'Invalid Credentials',
          message:
              'The email address or password you entered is incorrect. Please check your credentials and try again, or use "Forgot Password?" to reset it.',
        );

      case 'user-not-found':
        return const AppErrorDetails(
          title: 'Account Not Found',
          message:
              'No account was found with this email address. Please check for spelling mistakes or create a new account.',
        );

      case 'invalid-email':
        return const AppErrorDetails(
          title: 'Invalid Email Address',
          message:
              'The email address format is not valid. Please enter a valid email address (e.g. name@example.com).',
        );

      case 'email-already-in-use':
        return const AppErrorDetails(
          title: 'Email Already Registered',
          message:
              'An account is already registered with this email address. Please sign in instead, or reset your password if you forgot it.',
        );

      case 'weak-password':
        return const AppErrorDetails(
          title: 'Password Too Weak',
          message:
              'The password you entered is too weak. Please use at least 6 characters with a combination of letters and numbers.',
        );

      case 'too-many-requests':
        return const AppErrorDetails(
          title: 'Too Many Attempts',
          message:
              'Access to this account has been temporarily disabled due to multiple failed attempts. Please wait a few moments and try again, or reset your password.',
        );

      case 'user-disabled':
        return const AppErrorDetails(
          title: 'Account Disabled',
          message:
              'This account has been disabled. Please contact support if you believe this is a mistake.',
        );

      case 'operation-not-allowed':
        return const AppErrorDetails(
          title: 'Sign-in Disabled',
          message:
              'Sign-in with this method is currently disabled. Please contact support.',
        );

      case 'account-exists-with-different-credential':
        return const AppErrorDetails(
          title: 'Account Exists',
          message:
              'An account already exists with this email address using a different sign-in method. Please sign in using your original method.',
        );

      case 'requires-recent-login':
        return const AppErrorDetails(
          title: 'Recent Sign-in Required',
          message:
              'This security-sensitive action requires a recent sign-in. Please log out, sign in again, and retry.',
        );

      case 'network-request-failed':
        return const AppErrorDetails(
          title: 'Network Error',
          message:
              'Unable to reach authentication servers. Please verify your internet connection and try again.',
        );

      case 'expired-action-code':
        return const AppErrorDetails(
          title: 'Link Expired',
          message:
              'The password reset or verification link has expired. Please request a new link.',
        );

      case 'invalid-action-code':
        return const AppErrorDetails(
          title: 'Invalid Link',
          message:
              'The link is invalid or has already been used. Please request a new one.',
        );

      case 'missing-google-token':
      case 'google-sign-in-failed':
        return const AppErrorDetails(
          title: 'Google Sign-in Failed',
          message:
              'Could not complete Google sign-in. Please try again or use your email and password.',
        );

      default:
        return AppErrorDetails(
          title: 'Authentication Error',
          message: _sanitizeFallback(
            rawMessage,
            defaultMsg:
                'We could not verify your credentials. Please double check your details and try again.',
          ),
        );
    }
  }

  // ──────────────────────────────────────────────
  // Firestore / Storage / General Firebase Error Codes
  // ──────────────────────────────────────────────

  static AppErrorDetails _mapFirebaseCode(String code, [String? rawMessage]) {
    switch (code) {
      case 'permission-denied':
        return const AppErrorDetails(
          title: 'Access Denied',
          message:
              'You do not have permission to perform this action. Request access or check with the board owner.',
        );

      case 'unavailable':
        return const AppErrorDetails(
          title: 'Service Temporarily Unavailable',
          message:
              'The service is currently unreachable or your device is offline. Please check your connection and try again.',
        );

      case 'not-found':
        return const AppErrorDetails(
          title: 'Item Not Found',
          message:
              'The requested item or board could not be found. It may have been deleted or moved.',
        );

      case 'already-exists':
        return const AppErrorDetails(
          title: 'Already Exists',
          message:
              'An item with this name or identifier already exists. Please choose a different one.',
        );

      case 'resource-exhausted':
      case 'quota-exceeded':
        return const AppErrorDetails(
          title: 'Limit Reached',
          message:
              'The server quota or rate limit has been reached. Please wait a moment before trying again.',
        );

      case 'deadline-exceeded':
        return const AppErrorDetails(
          title: 'Request Timed Out',
          message:
              'The operation took too long to complete. Please check your internet connection and try again.',
        );

      case 'unauthenticated':
        return const AppErrorDetails(
          title: 'Session Expired',
          message:
              'Your session has expired. Please sign in again to continue.',
        );

      case 'cancelled':
        return const AppErrorDetails(
          title: 'Operation Cancelled',
          message: 'The operation was cancelled before completion.',
        );

      default:
        return AppErrorDetails(
          title: 'Server Error',
          message: _sanitizeFallback(
            rawMessage,
            defaultMsg: 'Something went wrong while communicating with the server. Please try again.',
          ),
        );
    }
  }

  // ──────────────────────────────────────────────
  // PlatformException Mapping
  // ──────────────────────────────────────────────

  static AppErrorDetails _mapPlatformException(PlatformException e) {
    final code = e.code.toLowerCase();
    if (code.contains('sign_in_canceled') || code.contains('canceled')) {
      return const AppErrorDetails(
        title: 'Sign-in Cancelled',
        message: 'Sign-in was cancelled.',
      );
    }
    if (code.contains('network') || code.contains('socket')) {
      return const AppErrorDetails(
        title: 'Network Issue',
        message: 'Could not connect. Please check your internet connection and try again.',
      );
    }
    return AppErrorDetails(
      title: 'Action Failed',
      message: _sanitizeFallback(
        e.message,
        defaultMsg: 'The requested action could not be completed. Please try again.',
      ),
    );
  }

  // ──────────────────────────────────────────────
  // String Pattern Extraction
  // ──────────────────────────────────────────────

  static AppErrorDetails _parseStringError(String raw) {
    // 1. Strip stack traces if present (split on newline or "#0")
    var clean = raw;
    if (clean.contains('\n')) {
      clean = clean.split('\n').first.trim();
    }
    if (clean.contains('#0')) {
      clean = clean.split('#0').first.trim();
    }

    // 2. Check for [firebase_auth/<code-name>] pattern
    final authRegex = RegExp(r'\[firebase_auth\/([a-zA-Z0-9\-_]+)\]');
    final authMatch = authRegex.firstMatch(clean);
    if (authMatch != null) {
      final code = authMatch.group(1)!;
      return _mapAuthCode(code, clean);
    }

    // 3. Check for [cloud_firestore/<code-name>] pattern
    final firestoreRegex =
        RegExp(r'\[(?:cloud_firestore|firebase_storage|firebase_functions)\/([a-zA-Z0-9\-_]+)\]');
    final firestoreMatch = firestoreRegex.firstMatch(clean);
    if (firestoreMatch != null) {
      final code = firestoreMatch.group(1)!;
      return _mapFirebaseCode(code, clean);
    }

    // 4. Keyword heuristics for common errors
    final lower = clean.toLowerCase();
    if (lower.contains('invalid-credential') ||
        lower.contains('wrong-password') ||
        lower.contains('incorrect password') ||
        lower.contains('invalid password') ||
        lower.contains('auth credential is incorrect')) {
      return _mapAuthCode('invalid-credential');
    }

    if (lower.contains('user-not-found') ||
        lower.contains('no account found') ||
        lower.contains('no user record')) {
      return _mapAuthCode('user-not-found');
    }

    if (lower.contains('email-already-in-use') ||
        lower.contains('email already registered')) {
      return _mapAuthCode('email-already-in-use');
    }

    if (lower.contains('invalid-email') ||
        lower.contains('badly formatted')) {
      return _mapAuthCode('invalid-email');
    }

    if (lower.contains('permission-denied') ||
        lower.contains('missing or insufficient permissions') ||
        lower.contains('permission denied')) {
      return _mapFirebaseCode('permission-denied');
    }

    if (lower.contains('too-many-requests') ||
        lower.contains('blocked all requests')) {
      return _mapAuthCode('too-many-requests');
    }

    if (lower.contains('network-request-failed') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network error') ||
        lower.contains('clientexception')) {
      return const AppErrorDetails(
        title: 'Connection Issue',
        message:
            'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }

    // 5. General cleanup: strip "Exception: ", "PlatformException(...)", etc.
    clean = clean.replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'^Error:\s*', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'^PlatformException\([^)]*\)\s*'), '');
    clean = clean.replaceAll(RegExp(r'\[.*?\]\s*'), ''); // strip any remaining [tags]
    clean = clean.trim();

    if (clean.isEmpty) {
      return const AppErrorDetails(
        title: 'Unexpected Error',
        message: 'Something went wrong. Please try again.',
      );
    }

    // Ensure it looks like a clean sentence
    final firstChar = clean[0].toUpperCase();
    var sanitized = firstChar + clean.substring(1);
    if (!sanitized.endsWith('.') && !sanitized.endsWith('!') && !sanitized.endsWith('?')) {
      sanitized += '.';
    }

    return AppErrorDetails(
      title: 'Notice',
      message: sanitized,
    );
  }

  static String _sanitizeFallback(String? raw, {required String defaultMsg}) {
    if (raw == null || raw.trim().isEmpty) return defaultMsg;
    var clean = raw;
    if (clean.contains('\n')) clean = clean.split('\n').first.trim();
    if (clean.contains('#0')) clean = clean.split('#0').first.trim();
    clean = clean.replaceAll(RegExp(r'\[.*?\]\s*'), '');
    clean = clean.replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '');
    clean = clean.trim();
    if (clean.isEmpty || clean.length > 200 || clean.contains('http') || clean.contains('sdk')) {
      return defaultMsg;
    }
    return clean.endsWith('.') ? clean : '$clean.';
  }
}
