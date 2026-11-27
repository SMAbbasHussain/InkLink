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
| `flutter test` | 950 tests passed at merge; 951 after the post-merge fixes |
| `flutter build web -t lib/web/main_web.dart` | built successfully (only the wasm dry-run notice from `socket_io_common`) |
| GitHub Actions `Architecture Guardrails` on the PR head | ▲ failed before the fix → ✅ passes after it |

I did **not** click through the app in a real browser or on a phone. The
manual phone checklist in the PR description (each tool, live sync with a
second device, offline reconnect, AI generate/edit, comments, chat, voice,
export, old board) still needs a human pass, as does a browser pass of the
companion pages and the board.

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

### 3. [Not fixed, low] `WebBoardRepository` fails at runtime for any unimplemented method

**Where:** `lib/web/canvas/web_board_repository.dart:180`.

The class implements `BoardRepository` and uses `noSuchMethod` to throw
`UnsupportedError`. Nothing is broken today: the canvas only reaches
`getBoardById`, `ensureBoardCached`, `deactivateBoard` and
`saveBoardPreview`, and board management (roles, revoke, pause, members) goes
through `BoardService` → Cloud Functions. But any future canvas call to
another repository method becomes a runtime error on the web only, and the
compiler will not point at it.

Suggested follow-up: implement the used subset explicitly (or split a smaller
interface for the canvas) so the compiler flags new uses.

### 4. [Not fixed, low / performance] Workspace cards re-query the user's board index

**Where:** `lib/web/data/firebase_web_companion_repository.dart:279`
(`watchWorkspaceBoards`).

Every workspace card and every workspace-link snapshot re-reads
`users/{uid}/boards` and then the boards themselves. A user with several
workspaces pays several reads for the first paint, and again on every link
change. The results are consistent, so this is a cost/latency issue rather
than a correctness bug. Caching the board index per session (or listening to
it once and joining in memory) would remove the N+1.

### 5. [Not fixed, low / performance] `whereIn` batches are 10 instead of 30

**Where:** `lib/web/data/web_mappers.dart:56` — `chunked(ids, [int size = 10])`.

Firestore accepts up to 30 values in a `whereIn`. Using 10 is safe but triples
the number of round trips for users with many boards/workspaces. It matters
most for the workspace queries in Problem 4.

### 6. [Fixed, low] “Resend email” had no busy state

**Where:** `lib/web/screens/sign_in_screen.dart:462`.

`_resend()` neither disabled the button nor showed a spinner, so a double click
sent several verification emails. All other web buttons in this PR (`Accept`,
`Decline`, `Sign in`, profile save) do guard against re-entry.

**Fix:** `_resend()` now sets the screen's existing `_busy` flag for the
request, so the button is disabled (with its loading state) until the send
finishes or fails.

### 7. [Not fixed, low / robustness] Shared files still import `dart:io`

`lib/core/utils/app_snackbar.dart` and
`lib/domain/services/canvas/board_export_service.dart` still import `dart:io`
and use `Platform`. The web release build succeeds and every use is guarded
(`!kIsWeb`) or unreachable on web today (`_resolveExportDirectory()` is only
called from `exportBoard()`/`exportCanvas()`, which the web export path does
not use). `export_directories.dart` shows the safer pattern: a conditional
export with web stubs. Moving the remaining `Platform` checks behind the same
pattern would remove the trap of a future call into `_resolveExportDirectory()`
crashing a browser session.

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
chat connections instead of one. The sync server needs no change; just be
aware of the extra concurrent sockets per user when looking at server load.

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

## Follow-ups suggested (not done here)

1. Narrow `WebBoardRepository` to a compile-time interface (Problem 3).
2. Cache the board index for workspace views and raise `chunked` to 30
   (Problems 4–5).
3. Move the remaining `Platform` checks behind conditional imports
   (Problem 7).
