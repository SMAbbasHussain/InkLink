# InkLink

InkLink is a real-time collaborative canvas and digital whiteboard application built with Flutter, powered by CRDT-based synchronization, an Agora-backed chat and voice media engine, Redis-cached state sync, Firebase backend integrations, and an offline-first Isar database architecture.

---

## System Architecture Overview

```
                      +------------------------------------------------+
                      |                 Flutter Client                 |
                      |  UI (Screens/Widgets) -> BLoC -> Domain Service|
                      |            -> Repository -> Data Sources       |
                      +-------+---------------+---------------+--------+
                              |               |               |
            +-----------------+               |               +-----------------+
            | HTTP / Callable                 | WebSockets (Socket.IO)          | Agora SDK
            v                                 v                                 v
+-----------------------+         +-----------------------+         +--------------------+
| Firebase Cloud Funct. |         | Node.js Relay Server  |         | Agora Cloud Netw.  |
| - Auth & Profiles     |         | - Realtime CRDT Relay |         | - P2P/Group Chat   |
| - Friends & Relations |         | - Redis Stream Buffer |         | - Voice RTC Call   |
| - Workspace & Boards  |         | - History & Revert    |         | - Presence/Receipts|
| - AI Image (WorkersAI)|         | - Board Chat History  |         +--------------------+
| - Cloudflare R2 Upload|         | - Voice State Signals |
+-----------+-----------+         | - Agora Token Minting |
            |                     +-----------+-----------+
            v                                 |
+-----------------------+                     +-------------------+
| Cloud Firestore & RDB |                     |                   |
| - Metadata & Presence |                     v                   v
| - Activity Index      |         +-------------------+ +--------------------+
+-----------------------+         | Redis (Cache/Log) | | Cloudflare R2      |
                                  | - CRDT Stream Log | | - History Blocks   |
                                  | - Board Chat (90d)| | - State Milestones |
                                  +-------------------+ | - Avatars & AI Img |
                                                        +--------------------+
```

---

## Core Capabilities & Features

### 1. Collaborative Real-Time Canvas
- **Yjs CRDT Engine:** Low-latency vector strokes (8 brush presets, pressure/tilt, stabilizer, QuickShape), shapes (labels, free aspect, independent fill/stroke colors, flips, dashes, arrowheads), sticky notes, rich-styled text, tables (`TableElement` up to 200 cells), and smart connectors (straight/curved/elbow with labels & anchors) synchronized with conflict-free replicated data types.
- **Layers, Frames & Media Tools:** Named layers as paint bands with per-layer opacity & blend modes, lock/hide, titled section frames with optional content clipping and frame-or-contents deletion, auto-layout/mind-map arrangement (`grid`/`row`/`column`/`tree`/`flow`), rulers/guides/snap/symmetry/perspective guides, mobile camera/gallery media editor (non-destructive crop, filters, flips, reference mode), starter templates (gallery filters + board creation flow), mobile long-press context menu, and minimap/pan/zoom controls.
- **Scoped Export Formats:** Export whole board, current selection, frame, or page preset bounds to PNG (1×/2×/4×, optional transparent background & pattern), PDF, and SVG with live pixel output dimensions and native share sheet integration.
- **Version History & Undo Requests:** Owner version history refresh & older-version fetching, R2-archived op blocks & milestone checkpoints, area-scoped history scrub/revert, and member desired-state sliders (`Only my changes` vs `Whole area state`) with owner Requested ↔ Current comparison.
- **AI Image Generation & Editing:** Prompt-based image generation, image-to-image editing, and masked inpainting (`generateAiImage`, `editAiImage`, `inpaintAiImage`) powered by Cloudflare Workers AI (`flux-2-klein-4b` / `flux-1-schnell`) and stored in Cloudflare R2, gated by `AI_IMAGE_ENABLED`.
- **Pin Comments & Threads:** Contextual pin annotations anchored to canvas coordinates with @mention alert delivery.

#### Known Canvas Gaps
- **Desktop & Web Input (`C-16`, `F-21` desktop):** Desktop keyboard shortcuts and secondary-click context menus are intentionally omitted in favor of mobile touch gestures and the mobile long-press menu; Isar's 64-bit IDs target native mobile/desktop builds rather than Flutter web.
- **Rich Text Spans:** Multi-style inline text spans within a single text element are omitted in favor of element-level typography styling.
- **Table & Frame Scope Limits:** Tables omit merged `colSpan`/`rowSpan` cells, and frames omit nested sub-frames.

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
| **`packages/yjs_dart/`** | Local pure-Dart Yjs v14 CRDT package override | Dart 3+ (`yjs_dart` v1.1.15) |
| **`server/`** | Real-time WebSocket relay, history/revert engine & Agora token minter | Node.js, Express 5, Socket.IO, Yjs, Redis (ioredis), Cloudflare R2, Firebase Admin, Agora Token SDK |
| **`functions/`** | Serverless backend callable cloud functions | Node.js 22, Firebase Functions v2, Cloud Firestore, Cloudflare R2 & Workers AI, Sharp |
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
- **Flutter SDK:** Stable channel (3.44+ / Dart 3.12+, matching `sdk: ^3.12.0` in `pubspec.yaml`)
- **Node.js:** v22 LTS (required by `firebase-admin` 14)
- **Redis Server:** Running locally (`redis://127.0.0.1:6379`) or a provisioned cloud instance
- **Firebase CLI:** Installed and authenticated (`firebase login`)
- **Agora Console Account:** App ID, App Certificate, and Chat REST credentials

---

### Step 1: Environment Configuration

1. **Client Configuration (`.env` in repo root):**
   ```bash
   cp .env.example .env
   ```
   Fill in your Firebase platform keys, `FIREBASE_RTDB_URL`, `WEBSOCKET_URL`, `AGORA_APP_ID`, `AI_IMAGE_ENABLED`, and Cloudflare R2 config.

2. **Server Configuration (`server/.env`):**
   ```bash
   cd server
   cp .env.example .env
   ```
   Configure `REDIS_URL`, Firebase Admin credentials (`FIREBASE_SERVICE_ACCOUNT_JSON`, `SERVICE_ACCOUNT_PATH`, etc.), `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`, `AGORA_CHAT_*`, and `CLOUDFLARE_R2_HISTORY_BUCKET` credentials.

3. **Cloud Functions Configuration (`functions/`):**
   Configure runtime secrets for Cloudflare R2 (`CLOUDFLARE_R2_ACCESS_KEY`, `CLOUDFLARE_R2_SECRET_KEY`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_R2_BUCKET`, `CLOUDFLARE_R2_PUBLIC_URL`, `CLOUDFLARE_R2_HISTORY_BUCKET`) and Cloudflare Workers AI (`CLOUDFLARE_AI_API_TOKEN`, `CLOUDFLARE_AI_ACCOUNT_ID`) for AI image generation.

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

# 3. Automated unit and widget tests (Flutter + Server + Functions)
flutter test
cd server && npm test && cd ..
cd functions && npm test && cd ..
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
- [Yjs Dart CRDT Package](packages/yjs_dart/README.md)
