# InkLink

InkLink is a Flutter app for real-time collaborative canvas workspaces with Firebase-backed sync and a BLoC + repository architecture.

## Current Implementation Snapshot

- Flutter app with feature modules under `lib/features`.
- Firebase integration for Auth, Firestore, and Cloud Functions.
- Local persistence and offline-friendly state via Isar.
- Collaborative canvas sync through CRDT update streams.
- Architecture guardrails enforced locally and in GitHub Actions.

## Architecture

The app follows this flow:

`UI (screens/widgets)` -> `BLoC` -> `Repository` -> `Services` -> `Firebase/Local DB`

Composition happens at app and route boundaries:

- `lib/main.dart` wires service and repository dependencies and app-level BLoCs.
- Route/wrapper files create feature-scoped BLoCs when needed.
- Screen files stay UI-focused and dispatch events to BLoCs.

## Key Modules

- `lib/features/auth`: sign in, sign up, session bootstrap.
- `lib/features/dashboard`: board listing and board creation flow.
- `lib/features/canvas`: collaborative board canvas state and sync.
- `lib/features/friends`: friend requests and social graph actions.
- `lib/features/profile`: profile load/update UI flow.
- `lib/features/settings`: settings state via `SettingsBloc` + repository.
- `lib/features/navigation`: bottom navigation shell and tab switching.
- `lib/features/theme`: app theme state and persistence.

## Data and Security

- Firestore rules enforce owner/member board access and friend-request constraints.
- Board reads allow owner or member access.
- CRDT update writes are constrained to board members and source client checks.

## Firebase Options and API Keys

`lib/firebase_options.dart` is generated client configuration and should be committed.

- The values there (including Firebase API keys) are client app identifiers, not server secrets.
- Real protection must come from Firebase Security Rules, Auth checks, and backend authorization.
- Do not commit service account private keys or other server-side secrets.

## Guardrails

Architecture checks live in:

- `tool/architecture_guardrails.dart`

Current enforced rules include:

1. No direct Firebase singleton access outside approved core paths.
2. No direct repository mutation calls from view files.
3. No direct repository/service reads from feature screen files.
4. No direct repository/service imports in feature screen files.

## CI Behavior

GitHub workflow:

- `.github/workflows/architecture-guardrails.yml`

Runs on:

- Every pull request.
- Pushes to `main` and `master`.

The workflow executes:

1. `dart run tool/architecture_guardrails.dart`
2. `flutter analyze`
3. `flutter test`

## Local Development

### Prerequisites

- Flutter SDK (stable channel)
- Firebase project configured for target platforms

### Setup

```bash
flutter pub get
```

### Run App

```bash
flutter run
```

### Run Quality Checks

```bash
dart run tool/architecture_guardrails.dart
flutter analyze
flutter test
```

## Project Layout (Top Level)

```text
lib/                  Flutter app source
functions/            Firebase Cloud Functions (Node.js)
tool/                 Project tooling scripts (including guardrails)
.github/workflows/    CI workflows
```

## Additional Documentation

For deeper lib-layer documentation, see:

- `lib/README.md`
