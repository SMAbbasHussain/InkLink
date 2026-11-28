# InkLink web version: audit and plan (Phase A)

> **Historical document:** Kept for project history. This initial Phase A audit predates the implemented web companion and web canvas; see [../architecture/layered-architecture.md](../architecture/layered-architecture.md) and [../web/web-companion.md](../web/web-companion.md) for the current architecture.
>
> Branch `feature/web-version`, created from `feature/ai-image-generation` at `bc8c411`, 2026-11-17.
> No app code has been changed yet. This document is for approval before Phase B.

## 1. Headline findings

1. **The offline database (Isar) cannot run on the web at all, and it blocks compiling.**
   - `flutter build web` fails with **40 errors, all in `lib/core/database/collections/*.g.dart`**: Isar's generated schema IDs are 64-bit integers that JavaScript cannot represent. There are no other compile errors.
   - Even if it compiled, Isar 3's web runtime loads `https://unpkg.com/isar@3.3.2/dist/index.js`, which **returns 404**. npm has no 3.x web build at all (only 1.0.0 and 4.0.0-dev), so Isar 3 has no working web version.
   - Isar is used by **10 repositories, about 500 lines** (chat 173, board 94, canvas sync 86, friends 85, workspace 33, invitation 27, profile 13, notification 11, settings 5, auth session 5), plus `message_reactions_sheet.dart`. It has **9 live `.watch()` streams** that feed screens.
   - **This is the biggest part of the web work.**
2. **Chat (Agora Chat SDK) has no web version.** `agora_chat_sdk` 1.4.0 supports Android and iOS only.
3. **Everything else is solvable:** Firebase (Auth, Firestore, RTDB, Functions, Messaging), Socket.IO, image picker, share and PDF all support the web. The work is in platform-specific code paths, listed below.

## 2. Dependency table

| Package | Web? | Notes / action |
|---|---|---|
| firebase_core, firebase_auth, cloud_firestore, cloud_functions, firebase_database | ✅ | Web config already exists (`firebase_options.dart`, `WEB_FIREBASE_KEY`, "inklink (web)" app in the console) |
| firebase_messaging | ⚠️ | Web push needs a `firebase-messaging-sw.js` service worker and a **VAPID key** (Owner). Recommend: **no web push in v1**; the in-app notification feed still works |
| awesome_notifications | ⚠️ | Has a web implementation, but `LocalNotificationService` already returns early on `kIsWeb`, so there's nothing to do |
| **isar_community** 3.3.2 | ❌ | See §1. Needs a web storage replacement (see §5, decision 1) |
| path_provider | ❌ | No web. Used by the Isar open, board preview PNGs (`board_repository_impl.dart`) and export (`board_export_service.dart`) |
| **agora_chat_sdk** | ❌ | Android/iOS only. Recommend hiding chat on web in v1 |
| agora_rtc_engine (voice) | ⚠️ | Supports web, but needs Agora's iris-web script in `web/index.html` and browser mic permission, plus CORS on the Node server's `/api/agora/rtc/token`. Recommend hiding in v1 and adding in v2 |
| google_sign_in 7.2.0 | ⚠️ | `GoogleSignIn.instance.authenticate()` is not supported on web. Use `FirebaseAuth.signInWithPopup(GoogleAuthProvider())` on web only |
| image_picker | ✅ | Returns bytes on web. `canvas_screen.dart:2086` uses `File(path)`, so the web path needs to read bytes instead |
| share_plus | ⚠️ | Works on web, but export should be a plain browser **download** |
| pdf, image, http, socket_io_client, google_fonts | ✅ | Their `dart:io` use is in mobile-only conditional files |
| permission_handler, shared_preferences, flutter_dotenv, rxdart, uuid, hlc, yjs_dart, lucide_icons_flutter, flutter_bloc | ✅ | Pure Dart or web-supported. `.env` is bundled and **public** on web (it holds only non-secret values today) |

## 3. App code that needs web paths

**`dart:io` imports in `lib/`** (12 files; these compile on web but throw at runtime when used):
`app_error_formatter.dart`, `app_snackbar.dart`, `board_repository_impl.dart`, `board_export_service.dart`, `agora_chat_service.dart`, `canvas_screen.dart`, `chat_bubble.dart`, `group_avatar_picker.dart`, `edit_profile_sheet.dart`, `workspace_card.dart`, `workspace_detail_screen.dart`, `board_card_frame.dart`.

**Hotspots:**
- `board_export_service.dart`: `Platform.isAndroid/isIOS`, `/storage/emulated/0/...` and `path_provider` (15 uses). On web this becomes a browser download (PNG/PDF/SVG bytes).
- `board_repository_impl.dart`: board preview PNG files on disk (10 `File`/`Directory` uses). On web, keep previews in memory or skip them.
- Avatar and preview widgets that read local files (`board_card_frame.dart`, `workspace_card.dart`, `edit_profile_sheet.dart`, `chat_bubble.dart`, `group_avatar_picker.dart`). On web, use network or memory images.
- `agora_chat_service.dart`: `Platform.isAndroid`, `File`. Not used on web if chat is hidden.

## 4. Server, cloud and web config

| Item | Status | Action |
|---|---|---|
| Socket.IO (canvas, board chat, history, voice) | ✅ | All 4 sockets use `setTransports(['websocket'])`. WebSockets are not blocked by CORS, so live sync works from any web origin |
| Node HTTP endpoints `/api/agora/chat/token`, `/api/agora/rtc/token` | ⚠️ | Subject to CORS. Default allowlist: `localhost:3000`, `inklink.web.app`, `inklink.app`. Only needed if chat/voice ship on web (not in v1) |
| `network_config.dart` | ✅ | Release builds already require https/wss. For local `flutter run -d chrome`, debug falls back to `http://10.0.2.2:3000` (emulator-only), so local web testing must set `WEBSOCKET_URL` to the Render URL (already the case in `.env`) |
| **R2 bucket CORS** | ❌ (Owner) | On web, avatars, AI images and the AI image downloads (`http.get`) are fetched by the browser and need a CORS rule on R2 allowing the web origin(s) (`http://localhost:<port>` for testing, plus the hosting domain) |
| Firebase Auth authorized domains | ⚠️ (Owner) | `localhost` is allowed by default. Add the hosting domain when deploying |
| `web/index.html`, `manifest.json` | ⚠️ | Title "inklink", description "A new Flutter project.". Rename to "InkLink" |
| Deep links | ✅ | On web, `/board/<id>` URLs come through the router; wire `onGenerateRoute` for web paths |
| Firebase Hosting | ❌ (Owner) | `firebase.json` has no `hosting` block. Add one; deploying needs the Owner (or hosting rights) |

## 5. Decisions needed

### Decision 1: local storage on web (required)
- **A. (Recommended) Storage abstraction, mobile unchanged.**
  - Move each repository's Isar reads and writes behind a small per-area "local store" interface (boards, canvas sync, friends, invitations, notifications, profile, settings, workspaces, chat).
  - **Mobile:** an Isar implementation that keeps the current code and behaviour.
  - **Web:** an in-memory implementation (v1: online-only; data reloads from Firestore on each page load; live streams via in-memory controllers).
  - The Isar generated files are imported only through conditional imports, so web never compiles them.
  - Optional later: persist web data in IndexedDB (needs one approved package, e.g. `sembast_web`).
  - **Cost:** the largest piece of work. It touches about 10 repositories (refactor only, same behaviour on mobile), guarded by the existing 355 tests plus new ones.
- B. Replace Isar on all platforms with a cross-platform database (drift or sembast). **Not recommended:** it changes mobile and needs a data migration.
- C. Ship web v1 without the repositories that use Isar. **Not workable:** boards and canvas sync are core and both use Isar.

### Decision 2: v1 scope on web (recommended)
| Area | Web v1 |
|---|---|
| Auth (email/password, verification, reset, Google via popup) | ✅ |
| Dashboard, boards (create/rename/archive/delete, tags, public discovery) | ✅ |
| Canvas: draw, shapes, text, images, eraser, undo (redo has the known main bug), live sync with phones, cursors, comments | ✅ |
| AI images (generate/edit/repaint/regenerate) | ✅ (needs R2 CORS) |
| Export PNG/PDF/SVG as a download | ✅ |
| Friends, in-app notifications, profile (avatar upload), settings, theme, workspaces | ✅ |
| Presence (tab visibility) | ✅ |
| Board chat (in-canvas, Socket.IO) | ✅ (not Agora) |
| Direct and group chat (Agora Chat) | ❌ Hidden, "available in the mobile app" |
| Voice calls (Agora RTC) | ❌ Hidden in v1, possible in v2 |
| Web push notifications | ❌ v2 (needs VAPID key) |
| Offline mode | ❌ Online-only in v1 |

### Decision 3: web UX extras (Phase D)
The canvas has no mouse-wheel, trackpad or keyboard handling today (`onPointerSignal`, `Shortcuts` etc.: 0 uses). Plan: wheel/pinch zoom and pan, Ctrl+Z / Ctrl+Y, Delete, Escape, and responsive layouts.

## 6. Plan (after approval)

| Phase | Work | Mobile impact |
|---|---|---|
| **B1** | Storage abstraction (Decision 1A): interfaces, Isar implementations (moved code), in-memory web implementations, conditional imports. Repository behaviour unchanged on mobile; tests extended | Refactor only: guardrails, analyze, 355+ tests and `flutter build apk --debug` must stay green |
| **B2** | Web-safe file code: export as download, previews in memory, image-picker bytes, avatar widgets; `kIsWeb` checks | None (mobile paths untouched) |
| **B3** | `flutter build web` and `flutter run -d chrome` working; chat and voice entry points hidden on web with a friendly message | None |
| **C** | Feature parity in the order of the prompt; Google sign-in via popup on web | None |
| **D** | Mouse/keyboard, responsive layout, `/board/<id>` URLs, title/manifest "InkLink" | Keyboard shortcuts also help tablets with keyboards; touch unchanged |
| **E** | Tests, `flutter build web --release`, `flutter build apk --debug`, WEB_SETUP.md (including Owner steps: R2 CORS, Hosting, Auth domain) | None |

**Risk:** B1 is a large refactor of the data layer. It's done file by file with tests after each repository, so any mobile regression is caught immediately.

## 7. Needs the project Owner (later, not blocking B–D)
- **R2 CORS rule** for the web origins (AI images and avatars won't load on web without it).
- **Firebase Hosting** setup and deploy, plus adding the domain to Auth authorized domains.
- (v2) VAPID key for web push; `CORS_ORIGIN` on the Render server for voice/chat token endpoints.

## 8. Baseline (same commit, verified 2026-11-17)
Guardrails pass · `flutter analyze` no issues · `flutter test` 355 passed · functions `npm test` 37 passed · `flutter build web`: **fails** (40 Isar errors, as above).
