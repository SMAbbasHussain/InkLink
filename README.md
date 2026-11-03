# InkLink

InkLink is a real-time collaborative canvas and digital whiteboard application built with Flutter, powered by CRDT-based synchronization, an Agora-backed chat and voice media engine, Redis-cached state sync, Firebase backend integrations, and an offline-first Isar database architecture.

---

## System Architecture Overview

```
                      +------------------------------------------------+
                      |                 Flutter Client                 |
                      |  UI (Screens/Widgets) -> BLoC -> Domain Service|
                      |            -> Repository -> Data Sources       |
                      +-------------------+-------+--------------------+
                                          |       |
            +-----------------------------+       +-----------------------------+
            | HTTP / REST                         | WebSockets (Socket.IO)       | Agora SDK
            v                                     v                             v
+-----------------------+              +-----------------------+     +--------------------+
| Firebase Cloud Funct. |              | Node.js Relay Server  |     | Agora Cloud Netw.  |
| - Auth & Profiles     |              | - Realtime CRDT Relay |     | - P2P/Group Chat   |
| - Friends & Relations |              | - Offline Redis Queue |     | - Voice RTC Call   |
| - Workspace Mgmt      |              | - Board Chat History  |     | - Presence/Receipts|
| - Cloudflare R2 Upload|              | - Voice State Signals |     +--------------------+
+-----------+-----------+              | - Agora Token Minting |
            |                          +-----------+-----------+
            v                                      |
+-----------------------+                          v
| Cloud Firestore & RDB |              +-----------------------+
| - Metadata & Presence |              | Redis (Persistence)  |
+-----------------------+              | - CRDT Buffer (7-day) |
                                       | - Board Chat (90-day) |
                                       +-----------------------+
```

---

## Core Capabilities & Features

### 1. Collaborative Real-Time Canvas
- **Yjs CRDT Engine:** Low-latency vector strokes, shapes, sticky notes, text, and connector lines synchronized with conflict-free replicated data types.
- **Layering & Media:** Drag-and-drop image placement, live remote cursors, natural painter z-ordering, stroke smoothing, and pan/zoom canvas manipulation.
- **Export Formats:** Full vector and raster export (PNG, PDF, SVG) with background preservation and native platform sharing.
- **Pin Comments & Threads:** Contextual pin annotations anchored to canvas coordinates with @mention alert delivery.

### 2. High-Performance In-App Communication
- **Direct & Group Chat (Agora-backed):** Real-time text messaging, media/file sharing, rich board/workspace snippet cards, emoji reactions with user inspection sheets, blue-tick read receipts, and message recall.
- **Live Voice HUD (Agora RTC):** Board-scoped multi-party audio calls with real-time active speaker visualizers, join/leave state synchronization, and background HUD controls.
- **Board Chat:** Socket-relayed, Redis-persisted instant board chat room with history replay up to 90 days.

### 3. Workspaces & Access Control
- **Team Workspaces:** Hierarchical organization of boards with granular role-based permissions (Owner, Admin, Member, Viewer).
- **Public Discovery & Deep Links:** Direct links to boards, invite code join workflows, and in-app request-to-access decision queues.

### 4. Offline-First Synchronization & Caching
- **Isar Database:** Local-first message queues, offline draft storage, conversation caching, and instant startup hydration.
- **Redis Sync Buffer:** Server-side Redis queue with 7-day TTL ensuring mobile clients catch up smoothly after offline periods.

---

## Monorepo Layout

| Directory | Purpose | Primary Technologies |
| :--- | :--- | :--- |
| **`lib/`** | Multiplatform Flutter application client | Flutter 3.35+, Dart 3.9.2+, BLoC, Isar, Agora Chat/RTC SDKs |
| **`server/`** | Real-time WebSocket relay & Agora token minter | Node.js, Express, Socket.IO, Redis (ioredis), Firebase Admin, Agora Token SDK |
| **`functions/`** | Serverless backend callable cloud functions | Node.js 22, Firebase Functions v2, Cloud Firestore, Cloudflare R2 |
| **`tool/`** | Developer tooling and architecture validation scripts | Dart CLI |

---

## Architecture Principles & Guardrails

The Flutter application enforces a strict unidirectional dependency chain:

$$\text{UI (Screens/Widgets)} \longrightarrow \text{BLoC} \longrightarrow \text{Domain Service} \longrightarrow \text{Repository} \longrightarrow \text{Backend / Database}$$

Enforced locally and in CI via `tool/architecture_guardrails.dart`:
- **Screen Files:** Strictly declarative rendering and event dispatching. No repositories, services, or raw database calls.
- **BLoCs:** Coordinate state and interact solely with Domain Services.
- **Domain Services:** Encapsulate business logic, orchestration, and validation.
- **Repositories:** Abstract raw data sources (Firestore, Isar, REST APIs, WebSockets). Repositories do not import Domain Services or invoke Cloud Functions directly.
- **Security Boundary:** Firebase singleton instantiation is guarded through core service wrappers (`FirestoreService`, `AuthService`, etc.).

---

## Local Development & Setup

### Prerequisites
- **Flutter SDK:** Stable channel (3.35+ / Dart 3.9.2+, matching `sdk: ^3.9.2` in `pubspec.yaml`)
- **Node.js:** v20+ or v22 LTS
- **Redis Server:** Running locally (`redis://127.0.0.1:6379`) or a provisioned cloud instance
- **Firebase CLI:** Installed and authenticated (`firebase login`)
- **Agora Console Account:** App ID, App Certificate, and Chat REST credentials

---

### Step 1: Environment Configuration

1. **Client Configuration (`.env` in repo root):**
   ```bash
   cp .env.example .env
   ```
   Fill in your Firebase web client ID, Agora App ID, WebSocket URL, and server endpoints.

2. **Server Configuration (`server/.env`):**
   ```bash
   cd server
   cp .env.example .env
   ```
   Configure `REDIS_URL`, `FIREBASE_SERVICE_ACCOUNT_JSON` (or `SERVICE_ACCOUNT_PATH`), `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, and `AGORA_CHAT_*` credentials.

3. **Cloud Functions Configuration (`functions/`):**
   Ensure runtime secrets for Cloudflare R2 (`CLOUDFLARE_R2_ACCESS_KEY`, `CLOUDFLARE_R2_SECRET_KEY`, etc.) are configured if deploying photo uploads.

---

### Step 2: Install Dependencies

```bash
# 1. Flutter app
flutter pub get

# 2. Node.js WebSocket server
cd server && npm install && cd ..

# 3. Firebase Cloud Functions
cd functions && npm install && cd ..
```

---

### Step 3: Running the Stack

#### Start Node.js WebSocket Server:
```bash
cd server
npm start
```
*Server starts on `http://localhost:3000` (or `PORT` defined in `server/.env`).*

#### Start Firebase Functions Emulator (Optional for local functions):
```bash
cd functions
npm run serve
```

#### Run Flutter Client:
```bash
flutter run
```

---

## Quality Gates & Verification

Run all mandatory quality checks before committing or opening a pull request:

```bash
# 1. Architecture rule verification
dart run tool/architecture_guardrails.dart

# 2. Dart static code analysis
flutter analyze

# 3. Automated unit and widget tests
flutter test
```

---

## Continuous Integration (CI)

GitHub Actions workflow (`.github/workflows/architecture-guardrails.yml`) automatically runs on every pull request and push to `main`:
1. `flutter pub get`
2. `dart run tool/architecture_guardrails.dart`
3. `flutter analyze`
4. `flutter test`

---

## Documentation Sub-Guides

- [Flutter Client Architecture & Module Map](lib/README.md)
- [Node.js WebSocket & Agora Relay Server](server/README.md)
- [Firebase Cloud Functions Specification](functions/README.md)
