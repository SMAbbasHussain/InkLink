# PR #44 review — Web version: InkLink companion pages and live board in the browser

Reviewed and merged on 2026-11-27. Fixes applied to `main` after the merge
commit are marked **Fixed** below.

| | |
|---|---|
| PR | [#44](https://github.com/SMAbbasHussain/InkLink/pull/44) — `feat/web-canvas` |
| Base | `main` @ `5171264` |
| Head merged | `1df184d` (`44835eb` + the test fix described in Problem 1) |
| Merge commit on `main` | `a01b40d` |
| Size | 27 commits, 64 files, +9,537 / −446 |

## Merge

`main` was already merged into the branch (`d1ef8ca`), so the PR had **no
conflicts** and no merge work was needed. The PR was merged with a merge
commit (`a01b40d`); the branch's history is preserved.

## Checks run on the merged tree

| Check | Result |
|---|---|
| `dart run tool/architecture_guardrails.dart` | passed |
| `flutter analyze` | No issues found |
| `flutter test` | 950 tests passed at merge; 960 after the follow-up fixes |
| `flutter build web -t lib/web/main_web.dart` | built successfully (only the wasm dry-run notice from `socket_io_common`) |
| GitHub Actions `Architecture Guardrails` on the PR head | ▲ failed before the fix → ✅ passes after it |

I did **not** click through the app in a real browser or on a phone. The
manual phone checklist in the PR description (each tool, live sync with a
second device, offline reconnect, AI generate/edit, comments, chat, voice,
export, old board) still needs a human pass, as does a browser pass of the
companion pages and the board.

## Coverage of the merge

The change set below is everything the merge brought into `main`:

```bash
git diff --name-status a01b40d^1 a01b40d   # 64 entries
```

| File | Kind | Verdict |
|---|---|---|
| `WEB_AUDIT.md` | doc | No issue — Phase A audit, kept as the record of the pre-work state |
| `WEB_CANVAS.md` | doc | No issue — matches the implemented canvas, entry point and owner steps |
| `WEB_CANVAS_PLAN.md` | doc | Fixed — Problem 11 (wrong `IsarCrdtLocalStore` path and file list) |
| `WEB_COMPANION.md` | doc | No issue — page list, limitations and run commands match the code |
| `lib/core/utils/app_snackbar.dart` | shared | Fixed — Problem 7 (test check moved behind a conditional import) |
| `lib/core/utils/sync_server_socket.dart` | shared | No issue — new socket helper; covered by `sync_server_socket_test.dart` |
| `lib/domain/models/canvas/crdt_update.dart` | shared | No issue — conditional export only |
| `lib/domain/models/canvas/local_crdt_update_web.dart` | shared | No issue — field parity checked by `crdt_update_web_test.dart` |
| `lib/domain/repositories/canvas/canvas_sync_repository.dart` | shared | No issue — import swap |
| `lib/domain/repositories/canvas/canvas_sync_repository_impl.dart` | shared | No issue — Isar calls replaced by the store, same ordering and transactions |
| `lib/domain/repositories/canvas/crdt_local_store.dart` | shared | No issue — interface; contract test runs both stores |
| `lib/domain/repositories/canvas/isar_crdt_local_store.dart` | shared | No issue — moved Isar code, contract-tested |
| `lib/domain/repositories/canvas/memory_crdt_local_store.dart` | shared | No issue — online-only store, contract-tested |
| `lib/domain/services/canvas/board_chat_service_impl.dart` | shared | No issue — chat now opens its own socket through the helper |
| `lib/domain/services/canvas/board_export_service.dart` | shared | Fixed — Problem 2 (full AI image in canvas/web exports) and Problem 7 (export folder resolution) |
| `lib/domain/services/canvas/canvas_service.dart` | shared | No issue — import swap |
| `lib/domain/services/canvas/export_directories.dart` | shared | No issue — conditional export, mobile path unchanged |
| `lib/domain/services/canvas/export_directories_web.dart` | shared | No issue — web stub |
| `lib/features/canvas/bloc/canvas_bloc.dart` | shared | No issue — web download branch is inside the existing try/catch, so `isExporting` is always cleared |
| `lib/features/canvas/view/board_settings_opener.dart` | shared | No issue — phone behaviour moved verbatim |
| `lib/features/canvas/view/board_settings_opener_web.dart` | shared | No issue — web dialog |
| `lib/features/canvas/view/canvas_screen.dart` | shared | No issue — conditional opener, `kIsWeb` guards for voice/share |
| `lib/features/canvas/view/canvas_screen_web.dart` | shared | No issue — desktop bars/rail/shortcuts; widget tests cover the layout |
| `lib/features/canvas/view/trays/members_tray.dart` | shared | No issue — voice explains it is mobile-only on web; edit requests use `routeFrom` |
| `lib/features/canvas/view/widgets/sliding_tray.dart` | shared | No issue — web trays behind `useWebLayout` (web + ≥700 px only) |
| `lib/features/dashboard/view/board_edit_requests_screen.dart` | shared | No issue — `routeFrom` supplies the board's `NotificationsBloc` |
| `lib/main.dart` | shared | No issue — passes `IsarCrdtLocalStore`, same database |
| `lib/ui/widgets/glass_nav_bar.dart` | shared | No issue — badge is additive, default 0 |
| `lib/web/canvas/web_board_repository.dart` | web | Fixed — Problem 3 (every interface member explicit, no `noSuchMethod`) |
| `lib/web/canvas/web_canvas.dart` | web | No issue — services wiring and back navigation |
| `lib/web/canvas/web_canvas_support.dart` | web | No issue — settings, notification feed and mobile-only voice stubs |
| `lib/web/data/firebase_web_companion_repository.dart` | web | Fixed — Problem 4 (shared board index, no per-card reads) |
| `lib/web/data/web_account.dart` | web | No issue |
| `lib/web/data/web_companion_repository.dart` | web | No issue — interface |
| `lib/web/data/web_mappers.dart` | web | Fixed — Problem 5 (`whereIn` batches) and the `combineLatest2` join helper |
| `lib/web/main_web.dart` | web | No issue — dotenv, Firebase, canvas services |
| `lib/web/preview/main_web_preview.dart` | web | No issue — preview entry only |
| `lib/web/preview/sample_web_repository.dart` | web | No issue — in-memory sample data, preview/tests only |
| `lib/web/screens/boards_page.dart` | web | No issue — tabs, search, archive/delete dialogs |
| `lib/web/screens/friends_page.dart` | web | No issue |
| `lib/web/screens/home_shell.dart` | web | No issue — sidebar/top bar, live counts |
| `lib/web/screens/invites_page.dart` | web | No issue |
| `lib/web/screens/notifications_page.dart` | web | No issue |
| `lib/web/screens/profile_page.dart` | web | No issue |
| `lib/web/screens/sign_in_screen.dart` | web | Fixed — Problem 6 (Resend busy state) |
| `lib/web/screens/web_shell_nav.dart` | web | No issue |
| `lib/web/screens/workspaces_page.dart` | web | No issue — list/detail, fresh query per visit |
| `lib/web/web_companion_app.dart` | web | No issue — sign-in gate and theme |
| `lib/web/web_theme.dart` | web | No issue — browser-stored light/dark choice |
| `lib/web/widgets/web_widgets.dart` | web | No issue — headers, stream lists, error/empty states |
| `test/core/utils/sync_server_socket_test.dart` | test | No issue |
| `test/domain/models/canvas/crdt_update_web_test.dart` | test | No issue |
| `test/domain/repositories/canvas/crdt_local_store_contract_test.dart` | test | No issue |
| `test/domain/repositories/canvas/crdt_store_test_support.dart` | test | No issue |
| `test/domain/services/canvas/board_export_web_download_test.dart` | test | No issue |
| `test/features/canvas/canvas_bloc_store_parity_test.dart` | test | No issue |
| `test/features/canvas/view/text_selection_editing_bar_test.dart` | test | No issue — covers the missing-`type` crash |
| `test/features/canvas/view/web_canvas_layout_test.dart` | test | Fixed — Problem 1 (real-time wait before delete) |
| `test/web/web_companion_imports_test.dart` | test | No issue — guard against Isar/path_provider/Agora in the web graph |
| `test/web/web_mappers_test.dart` | test | No issue |
| `test/web/web_pages_test.dart` | test | No issue |
| `test/web/web_review_fixes_test.dart` | test | No issue |
| `web/index.html` | config | No issue — title/description and splash container updated |
| `web/manifest.json` | config | No issue — name, theme and icons updated |

Counts: 4 docs, 24 shared-source files, 22 web-source files, 12 tests, 2 web
config files = 64, matching the merge exactly. "No issue" means the hunks were
read and no defect was found, not that a browser run was performed.

---

## Problems found

### 1. [Fixed, blocked CI] Web-layout undo test depends on Yjs's 500 ms undo capture window

**Where:** `test/features/canvas/view/web_canvas_layout_test.dart`,
“Delete removes the selection and Ctrl+Z brings it back”.

**Symptom:** The PR's CI failed at the `Test` step on GitHub's Ubuntu runner —
twice, including after a manual re-run:

```
test/features/canvas/view/web_canvas_layout_test.dart: Delete removes the selection and Ctrl+Z brings it back (failed)
Expected: an object with length of <1>
  Actual: WhereTypeIterable<TextElement>:[]
```

It passed on Windows, which is why it was not caught before opening the PR.

**Cause:** `UndoManager` (`packages/yjs_dart/lib/src/utils/undo_manager.dart`,
`captureTimeout = 500` at line 171, merge check at line 257) groups edits made
within **500 ms of each other, measured on the wall clock**. `tester.pump()`
advances only fake time, so it does not separate steps. On the faster Linux
runner the test's “add text” and “delete” landed inside one capture window and
became a single undo step; Ctrl+Z then reverted both operations, so the text
never came back. On the slower Windows machine the two operations were more
than 500 ms apart and the test passed.

**Fix:** the test now waits out the capture window with real time before
deleting, so the delete is its own undo step:

```dart
await tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 650)),
);
```

Committed as `1df184d` on the PR branch. The new CI run
([46015012185](https://github.com/SMAbbasHussain/InkLink/actions/runs/46015012185))
passed guardrails, analyze and the full test suite on Linux.

This was a test defect, not a product defect: undoing a group of operations
that cancel each other out correctly leaves the board as it was before the
group.

### 2. [Fixed, medium] Board exports drew AI images from their thumbnail, not the full image

**Where:** `lib/domain/services/canvas/board_export_service.dart`.

`resolveExportElements()` downloads the full image behind an AI image's URL and
inlines it for export, but only `exportBoard()` called it. `exportCanvas()` —
the path the export sheet uses on phones and the new `renderCanvasExport()` on
the web — never called it, and the canvas stores only a small thumbnail inline
for AI images (`CanvasAddAiImageElement`,
`lib/features/canvas/bloc/canvas_bloc.dart:2569`). Image elements in the export
were therefore rasterised from the thumbnail, so an exported PNG/PDF/SVG could
show an AI image at low resolution.

This predates the PR (it already affected the phone export sheet), but the new
“export as browser download” feature inherits it and the PR description lists
AI images among the tested export content.

**Fix:** both `exportCanvas()` and `renderCanvasExport()` now resolve the
planned elements before rendering (`exportElements`), so only the elements
actually in the export are fetched, the existing thumbnail fallback is kept,
and no board element is mutated. Covered by a new test in
`test/domain/services/canvas/board_export_ai_images_test.dart` that renders a
web export for an AI image and asserts the SVG embeds the downloaded full
image, not the thumbnail.

### 3. [Fixed, low] `WebBoardRepository` had a runtime-only `noSuchMethod` fallback

**Where:** `lib/web/canvas/web_board_repository.dart`.

The class implemented `BoardRepository` but relied on `noSuchMethod` to throw
`UnsupportedError`: a new canvas call to any other repository method failed in
the browser only, and the compiler had nothing to point at.

**Fix:** every `BoardRepository` member is declared explicitly. The canvas
subset (`getBoardById`, `getBoardMembers`, `renameBoard`, `ensureBoardCached`,
`deactivateBoard`, `saveBoardPreview`, and the no-op sync/preview stubs) keeps
its behaviour; the board-list, creation, archive and discovery members throw
`UnsupportedError` from named methods via one `_unsupported` helper. Adding a
member to the interface is now a compile error here.

Covered by `test/web/web_board_repository_test.dart` (fake services: the canvas
subset works without touching Firestore, and every remaining member throws
`UnsupportedError` naming itself) and by `test/web/web_platform_guards_test.dart`
(fails if a `noSuchMethod` implementation comes back).

### 4. [Fixed, low / performance] Workspace cards re-queried the user's board index

**Where:** `lib/web/data/firebase_web_companion_repository.dart`
(`watchWorkspaceBoards`).

Every workspace card and every workspace-link snapshot re-read
`users/{uid}/boards` before fetching its boards, so a user with several
workspaces paid several reads for the first paint and again on every link
change.

**Fix:** the repository now listens to the board index once per session
(`_myBoardIndex` — a shared broadcast stream, rebuilt only if the signed-in user
changes) and `watchWorkspaceBoards` joins that stream with its own links through
a new `combineLatest2` helper. Cards no longer read the index themselves, and a
workspace's board list now also refreshes when the index changes (for example
after an invite is accepted). `watchMyBoards` uses the same shared stream
instead of its own listener.

`combineLatest2` (emit once both sources have a value, then on either change;
close when both close; forward errors) is tested in
`test/web/web_mappers_test.dart`. The repository itself still has no Firestore
emulator test, which is the remaining gap in this fix.

### 5. [Fixed, low / performance] `whereIn` batches were 10 instead of 30

**Where:** `lib/web/data/web_mappers.dart` — `chunked(ids, [int size = 30])`.

Firestore accepts up to 30 values in a `whereIn`; the helper now defaults to
30, which cuts the round trips for the users/friends queries.

Boards stay at 10 on purpose. Reading a board is rule-checked with
`boardMemberDoc()` — a `get()` per candidate document — and Firestore allows 10
document reads per query, so a 30-value boards query from a user with more than
10 joined boards would be rejected with `permission-denied`. That is the same
reason `FirestoreBatchFetcher.chunkSize` is 10; `_fetchBoards` now passes that
constant explicitly, so raising the helper's default cannot silently break board
loading. `test/web/web_mappers_test.dart` asserts both the 30 default and the
explicit 10.

### 6. [Fixed, low] “Resend email” had no busy state

**Where:** `lib/web/screens/sign_in_screen.dart:462`.

`_resend()` neither disabled the button nor showed a spinner, so a double click
sent several verification emails. All other web buttons in this PR (`Accept`,
`Decline`, `Sign in`, profile save) do guard against re-entry.

**Fix:** `_resend()` now sets the screen's existing `_busy` flag for the
request, so the button is disabled (with its loading state) until the send
finishes or fails.

### 7. [Fixed, low / robustness] Shared files imported `dart:io` and checked `Platform`

`lib/core/utils/app_snackbar.dart` and
`lib/domain/services/canvas/board_export_service.dart` imported `dart:io` and
used `Platform`. The web release build succeeded and every use was guarded
(`!kIsWeb`) or unreachable on web, but a future call into
`_resolveExportDirectory()` would have crashed a browser session.

**Fix:** both checks now live behind conditional imports, the pattern
`export_directories.dart` already used:

* `lib/core/utils/test_environment.dart` exports `isFlutterTestEnvironment` from
  `test_environment_io.dart` (`Platform.environment['FLUTTER_TEST']`) or
  `test_environment_web.dart` (`false`). `app_snackbar.dart` no longer imports
  `dart:io` or `kIsWeb`; it uses the shared helper.
* `lib/domain/services/canvas/export_storage.dart` exports
  `resolveExportDirectory()`, which returns an `ExportDirectory` path wrapper
  declared in the shared library. The io branch
  (`export_storage_io.dart`) holds the previous Android/iOS/desktop folder logic
  and imports path_provider; the web branch (`export_storage_web.dart`) throws
  `UnsupportedError`. Only `.path` crosses the seam, so no `Directory` type is
  needed on the web side.

`board_export_service.dart` still imports `dart:io` for `File`, which is part of
its phone-only API (`exportBoard`, `exportCanvas`, `shareBoardFile` — the web
calls `renderCanvasExport`/`saveExportAsDownload` instead); no `Platform` or
path_provider code remains in it. `test/web/web_platform_guards_test.dart` keeps
those files free of `Platform.` and `dart:io` and keeps the seams conditional,
and `flutter build web -t lib/web/main_web.dart` succeeds with the new web
branches.

### 8. [Not fixed, informational] Browser context menu is a page-level global

**Where:** `lib/web/canvas/web_canvas.dart` (`_WebCanvasPage`).

The board disables the browser context menu on `initState` and re-enables it
on `dispose`. With the current navigation (one board at a time, the board is
popped to return to the companion) this is correct. If boards could be pushed
on top of each other, the first dispose would re-enable the menu underneath
the still-open board. Worth a stack-depth counter if board-in-board
navigation is ever added.

### 9. [By design, worth knowing] The web board keeps sync state in memory only

`MemoryCrdtLocalStore` holds the board's CRDT updates in memory, so a reload
or a long disconnect loses unsynced edits and the board is rebuilt from the
server. This is documented in `WEB_CANVAS.md`, and
`test/web/web_companion_imports_test.dart` enforces that the web app cannot
reach Isar or `path_provider`. No action needed; it is the main behavioural
difference from the phones and should be in the release notes.

### 10. [Informational] One server connection per feature, per device

`openSyncServerSocket` uses `forceNew` so board sync and board chat no longer
share (and no longer clear) each other's listeners. This is the right fix for
the lost-live-updates bug, but a device now holds separate sync, history and
chat connections instead of one. The sync server needs no change; just be aware of the extra concurrent sockets per user when looking at server load.

### 11. [Fixed, low / documentation] The web canvas plan named the wrong path for `IsarCrdtLocalStore`

**Where:** `WEB_CANVAS_PLAN.md` (§2 B and the file table).

The plan placed the store at `lib/core/database/isar_crdt_local_store.dart`
and said four files (including `canvas_event.dart`) switched to the
`LocalCrdtUpdate` conditional export. The store lives at
`lib/domain/repositories/canvas/isar_crdt_local_store.dart`, and
`canvas_event.dart` never imported the Isar record, so it was not changed by
the merge. Both statements are corrected, so the plan matches the merged
tree.

---


## Shared-code review (phone impact)

The parts of the diff that touch phone code were reviewed specifically:

* **Sync storage seam** — `IsarCrdtLocalStore` is the previous Isar queries and
  transactions moved verbatim (including “clearing a board forgets its
  cursor”), and the memory store is covered by the same contract test. No data
  migration is involved.
* **Socket separation** (`openSyncServerSocket`, `forceNew`) — verified the
  sync repository still disposes stale sockets and re-joins watched boards on
  reconnect; the chat service keeps `disableReconnection` and opens its own
  connection.
* **Text element editing bar** — the new test covers the missing-`type` crash;
  the phone layout is unchanged.
* **Edit Requests opener** — `BoardEditRequestsScreen.routeFrom` reads the
  app-wide `NotificationsBloc` on phones (provided in `lib/main.dart`), so
  behaviour there is unchanged; the web board supplies its own.
* **`GlassNavItem.badge`**, **board settings opener extraction**,
  **`AppSnackBar` web guard** — behaviour-preserving on phones.
* **Web chrome** — web-only widgets sit behind `SlidingTray.useWebLayout`
  (`kIsWeb` plus a 700 px window), so phone builds never reach them.

## Follow-ups

All three follow-ups are done in `840b97f`; Problems 3, 4, 5 and 7 above
describe the fixes, and the coverage table marks the files they touched.

| Check after the follow-ups | Result |
|---|---|
| `flutter test` | 960 tests passed |
| `flutter analyze` | No issues found |
| `dart run tool/architecture_guardrails.dart` | passed |
| `flutter build web -t lib/web/main_web.dart` | built successfully |
