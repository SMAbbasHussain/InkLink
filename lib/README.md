# InkLink - lib Architecture

This document describes the current implementation in the lib folder.

## Folder Structure

```text
lib/
|-- main.dart
|-- app_view.dart
|-- firebase_options.dart
|-- core/
|   |-- constants/
|   |-- crdt/
|   |-- database/
|   |   |-- collections/
|   |   `-- database_service.dart
|   |-- services/
|   |   |-- auth_service.dart
|   |   |-- firestore_service.dart
|   |   `-- cloud_functions_service.dart
|   |-- theme/
|   `-- utils/
|-- domain/
|   |-- models/
|   `-- repositories/
|       |-- auth/
|       |-- board/
|       |-- canvas/
|       |-- friends/
|       |-- profile/
|       |-- settings/
|       `-- theme/
`-- features/
    |-- auth/
    |-- canvas/
    |-- dashboard/
    |-- friends/
    |-- navigation/
    |-- profile/
    |-- settings/
    `-- theme/
```

## Startup and Dependency Composition

`main.dart` is the composition root.

Current startup flow:

1. Initialize Flutter bindings.
2. Initialize Firebase with `DefaultFirebaseOptions.currentPlatform`.
3. Load initial theme from `ThemeRepositoryImpl`.
4. Initialize local database service.
5. Build `MultiRepositoryProvider`.
6. Build `MultiBlocProvider`.
7. Start app with `MyApp` -> `AppView`.

Provided services in app scope:

- `FirestoreService`
- `AuthService`
- `CloudFunctionsService`
- `DatabaseService`

Provided repositories in app scope:

- `AuthRepository`
- `FriendsRepository`
- `ProfileRepository`
- `BoardRepository`
- `CanvasSyncRepository`
- `SettingsRepository`

Provided BLoCs in app scope:

- `ThemeBloc`
- `NavBloc`
- `DashboardBloc`
- `AuthBloc`
- `FriendsBloc`

## Routing and Feature Composition

`app_view.dart` routes by auth state:

- `Authenticated` -> `MainWrapper`
- All unauthenticated/loading/error auth states -> `LoginScreen`

`MainWrapper` owns tab shell composition:

- Tab 0: `HomeScreen`
- Tab 1: `FriendsScreen`
- Tab 2: `SettingsScreen` wrapped in a `SettingsBloc` provider

Route-level BLoC composition helpers:

- `features/canvas/view/canvas_route.dart` creates `CanvasBloc` and dispatches board sync/init events.
- `features/profile/view/profile_route.dart` creates `ProfileBloc` and dispatches profile load.

This keeps `*_screen.dart` files focused on UI + event dispatch.

## Domain Layer Pattern

Repository pattern is standardized as interface + implementation per folder:

- `auth/auth_repository.dart` + `auth/auth_repository_impl.dart`
- `board/board_repository.dart` + `board/board_repository_impl.dart`
- `canvas/canvas_sync_repository.dart` + `canvas/canvas_sync_repository_impl.dart`
- `friends/friends_repository.dart` + `friends/friends_repository_impl.dart`
- `profile/profile_repository.dart` + `profile/profile_repository_impl.dart`
- `settings/settings_repository.dart` + `settings/settings_repository_impl.dart`
- `theme/theme_repository.dart` + `theme/theme_repository_impl.dart`

## Feature Notes

### auth

- `AuthBloc` handles auth check, email/password auth, Google sign-in, and sign-out.
- `Authenticated` state currently carries `userName`, `uid`, `email`, and `photoUrl`.

### dashboard

- `DashboardBloc` owns board list streams and board actions.
- Supports create/join/rename/delete board.
- Uses one-shot effect fields in state: `joinedBoardId`, `createdBoardId`, `actionError`.

### canvas

- `CanvasBloc` is route-scoped per board session via `buildCanvasRoute`.
- Initializes CRDT sync and board sync on route entry.

### friends

- `FriendsBloc` handles friend requests and social interactions via `FriendsRepository`.

### profile

- `ProfileBloc` is composed at route level via `buildProfileRoute`.

### settings

- `SettingsBloc` manages tray tip preference and local cache clear actions.
- Uses `SettingsRepository`.

### navigation

- `NavBloc` controls tab index with `ChangeTab` events.

### theme

- `ThemeBloc` controls app `ThemeMode` and persistence.

## Architecture Guardrails

Guardrail script:

- `tool/architecture_guardrails.dart`

Current checks:

1. Blocks direct Firebase singleton use outside approved core paths.
2. Blocks direct repository mutation calls from view files.
3. Blocks direct service/repository access from feature screen files.
4. Blocks direct service/repository imports in feature screen files.

Run locally:

```bash
dart run tool/architecture_guardrails.dart
```

CI workflow:

- `.github/workflows/architecture-guardrails.yml`

Workflow steps:

1. `dart run tool/architecture_guardrails.dart`
2. `flutter analyze`
3. `flutter test`

## Working Rules for New Code

1. Add data access in services/repositories, not in screen files.
2. Add feature business logic in BLoC classes.
3. Compose new BLoCs in app root or route/wrapper files.
4. Keep screens focused on rendering and dispatching events.
5. Run guardrails, analyze, and tests before pushing.
