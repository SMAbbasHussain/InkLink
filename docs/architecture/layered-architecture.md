# InkLink Layered Architecture & Multi-Target Composition

This document is the authoritative architectural reference for InkLink's Flutter client (`lib/`), covering both the **mobile application** (`lib/main.dart`) and the **web companion** (`lib/web/main_web.dart`).

---

## 1. Mandatory 5-Layer Architecture

InkLink enforces a strict unidirectional dependency flow across both mobile and web:

```text
UI (Screens / Widgets)
  -> BLoC / Cubit (Presentation State & Events)
    -> Domain Services (Business Rules, Validation & Orchestration)
      -> Repository Abstractions -> Repository Implementations (Data Access & Mapping)
        -> Backend / Database (Firestore, Auth, RTDB, Cloud Functions, Isar, Socket.IO, R2)
```

### Layer Responsibilities & Allowed Dependencies

| Layer | Locations | Responsibilities | Allowed Dependencies | Forbidden Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| **1. UI (Screens & Widgets)** | `lib/features/*/view/`, `lib/web/screens/`, `lib/web/widgets/`, `lib/ui/` | Pure presentation, layout, input handling, dispatching BLoC events / Cubit actions | BLoCs/Cubits, domain models, `lib/ui/` design tokens & widgets, pure UI helpers | Repositories, domain services, Firestore/RTDB/Auth SDKs, `SharedPreferences`, local DB |
| **2. BLoC / Cubit** | `lib/features/*/bloc/`, `lib/web/bloc/` | Presentation state, stream subscriptions, mapping domain outcomes to UI state | Domain services, domain models, pure utilities | Repositories, `cloud_firestore`, `firebase_database`, `isar_community`, `shared_preferences`, `LocalDatabaseService` |
| **3. Domain Services** | `lib/domain/services/`, `lib/web/domain/` | Business rules, input validation, multi-repository orchestration, Cloud Function callables | Repository abstractions, other domain services, domain models, `CloudFunctionsService` | Concrete `*_impl.dart` repositories, `cloud_firestore`, `firebase_database`, `isar_community`, `FirestoreService`, UI/feature presentation |
| **4. Repositories** | `lib/domain/repositories/`, `lib/web/data/`, `lib/web/canvas/web_board_repository.dart` | Data access, persistence, mapping, transactions, caching | Domain models, `FirestorePaths`, `FirestoreService`, `AuthService`, local storage (`Isar` on mobile / in-memory & `SharedPreferences` on web) | Domain services, `cloud_functions`, `CloudFunctionsService`, `.httpsCallable()`, UI/presentation |
| **5. Backend / Database** | `lib/core/services/`, `lib/core/database/`, `functions/`, `server/` | Firebase SDK wrappers, Isar schemas, Socket.IO relay, Cloud Functions, R2 | External SDKs only | Higher application layers |

---

## 2. Application Bootstrap & Dependency Composition

Startup and dependency registration live under `lib/app/`, separating platform bootstrap from entry points and eliminating duplicated service wiring:

```text
lib/
├── main.dart                                      # Thin mobile entry point
├── app/
│   ├── app.dart                                   # MyApp, InitializationErrorApp, appNavigatorKey
│   ├── bootstrap/
│   │   └── firebase_bootstrap.dart                # Shared .env loading & idempotent Firebase.initializeApp
│   └── composition/
│       ├── shared_canvas_dependencies.dart        # Web-safe shared core & canvas service wiring (used by BOTH targets)
│       ├── mobile_dependencies.dart               # Mobile-only bootstrap (Isar, RTDB, FCM, DeepLink, Crashlytics, Agora)
│       └── web_dependencies.dart                  # Web-only bootstrap (MemoryCrdtLocalStore, WebBoardRepository, WebCompanionService)
└── web/
    ├── main_web.dart                              # Thin web entry point
    ├── web_companion_app.dart                     # MultiRepositoryProvider + MultiBlocProvider (6 web Cubits) + AuthGate
    ├── bloc/                                      # WebAuthCubit, WebBoardsCubit, WebWorkspacesCubit, WebSocialCubit, WebNotificationsCubit, WebSettingsCubit
    ├── domain/                                    # WebCompanionService (domain orchestration + Cloud Functions)
    ├── data/                                      # WebCompanionDataRepository, FirebaseWebCompanionRepository (pure data access), pure mappers
    ├── canvas/                                    # WebBoardRepository, WebSettingsRepository, WebNotificationRepository, WebVoiceService, buildWebCanvasRoute
    ├── screens/                                   # Presentation-only web screens communicating strictly with lib/web/bloc/
    ├── widgets/                                   # Shared web companion widgets
    └── preview/                                   # Offline sample-data preview entry & SampleWebCompanionRepository
```

### How Mobile and Web Share Logic Without Platform Leakage

1. **Shared core & canvas composition (`SharedCanvasDependencies`):** Both `MobileDependencies.bootstrap()` and `WebDependencies.bootstrap()` supply their platform-specific implementations of `BoardRepository`, `CrdtLocalStore`, `SettingsRepository`, `NotificationRepository`, and `VoiceService` into `SharedCanvasDependencies.create(...)`, which constructs the shared `CanvasService`, `BoardService`, `BoardExportService`, `BoardCommentsService`, `BoardChatService`, `BoardHistoryService`, `AiImageService`, `SettingsService`, and `NotificationService` once.
2. **Shared canvas session host (`CanvasSessionView`):** `lib/features/canvas/view/canvas_route.dart` defines `CanvasSessionView`, which loads canvas preferences and constructs `CanvasBloc` + `AiImageBloc`. Mobile's `buildCanvasRoute` mounts it directly; web's `buildWebCanvasRoute` wraps it with light desktop theme, browser context-menu toggling, and web provider scoping.
3. **Shared board domain rules (`lib/domain/services/board/board_rules.dart`):** Board name normalization/validation, tag normalization, visibility/join-policy rules, and Firestore board document field builders are pure Dart and shared across mobile and web.
4. **Zero mobile-only leakage into web:** `SharedCanvasDependencies`, `WebDependencies`, and all of `lib/web/` never transitively import `isar_community`, `lib/core/database/`, `path_provider`, `agora_chat_sdk`, `agora_rtc_engine`, or `mobile_dependencies.dart`. Platform-specific storage and native helpers sit behind conditional imports (`if (dart.library.js_interop)`).

---

## 3. Documented Architectural Exceptions

All exceptions enforced by `tool/architecture_guardrails.dart` are narrow and explicitly scoped:

1. **`lib/domain/services/auth/auth_session_service.dart` -> `LocalDatabaseService`:** Required on mobile to purge local Isar collections during sign-out and account deletion.
2. **`lib/domain/models/canvas/canvas_element.dart` & `lib/domain/services/canvas/canvas_geometry.dart`:** Legacy re-export shims preserving import paths for canvas geometry utilities shared between `BoardExportService` and `CanvasPainter`.
3. **`lib/features/auth/bloc/auth_bloc.dart` -> `package:firebase_auth/firebase_auth.dart`:** Mobile `AuthBloc` currently passes Firebase's `User?` into `AuthEmailUnverified`. Tracked as technical debt to replace with a pure domain `AuthAccount` model.

---

## 4. Running Guardrails, Tests & Builds

```bash
# 1. Enforce architectural boundaries & platform isolation
dart run tool/architecture_guardrails.dart

# 2. Static analysis
flutter analyze

# 3. Full test suite
flutter test

# 4. Web companion build (always pass -t lib/web/main_web.dart)
flutter build web --release -t lib/web/main_web.dart

# 5. Mobile Android debug build
flutter build apk --debug
```
