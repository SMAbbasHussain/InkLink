import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/ui/widgets/ink_button.dart';
import 'package:inklink/ui/widgets/ink_chip.dart';
import 'package:inklink/web/data/web_companion_repository.dart';
import 'package:inklink/web/preview/sample_web_repository.dart';
import 'package:inklink/web/web_companion_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the web companion's signed-in pages from sample data (no
/// Firebase) on a desktop-sized screen and checks the main content. The
/// pages use the mobile app's design (Ink theme, desk background, cards) in
/// a desktop layout: top bar and labelled sidebar.
void main() {
  setUp(() {
    // The settings page reads and writes browser-stored preferences.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    bool signedIn = true,
    Size size = const Size(1440, 900),
    WebCompanionRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WebCompanionApp(
        repository:
            repository ?? SampleWebCompanionRepository(signedIn: signedIn),
        themeMode: ThemeMode.light,
      ),
    );
    await settle(tester);
  }

  String roleOf(WidgetTester tester, String uid) =>
      tester.widget<Text>(find.byKey(ValueKey('member-role-$uid'))).data!;

  // Desktop width: sections are in the labelled sidebar.
  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await settle(tester);
  }

  Future<void> openWorkspace(WidgetTester tester, String name) async {
    await openSection(tester, 'Workspaces');
    await tester.tap(find.text(name).first);
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

  testWidgets('workspaces: list, open one to see its boards, go back', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSection(tester, 'Workspaces');
    expect(find.text('Product Team'), findsOneWidget);
    expect(find.text('Home Projects'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('4 members • 3 boards'), findsOneWidget);

    // Search narrows the list.
    await tester.enterText(find.byType(TextField).first, 'home');
    await settle(tester);
    expect(find.text('Product Team'), findsNothing);
    expect(find.text('Home Projects'), findsOneWidget);

    // Opening a workspace shows only its boards as board cards.
    await tester.tap(find.text('Home Projects'));
    await settle(tester);
    expect(find.text('Kitchen remodel ideas'), findsOneWidget);
    expect(find.text('Q3 roadmap'), findsNothing);
    expect(find.byTooltip('Board options'), findsOneWidget);

    await tester.tap(find.text('Workspaces').last); // back button
    await settle(tester);
    expect(find.text('Home Projects'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small windows use the phone nav bar instead of the sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WebCompanionApp(
        repository: SampleWebCompanionRepository(),
        themeMode: ThemeMode.light,
      ),
    );
    await settle(tester);
    expect(find.text('Notifications'), findsNothing); // no sidebar labels
    await tester.tap(find.byTooltip('Discover'));
    await settle(tester);
    expect(find.text('Explore Public Boards'), findsOneWidget);
    await tester.tap(find.byTooltip('Workspaces'));
    await settle(tester);
    expect(find.text('Product Team'), findsOneWidget);
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

  // ── Board lifecycle ────────────────────────────────────────────────────

  testWidgets('a board can be created from the web', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New board'));
    await settle(tester);
    // The button and the dialog title share the label.
    expect(find.text('New board'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).last, 'Fresh ideas');
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(find.text('Board created.'), findsOneWidget);
    expect(find.text('Fresh ideas'), findsOneWidget);
  });

  testWidgets('a board can be renamed from its card menu', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Board options').first);
    await settle(tester);
    await tester.tap(find.text('Rename'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).last, 'Roadmap 2027');
    await tester.tap(find.text('Rename').last);
    await settle(tester);

    expect(find.text('Board renamed.'), findsOneWidget);
    expect(find.text('Roadmap 2027'), findsOneWidget);
    expect(find.text('Q3 roadmap'), findsNothing);
  });

  testWidgets('a board can be archived and restored', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Board options').first);
    await settle(tester);
    await tester.tap(find.text('Archive'));
    await settle(tester);

    expect(find.text('Board archived.'), findsOneWidget);
    expect(find.text('Q3 roadmap'), findsNothing);

    await tester.tap(find.text('Archived'));
    await settle(tester);
    expect(find.text('Q3 roadmap'), findsOneWidget);

    await tester.tap(find.byTooltip('Board options').first);
    await settle(tester);
    await tester.tap(find.text('Unarchive'));
    await settle(tester);
    expect(find.text('Board restored.'), findsOneWidget);
  });

  testWidgets('a board can be tagged and its settings changed', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Board options').first);
    await settle(tester);
    await tester.tap(find.text('Tags'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Roadmap, Team');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Tags updated.'), findsOneWidget);
    expect(find.textContaining('#roadmap #team'), findsOneWidget);

    await tester.tap(find.byTooltip('Board options').first);
    await settle(tester);
    await tester.tap(find.text('Board settings'));
    await settle(tester);
    expect(find.text('Link join role'), findsOneWidget);
    await tester.tap(find.text('Public'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Board settings saved.'), findsOneWidget);
  });

  testWidgets('a public board can be joined from Discover', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Discover');

    // The card menu of a board the sample user has not joined.
    final menu = find.byTooltip('Board options').at(2);
    await tester.tap(menu);
    await settle(tester);
    await tester.tap(find.text('Join board'));
    await settle(tester);

    expect(find.textContaining('You joined'), findsOneWidget);
  });

  // ── Notifications ──────────────────────────────────────────────────────

  testWidgets('notifications can all be marked as read', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Notifications');

    expect(find.text('Mark all read'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await settle(tester);

    expect(find.text('All read'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
    expect(find.text('All notifications marked as read.'), findsOneWidget);
  });

  testWidgets('notifications can be filtered by type', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Notifications');

    // "Friends (1)": the accepted-request notification.
    await tester.tap(find.textContaining('Friends ('));
    await settle(tester);
    expect(find.textContaining('Mia Torres accepted'), findsOneWidget);
    expect(find.textContaining('mentioned you'), findsNothing);
  });

  // ── Friends ────────────────────────────────────────────────────────────

  testWidgets('a friend can be added by email', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Friends');

    await tester.tap(find.text('Add friend'));
    await settle(tester);
    await tester.enterText(
      find.byType(TextField).last,
      'omar.haddad@example.com',
    );
    await tester.tap(find.text('Search'));
    await settle(tester);

    expect(find.text('Omar Haddad'), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await settle(tester);
    expect(find.text('Request sent to Omar Haddad.'), findsOneWidget);
  });

  testWidgets('a friend can be blocked and unblocked', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Friends');

    await tester.tap(find.byTooltip('Friend options').first);
    await settle(tester);
    await tester.tap(find.text('Block'));
    await settle(tester);
    // The menu is closed, so this is the confirmation dialog's button.
    await tester.tap(find.text('Block'));
    await settle(tester);

    expect(find.text('Alex Kim is blocked.'), findsOneWidget);
    expect(find.text('Alex Kim'), findsOneWidget); // now in Blocked users
    await tester.tap(find.text('Unblock'));
    await settle(tester);
    expect(find.text('Alex Kim is unblocked.'), findsOneWidget);
  });

  // ── Workspaces and settings ────────────────────────────────────────────

  testWidgets('a workspace can be created from the web', (tester) async {
    await pumpApp(tester);
    await openSection(tester, 'Workspaces');

    await tester.tap(find.text('New workspace'));
    await settle(tester);
    // The dialog's name field is after the page's search box; its second
    // field is the description.
    await tester.enterText(find.byType(TextField).at(1), 'QA Guild');
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(find.text('Workspace created.'), findsOneWidget);
    expect(find.text('QA Guild'), findsOneWidget);
  });

  testWidgets('settings open from the sidebar and preferences toggle', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSection(tester, 'Settings');

    expect(find.text('Show tool tray tips'), findsOneWidget);
    expect(find.text('Board preview quality'), findsOneWidget);

    final trayTips = find.widgetWithText(SwitchListTile, 'Show tool tray tips');
    final before = tester.widget<SwitchListTile>(trayTips).value;
    await tester.tap(trayTips);
    await settle(tester);
    expect(tester.widget<SwitchListTile>(trayTips).value, !before);
  });

  testWidgets('privacy settings and preferred tags save from settings', (
    tester,
  ) async {
    // Tall enough to show every settings section without scrolling.
    await pumpApp(tester, size: const Size(1440, 2200));
    await openSection(tester, 'Settings');

    final publicSwitch = find.widgetWithText(SwitchListTile, 'Public profile');
    expect(publicSwitch, findsOneWidget);
    final before = tester.widget<SwitchListTile>(publicSwitch).value;
    await tester.tap(publicSwitch);
    await settle(tester);
    expect(tester.widget<SwitchListTile>(publicSwitch).value, !before);

    final emailSwitch = find.widgetWithText(
      SwitchListTile,
      'Show email address',
    );
    expect(tester.widget<SwitchListTile>(emailSwitch).value, isFalse);
    await tester.tap(emailSwitch);
    await settle(tester);
    expect(tester.widget<SwitchListTile>(emailSwitch).value, isTrue);

    // Suggested tags can be chosen, and chosen tags show as selected.
    await tester.tap(find.text('#Art'));
    await settle(tester);
    final art = tester.widget<InkChip>(find.widgetWithText(InkChip, '#Art'));
    expect(art.selected, isTrue);

    // A custom tag can be typed and added, then removed again.
    await tester.enterText(find.byType(TextField).last, 'Surrealism');
    await tester.tap(find.widgetWithText(InkButton, 'Add'));
    await settle(tester);
    expect(find.text('#Surrealism'), findsOneWidget);

    await tester.tap(find.text('#Surrealism'));
    await settle(tester);
    expect(find.text('#Surrealism'), findsNothing);
  });

  testWidgets('workspace owner sees member roles and can change or remove', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1440, 1600));
    await openWorkspace(tester, 'Product Team');

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('alex.kim@example.com'), findsOneWidget);
    expect(roleOf(tester, 'u2'), 'Editor');

    // Change a role from the member's menu.
    await tester.tap(find.byTooltip('Manage Alex Kim'));
    await settle(tester);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Viewer'));
    await settle(tester);
    expect(roleOf(tester, 'u2'), 'Viewer');

    // Remove another member through the confirmation dialog.
    await tester.tap(find.byTooltip('Manage Noah Patel'));
    await settle(tester);
    await tester.tap(find.text('Remove member'));
    await settle(tester);
    await tester.tap(find.widgetWithText(InkButton, 'Remove'));
    await settle(tester);
    expect(find.byKey(const ValueKey('member-row-u3')), findsNothing);
  });

  testWidgets('a refused workspace write reverts and shows the error', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: const Size(1440, 1600),
      repository: _RefusingWorkspaceRepository(),
    );
    await openWorkspace(tester, 'Product Team');

    await tester.tap(find.byTooltip('Manage Alex Kim'));
    await settle(tester);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Viewer'));
    await settle(tester);

    // The optimistic change is rolled back and the refusal is visible.
    expect(roleOf(tester, 'u2'), 'Editor');
    expect(
      find.text('Only the workspace owner can change member roles.'),
      findsOneWidget,
    );
  });

  testWidgets('a non-owner sees the members but no management menu', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1440, 1600));
    await openWorkspace(tester, 'Home Projects');

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Noah Patel'), findsOneWidget);
    expect(
      find.text('Only the workspace owner can manage members.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Manage Noah Patel'), findsNothing);
    expect(find.byTooltip('Manage Sam Rivera'), findsNothing);
  });

  testWidgets('workspace settings save the name and description', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1440, 1600));
    await openWorkspace(tester, 'Product Team');

    await tester.tap(find.widgetWithText(InkButton, 'Workspace settings'));
    await settle(tester);
    // Index 0 is the page's board search field; the dialog owns 1 and 2.
    await tester.enterText(find.byType(TextField).at(1), 'Product Guild');
    await tester.enterText(
      find.byType(TextField).at(2),
      'Renamed from the web.',
    );
    await tester.tap(find.widgetWithText(InkButton, 'Save changes'));
    await settle(tester);

    expect(find.text('Product Guild'), findsOneWidget);
    expect(find.textContaining('Renamed from the web.'), findsOneWidget);
  });

  testWidgets('workspace owner can invite someone by email', (tester) async {
    await pumpApp(tester, size: const Size(1440, 1600));
    await openWorkspace(tester, 'Product Team');

    await tester.tap(find.text('Invite'));
    await settle(tester);
    // Index 0 is the page's board search field; the dialog owns index 1.
    await tester.enterText(
      find.byType(TextField).at(1),
      'priya.shah@example.com',
    );
    await tester.tap(find.widgetWithText(InkButton, 'Send invite'));
    await settle(tester);

    expect(find.text('Invitation sent.'), findsOneWidget);
  });

  testWidgets('a member can leave a workspace', (tester) async {
    await pumpApp(tester, size: const Size(1440, 1600));
    await openWorkspace(tester, 'Home Projects');

    await tester.tap(find.widgetWithText(InkButton, 'Leave workspace'));
    await settle(tester);
    await tester.tap(find.widgetWithText(InkButton, 'Leave'));
    await settle(tester);

    expect(find.text('Home Projects'), findsNothing);
    expect(find.text('Product Team'), findsOneWidget);
  });

  testWidgets('the owner can delete a workspace', (tester) async {
    await pumpApp(tester, size: const Size(1440, 1600));
    await openWorkspace(tester, 'Product Team');

    await tester.tap(find.widgetWithText(InkButton, 'Delete workspace'));
    await settle(tester);
    await tester.tap(find.widgetWithText(InkButton, 'Delete'));
    await settle(tester);

    expect(find.text('Product Team'), findsNothing);
    expect(find.text('Home Projects'), findsOneWidget);
  });
}

/// Pumps frames for a while (pages contain looping animations, so
/// pumpAndSettle could wait forever).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The sample repository with member writes refused, for the rollback test.
class _RefusingWorkspaceRepository extends SampleWebCompanionRepository {
  @override
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  }) async {
    throw 'Only the workspace owner can change member roles.';
  }
}
