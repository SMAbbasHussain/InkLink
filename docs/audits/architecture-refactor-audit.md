# InkLink Architecture Audit & Refactoring Plan (Phase 1)

> Date: 2026-11-28 | Branch: `refactor/architecture`

## 1. Current Architecture & Dependency Map

InkLink builds two Flutter targets from the same repository:

| Target | Entry Point | Local Storage | Real-time / Social Infra |
|---|---|---|---|
| **Mobile app** | `lib/main.dart` | Isar (`LocalDatabaseService`) + `SharedPreferences` | Firebase (Auth, Firestore, RTDB, Functions, Messaging, Crashlytics), Socket.IO, Agora Chat SDK, Agora RTC |
| **Web companion** | `lib/web/main_web.dart` | In-memory (`MemoryCrdtLocalStore`) + `SharedPreferences` | Firebase (Auth, Firestore, Functions), Socket.IO |

### Governing 5-Layer Architecture

```text
UI (Screens / Widgets)
  -> BLoC (Presentation State & Events)
    -> Domain Services (Business Rules & Orchestration)
      -> Repository Abstractions -> Repository Implementations (Data Access & Mapping)
        -> Backend / Database (Firestore, Auth, RTDB, Cloud Functions, Isar, Socket.IO, R2)
```

## 2. Concrete Architectural Problems Identified

### P1. Monolithic & Duplicated Application Composition
- `lib/main.dart` (504 lines) mixes platform bootstrap, Firebase/RTDB/notification/deep-link initialization, Isar opening, 30+ `RepositoryProvider` declarations, 8 `BlocProvider` declarations, `MyApp`, and `InitializationErrorApp`.
- `lib/web/main_web.dart`, `lib/web/web_companion_app.dart`, and `lib/web/canvas/web_canvas.dart` instantiate `AuthServiceImpl`, `FirestoreServiceImpl`, `CloudFunctionsServiceImpl`, and `SharedPreferences` independently multiple times.
- `WebCanvasServices.create()` duplicates the shared canvas service wiring (`CanvasServiceImpl`, `BoardServiceImpl`, `BoardExportServiceImpl`, `BoardCommentsServiceImpl`, `BoardChatServiceImpl`, `BoardHistoryServiceImpl`, `AiImageServiceImpl`, `SettingsServiceImpl`, `NotificationServiceImpl`) already defined in `lib/main.dart`.

### P2. Duplicated Repository Logic & Boundary Violations
- `lib/web/data/firebase_web_companion_repository.dart` (1,304 lines) is a god repository combining Auth, Profile, Account Settings, Boards, Workspaces, Invites, Friends, Blocked Users, Notifications, and direct Cloud Function invocations.
- **Board CRUD duplication:** ~320 lines of Firestore board reads/writes in `FirebaseWebCompanionRepository` duplicate `WebBoardRepository` (`lib/web/canvas/web_board_repository.dart`), which already implements the shared `BoardRepository` contract.
- **Cloud Functions boundary leaks & double invocation:**
  - `WebBoardRepository` imports `package:cloud_functions/cloud_functions.dart` and calls `FirestoreService.getHttpsCallable(...)` (`joinBoardByCode`, `deleteBoard`, `setBoardPaused`). Because `BoardServiceImpl.setBoardPaused` also invokes `setBoardPaused`, pausing a board from the web canvas calls the Cloud Function twice.
  - `FirestoreService.getHttpsCallable` (`lib/core/services/firestore_service.dart`) exposes Cloud Functions through the Firestore wrapper (used only by `WebBoardRepository`).
  - `FirebaseWebCompanionRepository` directly calls `CloudFunctionsService.httpsCallable(...)` instead of isolating backend function calls behind domain service orchestration / dedicated gateways.
- **Hardcoded Firestore paths:** `web_board_repository.dart`, `firebase_web_companion_repository.dart`, and `web_canvas_support.dart` hardcode collection/subcollection names instead of using `FirestorePaths` constants (`lib/core/constants/firestore_paths.dart` was also missing constants already present in `functions/src/utils/firestore_paths.js`).
- **Board business rules duplication:** `lib/web/data/web_board_ops.dart` duplicates board normalization/validation rules instead of sharing them from `lib/domain/`.

### P3. Inverted Domain Dependencies & SDK Leakage
- `lib/domain/models/board_edit_request.dart` imports `package:cloud_firestore/cloud_firestore.dart` only to check `Timestamp` (while other domain models use `parseDateTimeValue`).
- `lib/domain/` imports models from `lib/features/canvas/models/`:
  - `lib/domain/repositories/canvas/board_comments_repository*.dart` -> `canvas_comment.dart`
  - `lib/domain/services/canvas/board_chat_service*.dart` -> `board_chat_message.dart`
  - `lib/domain/services/voice/voice_service*.dart` -> `voice_participant.dart`
  - `lib/domain/models/canvas/canvas_element.dart` re-exports from `lib/features/canvas/models/canvas_element.dart`.

### P4. Web Presentation Layer Bypasses BLoC & Domain Services
- All 11 UI files in `lib/web/screens/` read `context.read<WebCompanionRepository>()` directly, bypassing both BLoC and Domain Service layers.
- `lib/web/canvas/web_canvas.dart` duplicates `buildCanvasRoute` (`lib/features/canvas/view/canvas_route.dart`) for BLoC provisioning and canvas settings loading.
- Minor design-system inconsistencies in `lib/web/screens/profile_page.dart` (`LinearGradient` on profile cover banner) and hardcoded `Colors.white` where `context.ink` tokens apply.

### P5. Web PWA Shell, Guardrail Gaps & Repository Organization
- `web/index.html`:
  - `og:image` and `twitter:image` reference deleted `icons/Icon-512.png` instead of `icons/pwa-512.png`.
  - `#splash-screen-style` uses `#FFFFFF` instead of `#EDEDF0` (`surfaceDesk`) and lacks a `@media (prefers-color-scheme: dark)` `#121418` rule matching `<picture id="splash">`.
  - Viewport meta locks zoom (`maximum-scale=1.0, user-scalable=no`).
- `tool/architecture_guardrails.dart`:
  - Scoped only to `lib/features/`, `lib/domain/services/`, and `lib/domain/repositories/` — does not inspect `lib/web/` or `lib/app/`.
  - Does not catch `domain -> features` imports, `domain/models -> cloud_firestore/firebase`, presentation -> repository access in `lib/web/screens/`, or circular imports.
  - Uses regexes instead of Dart AST/directive parsing.
- Root clutter: `.tmp_probe/probe4.dart`, debug logs, and 13+ root-level markdown audit/plan/guide files that belong under `docs/{architecture,development,web,audits,decisions}/`.

## 3. Planned Execution Phases

1. **Phase 1 — Audit (this document):** Map architecture, record violations, establish `refactor/architecture` branch.
2. **Phase 2 — Bootstrap & Dependency Injection:** Extract `lib/app/bootstrap/` and `lib/app/composition/` (`shared_canvas_dependencies.dart`, `mobile_dependencies.dart`, `web_dependencies.dart`, `app.dart`); thin `lib/main.dart` and `lib/web/main_web.dart`; eliminate duplicate service instantiation.
3. **Phase 3 — Repository & Data Layer:** Align `FirestorePaths` with `functions/src/utils/firestore_paths.js`; eliminate `cloud_firestore` from `board_edit_request.dart`; move shared canvas domain models out of `lib/features/canvas/models/` into `lib/domain/models/canvas/`; remove `CloudFunctions` calls from `WebBoardRepository` and `FirestoreService.getHttpsCallable`; decompose `FirebaseWebCompanionRepository` to delegate boards to `WebBoardRepository` and notifications to `WebNotificationRepository`, and introduce `WebCompanionService` (domain service layer) to own business rules and Cloud Functions orchestration.
4. **Phase 4 — Feature & Platform Separation:** Introduce focused web companion BLoCs/Cubits (`WebSessionBloc`, `WebBoardsBloc`, `WebWorkspacesBloc`, `WebSocialBloc`, `WebNotificationsBloc`, `WebSettingsBloc`) so `lib/web/screens/` strictly communicate via BLoC -> Domain Service -> Repository; unify shared canvas route BLoC wiring between mobile and web; clean up `profile_page.dart` / `web_widgets.dart` / `home_shell.dart` theme token usage.
5. **Phase 5 — Guardrails, Web Shell & Documentation:** Fix `web/index.html` (`pwa-512.png`, desk splash light/dark CSS, accessible viewport); upgrade `tool/architecture_guardrails.dart` with structured AST/directive analysis covering `lib/domain/`, `lib/features/`, `lib/web/`, `lib/app/`, and circular imports; remove `.tmp_probe/` and consolidate root docs into `docs/{architecture,development,web,audits,decisions}/` with clear historical notices and updated references.
6. **Phase 6 — Verification:** Format, `dart run tool/architecture_guardrails.dart`, `flutter analyze`, full `flutter test`, `flutter build web --release -t lib/web/main_web.dart`, and mobile build check.
