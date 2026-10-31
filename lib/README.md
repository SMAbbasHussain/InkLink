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

```text
lib/
├── main.dart                      # Composition root: wires all services, repos, and app BLoCs
├── app_view.dart                  # Top-level routing switch (Auth, EmailVerification, MainWrapper)
├── firebase_options.dart          # FlutterFire environment platform configurations
│
├── core/
│   ├── constants/                 # Shared collections, Firestore paths, routes, and styling tokens
│   ├── crdt/                      # Yjs & HLC implementations for conflict-free state resolution
│   ├── database/                  # Isar schemas (LocalBoard, LocalChatMessage, LocalProfile, etc.)
│   ├── services/                  # Low-level service adapters (Auth, Firestore, CloudFunctions, Push)
│   ├── theme/                     # InkTheme design system, typographic scales, tokens, and dark/light modes
│   └── utils/                     # Network resolvers, debouncers, coordinate converters, and formatters
│
├── domain/
│   ├── models/                    # Immutable domain entities (Board, Message, Profile, Workspace, etc.)
│   ├── repositories/              # Repository contracts & implementations
│   │   ├── auth/
│   │   ├── board/
│   │   ├── canvas/
│   │   ├── friends/
│   │   ├── invitation/
│   │   ├── notification/
│   │   ├── presence/
│   │   ├── profile/
│   │   ├── settings/
│   │   ├── theme/
│   │   └── workspace/
│   └── services/                  # Domain orchestration services
│       ├── auth/                  # Auth session bootstrap & token lifecycle
│       ├── board/                 # Board business rules & search
│       ├── canvas/                # Canvas snapshotting, export & board chat
│       ├── chat/                  # Agora Chat SDK integration & Isar message sync
│       ├── friends/               # Social graph operations
│       ├── invitation/            # Inbound/outbound invites
│       ├── notification/          # Notification dispatching & stream listeners
│       ├── presence/              # Realtime presence heartbeats & online tracking
│       ├── profile/               # User profiles & Cloudflare R2 uploads
│       ├── settings/              # User preferences & cache invalidation
│       ├── theme/                 # App aesthetic preferences
│       ├── voice/                 # Agora RTC voice engine & participant tracking
│       └── workspace/             # Multi-tenant workspace grouping & access roles
│
└── features/
    ├── auth/                      # Login, Registration, Google Sign-in, and Password Reset
    ├── board_invitations/         # Board invitation inbox & approval sheets
    ├── canvas/                    # Collaborative drawing viewport, tools HUD, pin comments, & voice
    ├── chat/                      # Direct messaging, group chats, reaction sheets, & media attachments
    ├── dashboard/                 # Board gallery, recent canvases, and creation dialogs
    ├── friends/                   # Friend list, user search, incoming requests, & block list
    ├── navigation/                # Bottom navigation bar & MainWrapper lifecycle listener
    ├── notifications/             # Notification feed with interactive action pills
    ├── profile/                   # User profile editor, avatar picker, and account deletion
    ├── settings/                  # App settings, cache cleaner, and theme selector
    ├── theme/                     # Theme BLoC & theme switcher
    └── workspaces/                # Workspace switcher, member roles, invite flows, & board assignment
```

---

## App Bootstrapping Sequence

Located in [`lib/main.dart`](main.dart):

1. **Platform Initialization:** Bind Flutter engine widgets, initialize `.env` configuration.
2. **Firebase Initialization:** Configure `Firebase.initializeApp` with `DefaultFirebaseOptions`.
3. **Core Services:** Initialize notifications (local notifications & push handlers) and open the local Isar database.
4. **Dependency Injection Hierarchy:**
   - **Infrastructure Services:** `FirestoreService`, `AuthService`, `CloudFunctionsService`, `LocalDatabaseService`, `ThemeService`.
   - **Repositories:** Instantiated with their respective data wrappers.
   - **Domain Services:** Wired with repositories and platform bridges (e.g. `AgoraChatServiceImpl`, `AgoraVoiceServiceImpl`).
   - **App-Level BLoCs:** `AuthBloc`, `ThemeBloc`, `NavBloc`, `DashboardBloc`, `FriendsBloc`, `NotificationsBloc`, `BoardInvitationsBloc`, `WorkspaceBloc`.

---

## Feature Deep-Dives

### 1. Canvas Collaboration (`features/canvas/`)
- **CRDT Architecture:** Changes made to canvas elements produce delta packets synchronized over Socket.IO to the relay server.
- **Export Engine:** Uses vector converters to output high-resolution PNG, PDF, or SVG formats without clipping viewport boundaries.
- **Pin Comments:** Allows drop-pin discussions anchored to relative canvas coordinates $(x, y)$.

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
