# Web parity: plan, implementation and verification

> **Historical planning record:** Implemented; the web companion was subsequently refactored to the 5-layer architecture (`UI -> Cubit -> WebCompanionService -> Repository`). See [../architecture/layered-architecture.md](../architecture/layered-architecture.md) for the current layout.

Source of truth for *what was missing*: `../audits/web-parity-audit-historical.md` (B1–B11 and modules
1–11). This file records how each gap was closed, what stayed mobile-only on
purpose, and the tests that now guard the work.

Constraint from the brief: fix real defects and close real gaps; no refactors
beyond that, and nothing that changes phone behaviour.

## 1. Scope

Two kinds of items came out of the audit.

**Closed on the web** (the subject of this change): board lifecycle, workspace
management, friend management, settings, profile photo, account deletion,
notification read state and tap-through, deep links, voice/camera guards, web
share, joined-board roles, public-board join.

**Kept mobile-only** (documented exclusions, unchanged): Agora direct/group
chat, voice calls, FCM push, Isar offline persistence, board thumbnails.

## 2. Design decisions

1. **Shared, pure helpers first.** `lib/web/data/web_board_ops.dart` holds the
   document shapes (`newBoardFields`, `duplicatedBoardFields`,
   `boardSettingsFields`), notification read-state overlay (`applyReadState`,
   `unreadNotificationCount`), filter matching and tap-through targets. The same
   values mirror `FirestoreBoardRepository`, so a board created or re-configured
   in a browser is the document the phone reads. Being pure, the logic is
   unit-testable without Firebase.
2. **URL parser separated from routing.** `lib/web/data/web_url.dart` parses
   `#/board/<id>` and `#/discover` from the initial location. Hash routing is
   used because real paths would need server rewrites; `usePathUrlStrategy`
   would pull in `flutter_web_plugins`, which this app does not depend on.
3. **One repository contract, three implementations.** Every new member was
   added to `WebCompanionRepository` (interface), `FirebaseWebCompanionRepository`
   (Firestore/Cloud Functions) and `SampleWebRepository` (preview + widget
   tests). `WebBoardRepository` now implements the whole `BoardRepository`
   interface, so the canvas has no `UnsupportedError` path left.
4. **Notification read state follows the phone.** `NotificationPreferences`
   (uid-scoped `shared_preferences`) is overlaid onto the live notification
   stream with `combineLatest2(..., applyReadState)`; read ids also feed the
   sidebar badge count.
5. **Dialogs own their controllers.** Every new dialog is a `StatefulWidget`
   that keeps its controllers/notifiers and disposes them in `dispose()`, rather
   than creating them in a `showDialog` builder and disposing after the pop —
   that produced `TextEditingController used after being disposed` because the
   close animation rebuilds.
6. **ListTiles get a Material.** Flutter asserts when a `ListTile` sits inside a
   painted `DecoratedBox`; settings and the workspace board dialog wrap their
   tiles in `Material(type: MaterialType.transparency)`.
7. **Responsive page headers.** `WebPageHeader` stacks its actions under the
   title below 720 px, and the boards/workspaces actions use `Wrap`, so a
   600 px window no longer overflows by 31 px.

## 3. What was implemented

### Board lifecycle (audit #2, B3, B4, B7, B10)

- `WebBoardRepository`: `createNewBoard`, `archiveBoard`, `unarchiveBoard`,
  `deleteBoard`, `duplicateBoard`, `updateBoardTags`, `updateBoardSettings`,
  `setBoardPaused`, `getOwnedBoards`, `getJoinedBoards`, `getPublicBoards`,
  `getRecommendedPublicBoards`, `countBoardsForUser`, `joinBoard`.
  Create/duplicate are Firestore transactions like mobile; join goes through
  the `joinBoardByCode` Cloud Function; delete through `deleteBoard`; settings,
  tags, archive and pause are document updates plus best-effort
  `updateBoardSettings` / `setBoardPaused` calls.
- `boards_page.dart`: **New board** and **Join** in the header, and a card menu
  with open, rename, tags, settings, copy (duplicate), archive/unarchive,
  pause/resume, delete (with confirmation) and copy-link.
- `board_dialogs.dart`: create, join, rename, tags, board settings (visibility,
  join policy, who can invite, allow members to copy).
- Archived boards are no longer a dead end: the canvas banner points at the
  Home menu actions on web.
- Joined boards resolve `currentUserRole` from `members/{uid}` instead of the
  board document, so an editor no longer shows as a viewer.

### Notifications (B1, B2, B11)

- Read state persisted per user (`NotificationPreferences`) and overlayed onto
  the stream; unread dots and the sidebar/tab badge follow it.
- **Mark all read**, per-type filters (all / invites / activity), and
  tap-through: an invite opens its board after the accept/decline flow, a
  mention/comment opens the canvas, and board invites offer **Open board**.

### Navigation and settings (#6, #11)

- `settings_page.dart`: canvas preferences (tray tips, preview quality,
  compression), alert preferences, privacy toggles, preferred content tags,
  storage (clear cache) and account (sign out, delete account with
  confirmation). Canvas/alerts read `WebSettingsRepository`; privacy and tags
  read and write the user document, so the phone shows the same values. A new
  `Settings` entry sits in the sidebar and the header menu.
- `web_account_settings.dart`: the account-level model (`isProfilePublic`,
  `showOnlineStatus`, `showEmail`, `preferredTags`) with the phone's defaults and
  a case-insensitive `toggleTag`; `watchAccountSettings`,
  `updatePrivacySettings` and `updatePreferredTags` are on the repository and
  the settings page writes optimistically with rollback on failure.
- Deep links: `web_url.dart` + `main_web.dart` parse the initial location and
  `WebBoardOpener` opens `#/board/<id>` directly; a bookmarked `#/section` URL
  opens that section.
- Profile photo upload (`uploadProfilePhoto`, base64 image) from the profile
  page; account deletion from settings.

### Friends (#4)

- Add by email (search + `sendFriendRequest`), block/unblock (`blockUser`,
  `unblockUser`), unfriend (`unfriendUser`), and a blocked-users list read from
  `blocked_users` where `blockerUid == request.auth.uid`.

### Workspaces (#3, plus members and settings)

- Create workspace (`createWorkspace`), manage a workspace's boards
  (`addBoardToWorkspace` / `removeBoardFromWorkspace`) with a dialog per
  workspace, and board counts per workspace.
- `workspace_members.dart`: the live member list
  (`workspaces/{id}/members/{uid}` joined with each member's profile) with every
  member's role. The owner can change a role (`editor`, `member` or `viewer`,
  the phone's values), remove a member (a transaction that deletes the member
  document, decrements `memberCount` and bumps `updatedAt`, as the phone does),
  invite someone by email (`inviteToWorkspace` after `searchUsersByEmail`),
  edit the workspace name and description (`updateWorkspace`, which writes the
  same `name` / `description` / `updatedAt` fields the phone edits) and delete
  the workspace; a member can leave (`leaveWorkspace`). Refused writes — a
  non-owner trying to manage members, or a failed Cloud Function — are shown as
  errors, and member changes are applied optimistically with rollback. The
  members card tells non-owners that only the owner can manage members.

### Canvas platform guards (B5, B6, B8)

- `VoiceCallHud` only mounts when `!kIsWeb`; the camera capture option is
  hidden on web (the browser would just open a file chooser).
- Share uses `SharePlus.instance.share` on web with the old download as a
  fallback.

## 4. Tests

New and rewritten suites under `test/web/`:

- `web_board_ops_test.dart` — pure board document shapes, notification overlay,
  filters and tap-through targets.
- `web_url_test.dart` — hash-path parsing for sections and board ids.
- `web_account_settings_test.dart` — privacy defaults, tag parsing, tag
  toggling and equality.
- `web_board_repository_test.dart` — the canvas subset, empty-id handling, the
  signed-out guard, and a source check that no `BoardRepository` member falls
  back to an unsupported error.
- `web_workspace_members_test.dart` — repository rules for workspaces: roles
  and ordering, role changes, removal and the member count, owner-only
  management, the owner never being demoted or removed, valid roles only,
  invites, leaving, deleting, and the name/description write.
- `web_pages_test.dart` — widget flows: create, rename, archive/restore, tags,
  board settings, join from Discover, notification mark-all-read and filters,
  add/block/unblock friend, create workspace, workspace members (roles, role
  change, removal, the rollback on a refused write, the non-owner view),
  workspace settings, invites, leaving and deleting a workspace, settings page
  toggles, plus the existing sign-in and responsive-nav checks.
- `web_platform_guards_test.dart` — source guards for the voice HUD, camera and
  web share paths.

Run them with:

```bash
flutter test test/web
```

## 5. Results

Run on the implementation commit:

| Check | Command | Result |
|---|---|---|
| Web suites | `flutter test test/web` | 111 passed |
| Whole suite | `flutter test` | 1032 passed, 0 failed |
| Analyzer | `flutter analyze` | No issues found |
| Architecture guardrails | `dart run tool/architecture_guardrails.dart` | Passed |
| Web build | `flutter build web --release -t lib/web/main_web.dart` | Succeeded |

The widget tests caught three real defects during the work, all fixed here:

1. Dialogs disposed their `TextEditingController`s while the close animation
   still rebuilt, crashing rename/tags/settings/join.
2. The board settings dialog overflowed `InkDialog` (no scroll view) — now a
   `ConstrainedBox` + `SingleChildScrollView`.
3. A 600 px window overflowed the boards header by 31 px — now a stacked
   header and `Wrap` actions (`WebPageHeader`, boards, workspaces).

Not covered by these tests: a real browser session against Firebase (sign-in,
Cloud Functions, Firestore rules) and the phone app. The widget tests use the
sample repository and stubbed services.

## 6. Remaining mobile-only

- **Direct/group chat (Agora)** — needs the Agora web SDK and its own UI; no web
  entry point today.
- **Voice calls** — `WebVoiceService` stays a stub; the members tray explains
  it is app-only.
- **Push notifications** — needs a service worker and VAPID key.
- **Offline mode** — web reads come from Firestore with an in-memory CRDT store.
- **Board thumbnails** — the web canvas has no local preview image, so
  `saveBoardPreview` stays a no-op and web cards keep the placeholder.
- **Registration** — sign-in remains existing-accounts only.
