# InkLink

InkLink is a Flutter app for collaborative canvases with Firebase-backed realtime sync, offline cache support, and a service-first BLoC architecture.

## Current Status

- Flutter client in lib/ with modular feature folders.
- Firebase Auth, Firestore, Realtime Database presence, Cloud Functions, and FCM integrations.
- Isar-backed local cache and settings storage.
- Canvas collaboration powered by CRDT sync.
- Social graph + board invitation + notifications flows are implemented.
- Architecture guardrails are enforced locally and in CI.

## Architecture

Layer flow:

UI (screens/widgets) -> BLoC -> Domain Service -> Repository -> Backend/DB

Rules enforced by tool/architecture_guardrails.dart:

- Screen files remain UI/event-dispatch only.
- BLoCs depend on domain services, not repositories.
- Repositories are data-access only.
- Domain services own orchestration/business rules.
- Direct Firebase singleton usage is restricted to approved core wrappers.
- Repositories do not call Cloud Functions directly.

Composition roots:

- lib/main.dart wires services, repositories, domain services, and app-level BLoCs.
- Route-level builders (for example canvas/profile/notifications routes) provide scoped BLoCs and services.
- lib/features/navigation/view/main_wrapper.dart manages tab shell and app lifecycle presence updates.

## Feature Areas

- lib/features/auth: email/password + Google auth and session bootstrap.
- lib/features/dashboard: boards listing and board CRUD entry points.
- lib/features/canvas: board editing, CRDT sync initialization.
- lib/features/friends: requests, friend actions, block/report/unfriend flows.
- lib/features/board_invitations: invite inbox and accept/decline.
- lib/features/notifications: in-app notification stream.
- lib/features/profile: profile load/update and photo flow.
- lib/features/settings: settings state and cache actions.
- lib/features/theme and lib/features/navigation: global app state.

## Local Development

### Prerequisites

- Flutter SDK (stable)
- Firebase project configured for client platforms
- .env file at repo root (copy from .env.example and fill values)

### Install

```bash
flutter pub get
```

### Run App

```bash
flutter run
```

### Quality Gates

```bash
dart run tool/architecture_guardrails.dart
flutter analyze
flutter test
```

## Cloud Functions (Backend)

Backend callable functions live in functions/.

```bash
cd functions
npm install
npm run serve
```

See functions/README.md for the full backend guide and function conventions.

## Security and Configuration Notes

- Commit lib/firebase_options.dart (generated client config).
- Do not commit service-account credentials or other server-only secrets.
- Keep firestore.rules and database.rules.json aligned with backend behavior.
- Keep Firestore path constants aligned between:
	- lib/core/constants/firestore_paths.dart
	- functions/src/utils/firestore_paths.js

## CI

GitHub Actions workflow .github/workflows/architecture-guardrails.yml runs on PRs and main/master pushes and executes:

1. flutter pub get
2. dart run tool/architecture_guardrails.dart
3. flutter analyze
4. flutter test

## Documentation Map

- Root overview: README.md
- App architecture details: lib/README.md
- Cloud Functions details: functions/README.md
