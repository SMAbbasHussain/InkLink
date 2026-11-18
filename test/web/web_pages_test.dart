import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/web/preview/sample_web_repository.dart';
import 'package:inklink/web/web_companion_app.dart';

/// Renders the web companion's signed-in pages from sample data (no
/// Firebase) on a desktop-sized screen and checks the main content. The
/// pages use the mobile app's design (Ink theme, desk background, glass nav
/// bar), so navigation is by the nav bar and header buttons' tooltips.
void main() {
  Future<void> pumpApp(WidgetTester tester, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WebCompanionApp(
        repository: SampleWebCompanionRepository(signedIn: signedIn),
        themeMode: ThemeMode.light,
      ),
    );
    await settle(tester);
  }

  Finder tooltipStartingWith(String text) => find.byWidgetPredicate(
    (w) => w is Tooltip && (w.message ?? '').startsWith(text),
  );

  Future<void> openSection(WidgetTester tester, String label) async {
    if (label == 'Profile') {
      await tester.tap(find.byTooltip('Account'));
      await settle(tester);
      await tester.tap(find.text('Your profile'));
    } else {
      await tester.tap(tooltipStartingWith(label).first);
    }
    await settle(tester);
  }

  testWidgets('boards page: greeting, invite note and the board tabs', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Ready to bring your ideas to life?'), findsOneWidget);
    // The sticky note for the waiting board invite.
    expect(find.textContaining('invited to a board'), findsOneWidget);
    // My Boards: owned and not archived.
    expect(find.text('Q3 roadmap'), findsOneWidget);
    expect(find.text('Landing page wireframes'), findsOneWidget);
    expect(find.text('Sprint retro'), findsNothing);
    expect(find.text('Old brainstorm'), findsNothing);

    await tester.tap(find.text('Joined'));
    await settle(tester);
    expect(find.text('Sprint retro'), findsOneWidget);
    expect(find.text('Q3 roadmap'), findsNothing);

    await tester.tap(find.text('Archived'));
    await settle(tester);
    expect(find.text('Old brainstorm'), findsOneWidget);
  });

  testWidgets('search filters boards by title or tag', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'art');
    await settle(tester);
    expect(find.text('Character sketches'), findsOneWidget);
    expect(find.text('Q3 roadmap'), findsNothing);
  });

  testWidgets('discover lists public boards and filters by tag', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSection(tester, 'Discover');
    expect(find.text('Explore Public Boards'), findsOneWidget);
    expect(find.text('City sketch walk'), findsOneWidget);
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
    // The invite note is gone (the confirmation message names the board).
    expect(
      find.textContaining('invited you to "Open-source logo jam"'),
      findsNothing,
    );
    expect(find.text('No board invites'), findsOneWidget);
  });

  testWidgets('friends: request and friend list', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Friends');
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('Alex Kim'), findsOneWidget);
    await tester.tap(find.text('Accept').first);
    await settle(tester);
    expect(find.text('No pending requests'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget); // now a friend
  });

  testWidgets('notifications are grouped and use sender initials', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSection(tester, 'Notifications');
    // Sample times are relative to now, so the newest items are "Today" or
    // (just after midnight) "This week"; the 9-day-old one is always earlier.
    expect(
      find.text('Today').evaluate().length +
          find.text('This week').evaluate().length,
      greaterThan(0),
    );
    expect(find.text('Earlier'), findsOneWidget);
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

  testWidgets('the header switches between light and dark', (tester) async {
    await pumpApp(tester);
    expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await settle(tester);
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
  });

  testWidgets('signed out shows sign-in, and signing in opens the boards', (
    tester,
  ) async {
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
