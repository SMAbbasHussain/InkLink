import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/data/web_companion_repository.dart';
import 'package:inklink/web/preview/sample_web_repository.dart';
import 'package:inklink/web/web_companion_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sign-up and the board-link sign-in note, plus the accessible name the
/// boards grid exposes for each card and the share metadata the page ships.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // The sample repository fakes its network delay (400 ms for sign-in), so
  // give animations and futures a full second to land.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpSignedOut(
    WidgetTester tester, {
    String? initialBoardId,
    WebCompanionRepository? repository,
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WebCompanionApp(
        repository: repository ?? SampleWebCompanionRepository(signedIn: false),
        themeMode: ThemeMode.light,
        initialBoardId: initialBoardId,
      ),
    );
    await settle(tester);
  }

  testWidgets('sign-in offers account creation and switches back', (
    tester,
  ) async {
    await pumpSignedOut(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await settle(tester);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
    // Google sign-in stays in the sign-in form: its popup requires an
    // existing InkLink profile.
    expect(find.text('Continue with Google'), findsNothing);

    await tester.tap(find.text('Sign in').last);
    await settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('creating an account needs a name', (tester) async {
    await pumpSignedOut(tester);
    await tester.tap(find.text('Create an account'));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).at(1), 'Rae Chen');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret12');
    // No name: the form refuses before calling the backend.
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.text('Create account'));
    await settle(tester);

    expect(find.text('Please enter your name.'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('a short password is refused locally', (tester) async {
    await pumpSignedOut(tester);
    await tester.tap(find.text('Create an account'));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Rae Chen');
    await tester.enterText(find.byType(TextFormField).at(1), 'rae@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '123');
    await tester.tap(find.text('Create account'));
    await settle(tester);

    expect(find.text('Use at least 6 characters for your password.'), findsOne);
  });

  testWidgets('a new account must verify its email, then reaches the app', (
    tester,
  ) async {
    await pumpSignedOut(tester);

    await tester.tap(find.text('Create an account'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Rae Chen');
    await tester.enterText(find.byType(TextFormField).at(1), 'rae@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret12');
    await tester.tap(find.text('Create account'));
    await settle(tester);

    // Firebase password accounts start unverified, so the gate asks for the
    // email to be verified before the pages appear.
    expect(find.text('Verify your email'), findsOneWidget);

    await tester.tap(find.text("I've verified"));
    await settle(tester);
    expect(find.text('Ready to bring your ideas to life?'), findsOneWidget);
  });

  testWidgets('an existing email is reported by the repository', (
    tester,
  ) async {
    await pumpSignedOut(tester);
    await tester.tap(find.text('Create an account'));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Sam Rivera');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'sam.rivera@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret12');
    await tester.tap(find.text('Create account'));
    await settle(tester);

    expect(
      find.text('An account already exists for that email. Sign in instead.'),
      findsOne,
    );
  });

  testWidgets('a board link says a board is waiting and opens it after signing '
      'in', (tester) async {
    await pumpSignedOut(tester, initialBoardId: 'b5');

    expect(find.textContaining('A board is waiting for you'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'sam.rivera@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret12');
    await tester.tap(find.text('Sign in'));
    await settle(tester);

    // The sample preview has no canvas route, so the deep link reports the
    // board id instead of opening it (the real app opens the canvas).
    expect(
      find.text('Open this board in the InkLink app: b5'),
      findsOneWidget,
    );
  });

  testWidgets('board cards have a descriptive accessible name', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WebCompanionApp(
        repository: SampleWebCompanionRepository(),
        themeMode: ThemeMode.light,
      ),
    );
    await settle(tester);

    expect(
      find.bySemanticsLabel(RegExp(r'^Board Q3 roadmap\. #planning #team')),
      findsOneWidget,
    );
    // The card's menu button keeps its own name inside the card node.
    expect(find.byTooltip('Board options'), findsWidgets);
    // Disposed here: the framework checks handles before tear-downs run.
    handle.dispose();
  });

  test('the page ships link-preview metadata', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('property="og:title"'));
    expect(html, contains('property="og:description"'));
    expect(html, contains('property="og:image"'));
    expect(html, contains('name="twitter:card"'));
  });
}
