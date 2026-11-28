# InkLink Client (`lib/`) Architecture

This document outlines the design patterns, layer contracts, state management, and file structure of the InkLink Flutter client codebase in `lib/`.

---

## Architectural Flow & Layer Contracts

InkLink follows an explicit layered architecture with strict separation of concerns:

```
[ UI Layer (Screens & Widgets) ]
               │
               ▼ (Dispatches Events / Renders States)
        [ BLoC Layer ]
               │
               ▼ (Calls Domain Methods)
     [ Domain Service Layer ]  <── Orchestrates business logic, multi-repo sync
               │
               ▼ (Calls Data Contracts)
     [ Repository Layer ]      <── Pure data access & schema transformations
               │
               ▼
  [ Data Sources / Drivers ]   <── Firestore, Isar, Agora SDK, WebSocket, HTTP
```

### Layer Rules (Enforced by `tool/architecture_guardrails.dart`)
1. **Screen Files (`lib/features/**/view/*.dart`):**
   - Strictly presentational.
   - May only depend on BLoCs or UI models/tokens.
   - Never import repositories, database drivers, or domain services directly.
2. **BLoCs (`lib/features/**/bloc/*.dart`):**
   - State management via `flutter_bloc`.
   - Depend only on Domain Services.
   - Never directly import Repositories or core Database clients.
3. **Domain Services (`lib/domain/services/**/*.dart`):**
   - Own business logic, state aggregation, caching policies, and multi-source synchronization.
   - Abstract third-party hardware/APIs (Agora, Voice, Push notifications).
4. **Repositories (`lib/domain/repositories/**/*.dart`):**
   - CRUD and data-fetching operations only.
   - Transform external data structures into domain entities.
   - Never import Domain Services or invoke Cloud Functions directly.
5. **Core Wrappers (`lib/core/services/*.dart`):**
   - Encapsulate external Firebase and platform singletons (`FirestoreService`, `AuthService`, `CloudFunctionsService`, `LocalDatabaseService`).

---

## Directory Organization

See [docs/architecture/layered-architecture.md](../docs/architecture/layered-architecture.md) for the complete 5-layer contract, mobile/web composition roots, and guardrail rules.

```text
lib/
├── main.dart                      # Thin mobile entry point -> MobileDependencies.bootstrap()
├── app_view.dart                  # Mobile top-level auth/navigation switch
├── firebase_options.dart          # FlutterFire platform configurations
│
├── app/
│   ├── app.dart                   # MyApp, InitializationErrorApp, appNavigatorKey
│   ├── bootstrap/                 # Shared .env & Firebase initialization
│   └── composition/               # SharedCanvasDependencies, MobileDependencies, WebDependencies
│
├── core/
│   ├── constants/                 # Shared FirestorePaths constants (aligned with functions/)
│   ├── crdt/                      # Yjs & HLC implementations (CanvasCrdtAdapter, undo ledger)
│   ├── database/                  # Mobile Isar schemas (never imported by web)
│   ├── services/                  # Low-level service wrappers (Auth, Firestore, CloudFunctions, DeepLink, Push)
│   └── utils/                     # Network resolvers, AI feature flag, error formatters, preferences
│
├── ui/
│   ├── theme/                     # InkTheme design system (InkColors, InkTokens, InkType)
│   └── widgets/                   # Shared design-system widgets (PaperCard, GlassPanel, DeskBackground, etc.)
│
├── domain/
│   ├── models/                    # Immutable domain entities (ai, canvas, chat, friends, history, invitation, notification)
│   ├── repositories/              # Repository contracts & mobile implementations
│   └── services/                  # Shared domain services & board rules
│
├── features/                      # Mobile feature modules + shared canvas feature (`CanvasSessionView`)
└── web/                           # Web companion mirroring lib/ (core/, domain/, ui/, features/<feature>/{bloc,view}/)
```

---

## App Bootstrapping Sequence

Located in [`lib/main.dart`](main.dart):

1. **Platform Initialization:** Bind Flutter engine widgets, initialize `.env` configuration.
2. **Firebase Initialization:** Configure `Firebase.initializeApp` with `DefaultFirebaseOptions`.
3. **Core Services:** Initialize notifications (local notifications & push handlers) and open the local Isar database.
4. **Dependency Injection Hierarchy:**
   - **Infrastructure Services:** `FirestoreService`, `AuthService`, `CloudFunctionsService`, `LocalDatabaseService`, `ThemeService`, `FirebaseDatabase` (RTDB).
   - **Repositories:** Instantiated with their respective data wrappers (including `CanvasSyncRepositoryImpl`, `BoardHistoryRepositoryImpl`, `ChatRepositoryImpl`, etc.).
   - **Domain Services:** Wired with repositories and platform bridges (e.g. `AgoraChatServiceImpl`, `AgoraVoiceServiceImpl`, `BoardHistoryServiceImpl`, `AiImageService`, `BoardExportService`).
   - **App-Level BLoCs:** `AuthBloc`, `ThemeBloc`, `NavBloc`, `DashboardBloc`, `FriendsBloc`, `NotificationsBloc`, `BoardInvitationsBloc`, `WorkspaceBloc`.

---

## Feature Deep-Dives

### 1. Canvas Collaboration (`features/canvas/`)
- **CRDT Architecture:** `CanvasCrdtAdapter` wraps `yjs_dart` (`YMap('elements')` + `UndoManager` with a 15-minute local undo ledger) to produce binary delta updates persisted in Isar (`LocalCrdtUpdate`) and synchronized over Socket.IO.
- **History, AI & Media:** Includes `HistoryScreen` & `UserHistoryTimeline` for version/area scrubbing and undo requests, `AiImageBloc` & `AiRepaintScreen` for AI generation/editing/inpainting, and `MediaEditorScreen` for non-destructive image cropping/filtering.
- **Export Engine:** `BoardExportService` outputs whole-board, selection, frame, or page-preset bounds to high-resolution PNG (1×/2×/4×), PDF, or SVG formats.
- **Pin Comments:** Allows drop-pin discussions anchored to relative canvas coordinates $(x, y)$ with `@mention` notifications.

### 2. Agora-Powered Chat (`features/chat/`)
- **Zero-Firestore Chat Path:** Chat messages, group memberships, read receipts, and delivery acks run completely over the Agora Chat SDK.
- **Local Materialization:** Incoming packets and history catches are persisted locally in Isar (`LocalChatMessage`, `LocalChatConversation`) for instantaneous offline access.
- **Rich Payloads:** Supports image and file transfers, workspace invite cards, and interactive board links.

### 3. Voice Calling (`domain/services/voice/`)
- Powered by `AgoraVoiceServiceImpl` implementing the Agora RTC engine (`agora_rtc_engine`).
- Dynamically joins room channels (`board_<boardId>`) with server-minted tokens, tracks speaking participants, and renders real-time audio rings in the canvas HUD.

---

## Quality & Compliance Verification

Run the local validation suite before creating any pull request:

```bash
# 1. Enforce strict layered boundaries
dart run tool/architecture_guardrails.dart

# 2. Static analysis
flutter analyze

# 3. Unit and Widget test execution
flutter test
```
