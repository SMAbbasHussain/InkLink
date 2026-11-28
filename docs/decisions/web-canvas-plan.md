# Web canvas plan (Phase A: audit only)

> **Historical planning record:** Implemented and later refactored under `lib/app/composition/shared_canvas_dependencies.dart` and `CanvasSessionView`. See [../architecture/layered-architecture.md](../architecture/layered-architecture.md) and [../web/web-canvas.md](../web/web-canvas.md) for current architecture.

Goal: open a board from the web companion and draw, edit, use AI images and sync live with phones, using the **mobile canvas UI unchanged** (no glass restyle). Phones must behave exactly as today and keep Isar (same database, same schemas, no migration).

Branch: `feat/web-canvas` (from `feat/web-glass-redesign` @ `7e1a4d6`).

## 0. Baseline (on `7e1a4d6`, before any change)

| Check | Result |
|---|---|
| `dart run tool/architecture_guardrails.dart` | pass |
| `flutter analyze` | no issues |
| `flutter test` | 823 passed |
| `functions` tests | 37 passed |
| `flutter build web -t lib/web/main_web.dart` | OK |
| `flutter build apk --debug` | OK (`app-debug.apk` built) |

## 1. Import chains that block the web build

I traced every import from `canvas_screen.dart`, `canvas_route.dart` and `canvas_bloc.dart`. The route reaches 133 files. Only **three links** reach something that cannot compile for the web:

| # | Chain | Blocker |
|---|---|---|
| A | `canvas_bloc.dart` → `core/database/collections/local_crdt_update.dart` (also via `canvas_event.dart`, `canvas_service.dart` and `canvas_sync_repository.dart`) | Isar collection plus its `.g.dart` (64-bit IDs) |
| B | `canvas_service.dart` → `canvas_sync_repository.dart` (interface, OK once A is cut). The **implementation** `canvas_sync_repository_impl.dart` imports `isar_community`, `LocalCrdtUpdate`, `LocalCanvasSyncState` and `LocalDatabaseService` (about 20 Isar call sites) | Isar |
| C | `canvas_screen.dart` → `dashboard/view/board_settings_route.dart` → `board_settings_screen.dart` → `auth/bloc/auth_bloc.dart` → `auth_session_service.dart` → `core/database/local_database_service.dart` | Isar |

The following compile on the web but fail **at runtime** there:

| # | Where | Problem on web |
|---|---|---|
| D | `core/utils/app_snackbar.dart:65` `Platform.environment` | Throws, so **every snackbar** in the canvas would crash on web |
| E | `board_export_service.dart`: `path_provider`, `File`, `Platform.isAndroid`; its interface returns `dart:io File` | Export writes files and has no download path |
| F | `canvas_screen.dart:4215` `File(path)` in the "Share" snackbar after export | No files on web |
| G | `canvas_screen.dart:2956` `context.read<DashboardBloc>()` (board settings) | No DashboardBloc in the web app |
| H | `voice/rtc_media_client.dart` → `agora_rtc_engine` | Agora web needs extra JS and setup; out of scope |

The following were checked and are fine on web:
- `canvas_route.dart` reads its services from `context`, so the web entry can provide its own implementations.
- `image_picker` returns bytes (`picked.readAsBytes()`; no `File`) and has a web implementation.
- `share_plus` has a web implementation.
- `socket_io_client`, `cloud_functions`, `http`, `shared_preferences`, `pdf` and `image` all work on web.
- `app_error_formatter.dart` only does an `is SocketException` type check, which is false on web.
- The bloc's services are already nullable/injected; the tests build it with only a fake `CanvasService`.
- `agora_chat_sdk` is not reachable from the canvas.

## 2. Smallest behaviour-preserving cut for each link

**A — CRDT update type.** I recommend a **conditional export** rather than a new mapped type.
- New file `lib/domain/models/canvas/crdt_update.dart`:
  ```dart
  export '../../../core/database/collections/local_crdt_update.dart'
      if (dart.library.js_interop) 'local_crdt_update_web.dart';
  ```
- `local_crdt_update_web.dart` is a plain class with the **same name and fields**, no Isar annotations, and `int id = 0`.
- Every file that imports `LocalCrdtUpdate` (the canvas bloc, the canvas service and the sync-repo interface) switches to this one import.
- Mobile gets the **identical** Isar class, so there is no mapping, no schema change and no test churn.
- The alternative from the prompt is a new plain `CrdtUpdate` type mapped inside the Isar repository. It changes the `CanvasService` and `CanvasSyncRepository` signatures and the fakes in about 17 test files, so it is a bigger and riskier diff. I'd only do it if you prefer it.

**B — Local persistence behind a store interface.**
- New `CrdtLocalStore` interface (`lib/domain/repositories/canvas/crdt_local_store.dart`). It has only the operations the sync repository performs today:
  - put/get by `updateId`;
  - list/watch by board;
  - latest-by-board;
  - delete-by-board;
  - list unsynced;
  - get/put the board sync cursor (as primitives, so `LocalCanvasSyncState` stays Isar-only);
  - a `transaction` wrapper for the places that currently write several things in one `writeTxn`.
- `IsarCrdtLocalStore` (`lib/domain/repositories/canvas/isar_crdt_local_store.dart`, mobile): the existing Isar query code moved **verbatim**, including the same `writeTxn` boundaries.
- `MemoryCrdtLocalStore` (web): online-only. A page refresh reloads from the server through the existing fetch/peer paths.
- `canvas_sync_repository_impl.dart` keeps all its socket/Firestore logic and calls the store instead of `isar`. It then compiles on web, so web and phone run the **same sync protocol code** with no copy that could drift.
- `main.dart` passes `IsarCrdtLocalStore(localDatabaseService)`.

**C, G — Board settings entry.**
- Move the body of `_openSettings` (DashboardBloc lookup plus `buildBoardSettingsRoute`) unchanged into `lib/features/canvas/view/board_settings_opener.dart`.
- `canvas_screen.dart` imports it as `board_settings_opener.dart if (dart.library.js_interop) board_settings_opener_web.dart`.
- The web version opens a small dialog: rename plus "Manage members in the app".
- `canvas_screen.dart` no longer imports the dashboard settings route or the DashboardBloc. `BoardEditRequestsScreen` is web-safe and stays.

**D — Snackbar.** `final isTestEnvironment = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');`. `kIsWeb` is the constant `false` on phones, so the result is identical there.

**E, F — Export as a browser download.**
- In the bloc's export handler, add an `if (kIsWeb)` branch. It renders the same bytes as the existing export code (the render step is exposed as a public method of `BoardExportServiceImpl`, with no logic change) and hands them to the browser.
- The download uses `share_plus` `shareXFiles` with an in-memory `XFile`, which falls back to a download when the browser has no share sheet. That package is already a dependency.
- If that fallback turns out to be poor, I would **ask you** before adding `package:web` as a direct dependency.
- The screen's "Share" snackbar action is skipped on web.
- The mobile branch is untouched.

**Board, settings and AI services on web (no shared changes):**
- `WebBoardRepository implements BoardRepository` (in `lib/web/canvas/`) is Firestore-only. It implements just the methods the canvas path needs:
  - `getBoardById`, `ensureBoardCached` (no-op), `saveBoardPreview`, `deactivateBoard` and `watchBoardById`;
  - the members, rename and access-request methods that `BoardServiceImpl` forwards.

  The remaining methods throw `UnsupportedError`. The existing `CanvasServiceImpl` and `BoardServiceImpl` are reused on top of it.
- Web `SettingsService` returns the mobile defaults (preview quality, compression, toolbar actions).
- `AiImageServiceImpl`, `BoardCommentsServiceImpl`, `BoardChatServiceImpl` and `BoardHistoryServiceImpl` are web-safe and reused as they are.

**H — Voice.** Hidden on web: `VoiceCallHud` and the call button are wrapped in `if (!kIsWeb)`. Phones are identical.

## 3. Existing files to change (and why phones don't change)

| File | Change | Why mobile is unchanged |
|---|---|---|
| `lib/features/canvas/bloc/canvas_bloc.dart` | import swap (A); `kIsWeb` export branch (E) | same class resolves on mobile; mobile branch untouched |
| `lib/features/canvas/bloc/canvas_event.dart` | import swap (A) | same class |
| `lib/domain/services/canvas/canvas_service.dart` | import swap (A) | same class |
| `lib/domain/repositories/canvas/canvas_sync_repository.dart` | import swap (A) | same class |
| `lib/domain/repositories/canvas/canvas_sync_repository_impl.dart` | Isar calls → `CrdtLocalStore` (B) | the same queries and transactions, moved verbatim into `IsarCrdtLocalStore` |
| `lib/main.dart` | construct the sync repo with `IsarCrdtLocalStore` | same database instance |
| `lib/domain/services/canvas/board_export_service.dart` | expose the existing render step as a public method (E) | no logic change |
| `lib/features/canvas/view/canvas_screen.dart` | conditional settings opener (C/G); `kIsWeb` guards for voice and the share action (F/H) | code moved verbatim; guards are const false on phones |
| `lib/core/utils/app_snackbar.dart` | `!kIsWeb &&` (D) | const false on phones |
| `test/web/web_companion_imports_test.dart` | allow the two conditional-export files; add a check that the web build reaches no Isar | test only |

New files: `crdt_update.dart`, `local_crdt_update_web.dart`, `crdt_local_store.dart`, `isar_crdt_local_store.dart`, `memory_crdt_local_store.dart`, `board_settings_opener.dart` (+ `_web`), and the web wiring in `lib/web/canvas/` (repositories, settings and the route from the companion). `tool/architecture_guardrails.dart` is checked after each step. If one of its rules blocks a new file, I'll stop and ask.

## 4. Web v1 scope

**Works on web:**
- Drawing and all canvas tools: shapes, text, sticky notes, frames, tables, layers, guides and symmetry, image import (gallery picker).
- AI image generate and edit.
- Live sync with phones (same socket protocol).
- Comments, board chat (socket), history and undo/redo.
- Export as a download.

**Hidden on web:**
- Voice calls (Agora RTC).
- Agora direct chat (not part of the canvas).
- Offline mode and local persistence (online-only; a refresh reloads from the server).
- Full board-settings screen (members and roles stay in the app; rename is available).
- Camera capture (the gallery/file picker only).

**Opening a board:** board cards in the companion push the canvas route (instead of the "open in app" dialog), and Back returns to the companion.

## 5. Owner / cloud steps (not code)

1. **R2 CORS:** allow `GET` from the web origin(s) for the AI-image and avatar bucket. Without it, CanvasKit can't draw AI images and the export can't download them.
2. **Firebase Auth → Authorized domains:** add the hosting domain once the web app is hosted (`localhost` is already allowed).
3. **Socket server CORS:** it currently allows any `localhost`/`127.0.0.1` port. The hosted web origin must be added and the server redeployed (EC2 workflow).
4. `.env` is public on web: it holds only `WEBSOCKET_URL` and non-secret config, and no secrets are added.

## 6. Risks and how each is tested

| Risk | Test |
|---|---|
| Moving Isar code into the store changes mobile sync (the sync impl has **no unit tests** today) | Phase B: a contract test suite run against `MemoryCrdtLocalStore` and `IsarCrdtLocalStore` (Isar core in tests, if it loads on this machine; otherwise I'll report that it doesn't); a review diff showing the queries and `writeTxn` blocks moved verbatim; a manual two-phone sync on the emulator plus a phone |
| The conditional export picks the wrong file | analyzer plus `flutter test` (mobile/VM picks Isar); a web build plus a guard test that the web graph has no `isar`/`core/database` |
| The settings-opener move changes navigation | the existing canvas widget tests; a manual open of board settings on the phone |
| Web runtime `dart:io` crash I missed | headless Chrome run of the web canvas (draw, AI, export) checking the console for `Unsupported operation` |
| CRDT interop between web and phone | two-client test (`two_client_invite_sync_test.dart` pattern) with the memory store; manual web ↔ phone session |
| Web memory growth on large boards | manual check with a large board; it's online-only, so a refresh clears it |
| Phone regression overall | after every step: guardrails, analyze, the full `flutter test`, and `flutter build apk --debug` at the end of Phase B and again at the end |

## Existing bugs noticed (not fixed)

- **Redo after undo re-applies the snapshot** (known; a teammate is on it).
- **`AppSnackBar` uses `Platform.environment`**: not a phone bug, but it crashes on web (cut D handles it).
- **Notification field names differ:** Cloud Functions write `fromUid/senderName/senderPic`, but the shared model reads `senderUid/senderDisplayName/senderPhotoUrl`. The web companion maps this; the phone app may show missing sender info for those notifications.

**Waiting for approval before Phase B.** Decisions for you:
1. A: conditional export (recommended) or a mapped plain type.
2. B: store interface (recommended, shared sync code) or a separate web-only sync repository (zero edits to the mobile sync file, but duplicated protocol code).
