import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/preview/sample_web_repository.dart';
import 'package:inklink/web/web_companion_app.dart';

/// Renders the web companion's signed-in pages from sample data (no
/// Firebase) on a desktop-sized screen and checks the main content.
void main() {
  Future<void> pumpApp(WidgetTester tester, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WebCompanionApp(
      repository: SampleWebCompanionRepository(signedIn: signedIn),
      themeMode: ThemeMode.light,
    ));
    await settle(tester);
  }

  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await settle(tester);
  }

  testWidgets('boards page: greeting, stats and board cards', (tester) async {
    await pumpApp(tester);
    // The greeting draws the first name separately (gradient text).
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('invites waiting'), findsOneWidget);
    expect(find.text('Q3 roadmap'), findsOneWidget);
    expect(find.text('Landing page wireframes'), findsOneWidget);
    // Archived boards are hidden under "All".
    expect(find.text('Old brainstorm'), findsNothing);
  });

  testWidgets('search filters boards by title or tag', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'art');
    await settle(tester);
    expect(find.text('Character sketches'), findsOneWidget);
    expect(find.text('Q3 roadmap'), findsNothing);
  });

  testWidgets('discover labels public boards correctly and filters by tag',
      (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Discover');
    expect(find.text('City sketch walk'), findsOneWidget);
    expect(find.text('Public'), findsWidgets);
    await tester.tap(find.text('#study').first); // the filter chip
    await settle(tester);
    expect(find.text('Physics study notes'), findsOneWidget);
    expect(find.text('City sketch walk'), findsNothing);
  });

  testWidgets('invites can be accepted', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Invites');
    expect(find.textContaining('Open-source logo jam'), findsOneWidget);
    await tester.tap(find.text('Accept').first);
    await settle(tester);
    // The invite row is gone (the confirmation message still names the board).
    expect(find.textContaining('invited you to "Open-source logo jam"'), findsNothing);
    expect(find.text('No board invites'), findsOneWidget);
  });

  testWidgets('friends: request and friend cards', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Friends');
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('Alex Kim'), findsOneWidget);
    await tester.tap(find.text('Accept').first);
    await settle(tester);
    expect(find.text('No pending requests'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget); // now a friend
  });

  testWidgets('notifications are grouped and use sender initials',
      (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Notifications');
    // Sample times are relative to now, so the newest items are "Today" or
    // (just after midnight) "This week"; the 9-day-old one is always earlier.
    expect(
      find.text('TODAY').evaluate().length + find.text('THIS WEEK').evaluate().length,
      greaterThan(0),
    );
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('PS'), findsOneWidget); // Priya Shah
  });

  testWidgets('profile can be edited', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Profile');
    expect(find.text('Member since'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Hello from the web');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Hello from the web'), findsOneWidget);
  });

  testWidgets('signed out shows sign-in, and signing in opens the boards',
      (tester) async {
    await pumpApp(tester, signedIn: false);
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'sam@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('Sign in'));
    await settle(tester);
    expect(find.text('Q3 roadmap'), findsOneWidget);
  });
}

/// Pumps frames for a while (pages contain looping animations, so
/// pumpAndSettle could wait forever).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
