# Web vs mobile: module parity audit

> **Status (implementation):** the gaps below are implemented on the web as
> described in `WEB_PARITY_PLAN.md` — board lifecycle, workspaces, friends,
> settings, profile photo, account deletion, notification read state and
> tap-through, deep links, workspace members/roles/invites/settings, and the
> voice/camera/share guards. Chat, voice, push,
> offline mode and board thumbnails remain mobile-only by design. This document
> is kept as the original audit.

Scope: every module under `lib/features/`, `lib/domain/` and `lib/ui/` that the web
entry point (`lib/web/main_web.dart`) does **not** reuse, plus the web modules that
exist but are only partly wired. Phones are unaffected by all of this.

Method: read `lib/web/**` (screens, repositories, canvas services), the mobile screens
and blocs those replace, and `WEB_COMPANION.md` / `WEB_CANVAS.md` to separate
*deliberate* exclusions from *unfinished* or *silently broken* ones. This is a
code-reading audit; nothing below was executed in a browser or on a device.

Legend: **Missing** = no web implementation at all. **Partial** = present but a
subset of the mobile workflow. **Stubbed** = a class exists only to satisfy an
interface. **Broken** = present and reachable, but misbehaves.

## 1. Modules with no web implementation

| # | Module | Mobile source | Web state | Impact |
|---|---|---|---|---|
| 1 | Direct / group chat (Agora): inbox, thread, attachments, reactions, GIFs, group creation and settings | `lib/features/chat/**` (~2,900 lines: `chat_inbox_screen.dart`, `chat_thread_screen.dart`, `group_settings_screen.dart`, `create_group_screen.dart`, …) | **Missing.** No file in `lib/web` mentions chat except the in-canvas board chat. `WEB_COMPANION.md` lists "chat (direct messages)" as not on the web. | Web users cannot message friends at all, and there is no "available in the app" entry point — the feature simply does not exist in the navigation. |
| 2 | Board lifecycle: create, rename, duplicate, archive/unarchive, delete, tags, visibility / join policy / who-can-invite / copy settings, invite members | `lib/features/dashboard/view/create_board_screen.dart`, `board_settings_screen.dart`, `dashboard_bloc.dart`, `board_settings_bloc.dart` | **Missing.** `WebBoardRepository` (`lib/web/canvas/web_board_repository.dart:191-257`) throws `UnsupportedError` for `createNewBoard`, `joinBoard`, `deleteBoard`, `archiveBoard`, `unarchiveBoard`, `setBoardPaused`, `duplicateBoard`, `updateBoardTags`, `updateBoardSettings`, `getPublicBoards`, `getRecommendedPublicBoards`, `countBoardsForUser`, `getOwnedBoards`, `getJoinedBoards`. The web UI has no create/rename/archive/delete entry. | A user cannot create a first board, rename one, or tidy the account from the browser. `WEB_COMPANION.md` documents creation as app-only. |
| 3 | Workspace management: create, settings, invite members, add / move / remove boards, join by code | `lib/features/workspaces/view/create_workspace_screen.dart`, `workspace_settings_screen.dart`, `workspace_detail_screen.dart` (FAB, move/remove) | **Missing.** `lib/web/screens/workspaces_page.dart` is read-only: list → workspace boards → open board. The doc comment says creating/managing stays in the app. | Workspaces can be browsed but never changed from the web. |
| 4 | Friend management: send requests, search users, add friend, blocked users, presence, open a friend's profile | `lib/features/friends/view/widgets/add_friend_sheet.dart`, `blocked_users_screen.dart`, `friends_bloc.dart`, `friend_presence_avatar.dart`, `profile_route.dart` | **Partial.** `lib/web/screens/friends_page.dart` only accepts/declines incoming requests and lists friends. `WebCompanionRepository` has no send/search/block methods. | One-way friend workflow: requests can be answered but never started, and nobody can be blocked or inspected. |
| 5 | Account: registration, account deletion, logout from settings | `register_screen.dart`, settings "Danger Zone" | **Partial.** Sign-in only for existing accounts (`_requireExistingAccount`, `firebase_web_companion_repository.dart:125-137`); logout exists in the header menu (`home_shell.dart:492`); no delete-account or registration. | Acceptable as a stated v1 rule, but "delete my account" and "sign up" have no web path. |
| 6 | Settings: tray tips, board preview quality/compression, default bottom bar customizer, push/invite/friend alert toggles, privacy toggles, preferred tags, clear cache, logout, delete account | `lib/features/settings/view/settings_screen.dart` (+ `SettingsBloc`) | **Missing.** There is no settings page or navigation entry in `lib/web`; the header only switches light/dark (`web_theme.dart`). `WebSettingsRepository` (`web_canvas_support.dart:19-88`) implements the storage layer but nothing exposes it. | Canvas preferences can only be changed on a phone; the bottom bar the web canvas loads cannot be customised from the web. |
| 7 | Profile photo upload | `lib/features/profile/view/widgets/edit_profile_sheet.dart` (camera/gallery, validation, compression) | **Missing.** `lib/web/screens/profile_page.dart` edits name and bio only and tells the user to change the photo in the app. | Documented limitation; the avatar shown is the stored URL. |
| 8 | Voice calls | `lib/features/canvas/view/voice/voice_call_hud.dart`, `voice_service` impl (Agora RTC) | **Stubbed.** `WebVoiceService` (`web_canvas_support.dart:128-190`) returns empty streams, `joinCall` throws; the members tray replaces the call button with a message (`members_tray.dart:99`). | Documented "mobile only". See B5 for the one unguarded piece. |
| 9 | Push notifications | `LocalNotificationService`, FCM | **Missing** by design (needs a service worker + VAPID key). | In-app feed still works. |
| 10 | Offline mode and local persistence | Isar repositories, `IsarCrdtLocalStore` | **Missing** by design: `MemoryCrdtLocalStore`, Firestore-only reads. | A refresh reloads from the server; no offline drawing. |
| 11 | Deep links and URL routing (`/board/<id>`, profile, invite links) | `AppRouter`/`onGenerateRoute` in `lib/app_view.dart` | **Missing.** `web_companion_app.dart` uses `MaterialApp(home: …)` with no `onGenerateRoute` and no `usePathUrlStrategy`; the URL never changes. | Board links cannot be shared or bookmarked on the web, and browser Back leaves the canvas instead of navigating inside the app. |

## 2. Present but incomplete or broken

### B1. Notification read state is never applied on web (unread badges are always on)

- `InAppNotification.fromMap` reads the Firestore field `read`
  (`lib/domain/models/notification/in_app_notification.dart:44`).
- Nothing writes that field: mobile marks read locally through
  `NotificationPreferences.markAsRead` → `shared_preferences` key
  `read_notification_ids` (`lib/core/utils/notification_preferences.dart:17-26`),
  and `NotificationsBloc` merges those ids into the list as `isRead`
  (`notifications_bloc.dart:313`). `notification_repository_impl.dart:86` only
  *reads* `data['read']`.
- The web repository maps Firestore documents directly
  (`firebase_web_companion_repository.dart:482-505`) and has **no** mark-read
  method; `WebCompanionRepository` (`web_companion_repository.dart`) exposes only
  `watchNotifications` and `deleteNotification`.
- Consequence: every notification renders with the unread dot
  (`notifications_page.dart:128`), the header badge counts all of them
  (`home_shell.dart:92`), and there is no "Mark all read"
  (mobile: `notifications_screen.dart:373`). The badge can only ever be reduced
  by deleting items.
- Fix: load `read_notification_ids` from `NotificationPreferences` in the web
  notification stream (or overlay in the page), add `markRead`/`markAllRead` to
  `WebCompanionRepository`, and call them on tap/delete.

### B2. Notifications are read-only cards with no navigation

The web page only deletes (`notifications_page.dart:31-38`). Mobile notifications
are clickable and route by `type`: board canvas, board invites, friend requests,
workspace detail, edit requests, profile (`notifications_screen.dart:480-620`).
On the web a "you were invited" notification cannot take you to the invite, and an
"edit access approved" notification cannot open the board. There are also no
type filters (`All/Requests/Boards/Workspace/Friends`).

### B3. Board settings are a dead end

Tapping the board title, or "Board Settings" in the board menu, calls
`_openSettings`, which on web is `board_settings_opener_web.dart` — it shows
"Board settings are available in the InkLink mobile app." and returns. So on the
web there is no way to rename a board, change members/roles, invite, change
visibility, tags, pause or archive. Note `WebBoardRepository.renameBoard`
(`web_board_repository.dart:150`) is fully implemented and has **no caller** —
`CanvasRenameBoardRequested` is only dispatched from the mobile settings screen.
Cheap partial win: a rename dialog on web (the repository method already works).

### B4. Archived / paused boards are dead ends on the web

- The archived banner says "Unarchive it from Settings to edit"
  (`canvas_screen.dart:9605-9617`), but the web has no Settings screen (item 6).
- The paused banner's Resume action dispatches `CanvasSetBoardPausedRequested(false)`,
  which reaches `BoardService.setBoardPaused` → `WebBoardRepository`'s
  `_unsupported('setBoardPaused')`; the bloc catches it and shows
  "Failed to update board pause state" (`canvas_bloc.dart:7420-7450`).
- The web board list's Archived tab opens archived boards, so users can reach
  these dead ends.

### B5. Voice HUD is not gated; only the join path is

Only the members-tray call button is guarded (`members_tray.dart:99`). The layout
still builds `const VoiceCallHud()` unconditionally (`canvas_screen.dart:6001`).
Today it is invisible because `WebVoiceService` never emits an active call, so the
guard is implicit and easy to lose. `WEB_CANVAS_PLAN.md` §2 H promised an explicit
`if (!kIsWeb)` around the HUD, which was not done.

### B6. "Share" actions on web silently download instead of sharing

The web top bar's Share menu ("Share as image") and the export sheet's
"Share via…" both dispatch `CanvasExportBoardRequested(..., shareAfterExport: true)`
(`canvas_screen_web.dart`, `canvas_screen.dart:9908-9917`). The `kIsWeb` branch in
`canvas_bloc.dart:7460-7490` ignores `shareAfterExport`, downloads the file and
reports "Board downloaded as …". Functionally fine, but the labels promise a share
sheet that never appears; no Web Share API / clipboard fallback is used.

### B7. Public board discovery cannot join

`WebDiscoverPage` lists public boards and opens them, but `joinBoard` is
`UnsupportedError`, and the page has no membership action. Depending on
`firestore.rules`, opening a public board the user has not joined can only ever be
read-only (or fail), and there is no way to become a member from the web.

### B8. Camera capture is offered without a web path

The canvas image tool exposes "Take a photo" → `ImageSource.camera`
(`canvas_screen.dart:1868`), and `image_picker_for_web` maps that to a file input
with a capture hint. Most desktop browsers ignore it and open a file chooser.
It degrades silently; `WEB_CANVAS_PLAN.md` §4 lists camera as hidden on web, but
no guard exists.

### B9. Board thumbnails never appear

`WebBoardRepository.saveBoardPreview` is a no-op (`web_board_repository.dart:173`),
so a board edited on the web writes no preview, and `watchBoardPreview` always
returns null. Web board cards use the placeholder path
(`boards_page.dart`: `previewPath: null`). Documented, but it also means web edits
never refresh the thumbnail a phone sees for that board.

### B10. Joined-board role is approximate in lists

`watchMyBoards` marks owner by the board index, and leaves `currentUserRole` as the
board document's value for joined boards (it never reads `members/{uid}`), so a
joined editor can appear as viewer on cards. Inside the canvas the role is resolved
correctly (`web_board_repository.dart:_resolveRole`). Documented in
`WEB_COMPANION.md`; low impact.

### B11. No delete/mark-read on notification and no per-board "open" from invites

Invites are accepted/declined correctly, but after accepting, the user has to find
the board on Home — there is no "Open board" result, unlike mobile, which pushes
the canvas after acceptance (`notifications_screen.dart:180-200`).

## 3. Verified working on web (no action)

Email/password + Google popup sign-in, password reset, email verification gate;
live board list with search and My/Joined/Archived tabs; invites (board and
workspace) accept/decline through the same Cloud Functions; workspace list and
per-workspace board list; Discover search and tag filters; incoming friend
requests and friends list; name/bio editing; light/dark theme with persistence;
responsive desktop sidebar / phone-style nav; the full canvas (tools, layers,
selection, frames, tables, images, minimap, comments, board chat, history + undo,
AI generate/edit, edit-request review, keyboard/mouse shortcuts) with the shared
Socket.IO sync; export PNG/PDF/SVG as a browser download.

## 4. Suggested priority

| Priority | Item | Why | Rough size |
|---|---|---|---|
| 1 | B1 + B2 notification read state, mark-all-read, tap-through | Visible wrongness today (badge/undots) and cheap | Small (one repository stream + page handlers) |
| 2 | B3 rename on web (and reuse it in B4 unarchive, pause) | `renameBoard` already works; unblocks archived/paused boards | Small–medium |
| 3 | #2 board creation + archive/delete/tags/invite (move `WebBoardRepository` methods to real implementations) | Biggest functional hole; the repository already declares them | Medium |
| 4 | #6 settings page on web (reuse `WebSettingsRepository`) | Needed by canvas preferences and by account actions | Medium |
| 5 | B7 join public board, #4 send friend request / block | Completes discovery and friends | Medium |
| 6 | #3 workspace management | Large, app-specific flows | Large |
| 7 | #1 chat, #8 voice, #9 push | Separate protocols/SDK work | Large |
| 8 | #11 URL routing / deep links | Navigation polish and shareable links | Medium |

Intentional and already documented as out of scope: offline mode, local
persistence, push, voice, direct chat, account creation, board thumbnails,
joined-role precision.
