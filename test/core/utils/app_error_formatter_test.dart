import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/app_error_formatter.dart';

void main() {
  group('AppErrorFormatter', () {
    test('formats null error safely', () {
      final details = AppErrorFormatter.format(null);
      expect(details.title, equals('Unknown Error'));
      expect(details.message, contains('unexpected issue occurred'));
      expect(AppErrorFormatter.cleanMessage(null, fallback: 'Fallback message'), equals('Fallback message'));
    });

    test('formats FirebaseAuthException with invalid-credential', () {
      final ex = FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The supplied auth credential is incorrect, malformed or has expired.',
      );
      final details = AppErrorFormatter.format(ex);
      expect(details.title, equals('Invalid Credentials'));
      expect(details.message, contains('email address or password you entered is incorrect'));
      expect(details.message, isNot(contains('firebase_auth')));
    });

    test('formats raw string matching user screenshot', () {
      const raw =
          '[firebase_auth/invalid-credential] The supplied auth credential is incorrect, malformed or has expired.';
      final details = AppErrorFormatter.format(raw);
      expect(details.title, equals('Invalid Credentials'));
      expect(details.message, contains('email address or password you entered is incorrect'));
      expect(details.message, isNot(contains('firebase_auth')));
      expect(details.message, isNot(contains('[invalid-credential]')));
    });

    test('formats other common FirebaseAuth codes', () {
      final userNotFound = FirebaseAuthException(code: 'user-not-found');
      expect(AppErrorFormatter.format(userNotFound).title, equals('Account Not Found'));

      final emailInUse = FirebaseAuthException(code: 'email-already-in-use');
      expect(AppErrorFormatter.format(emailInUse).title, equals('Email Already Registered'));

      final weakPw = FirebaseAuthException(code: 'weak-password');
      expect(AppErrorFormatter.format(weakPw).title, equals('Password Too Weak'));

      final tooMany = FirebaseAuthException(code: 'too-many-requests');
      expect(AppErrorFormatter.format(tooMany).title, equals('Too Many Attempts'));
    });

    test('formats FirebaseException for Firestore / Storage', () {
      final permDenied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      final details = AppErrorFormatter.format(permDenied);
      expect(details.title, equals('Access Denied'));
      expect(details.message, contains('permission'));
      expect(details.message, isNot(contains('cloud_firestore')));
    });

    test('formats raw string matching cloud_firestore permission-denied', () {
      const raw = '[cloud_firestore/permission-denied] Missing or insufficient permissions.';
      final details = AppErrorFormatter.format(raw);
      expect(details.title, equals('Access Denied'));
      expect(details.message, isNot(contains('cloud_firestore')));
    });

    test('formats PlatformException cleanly', () {
      final ex = PlatformException(
        code: 'sign_in_canceled',
        message: 'User cancelled Google sign in',
      );
      final details = AppErrorFormatter.format(ex);
      expect(details.title, equals('Sign-in Cancelled'));
      expect(details.message, equals('Sign-in was cancelled.'));
    });

    test('formats SocketException / network errors cleanly', () {
      const ex = SocketException('Failed host lookup: googleapis.com');
      final details = AppErrorFormatter.format(ex);
      expect(details.title, equals('Connection Issue'));
      expect(details.message, contains('internet connection'));
    });

    test('strips stack traces and Exception prefix from unknown exceptions', () {
      const raw = 'Exception: Something went sideways in the worker\n#0 runWorker (worker.dart:12)';
      final details = AppErrorFormatter.format(raw);
      expect(details.message, equals('Something went sideways in the worker.'));
      expect(details.message, isNot(contains('Exception:')));
      expect(details.message, isNot(contains('#0')));
    });

    test('cleanMessage returns clean string without title', () {
      final msg = AppErrorFormatter.cleanMessage(
        FirebaseAuthException(code: 'invalid-email'),
      );
      expect(msg, contains('email address format is not valid'));
      expect(msg, isNot(contains('Invalid Email Address:')));
    });
  });
}

