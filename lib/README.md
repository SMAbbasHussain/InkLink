# InkLink lib/ Architecture

This document captures the current Flutter client structure in lib/.

## High-Level Layering

Dependency flow:

UI (screens/widgets) -> BLoC -> Domain Service -> Repository -> Backend/DB

Key contract:

- Screen files are UI-only and dispatch events.
- BLoCs coordinate state and call domain services.
- Domain services own orchestration and business rules.
- Repositories are data-access only.

Guardrails are enforced by tool/architecture_guardrails.dart.

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
|   |-- services/
|   |   |-- auth_service.dart
|   |   |-- cloud_functions_service.dart
|   |   |-- firestore_service.dart
|   |   |-- local_notification_service.dart
|   |   `-- messaging_service.dart
|   |-- theme/
|   `-- utils/
|-- domain/
|   |-- models/
|   |-- repositories/
|   |   |-- auth/
|   |   |-- board/
|   |   |-- canvas/
|   |   |-- friends/
|   |   |-- invitation/
|   |   |-- notification/
|   |   |-- presence/
|   |   |-- profile/
|   |   |-- settings/
|   |   `-- theme/
|   `-- services/
|       |-- auth/
|       |-- board/
|       |-- canvas/
|       |-- friends/
|       |-- invitation/
|       |-- notification/
|       |-- presence/
|       |-- profile/
|       |-- settings/
|       `-- theme/
`-- features/
    |-- auth/
    |-- board_invitations/
    |-- canvas/
    |-- dashboard/
    |-- friends/
    |-- navigation/
    |-- notifications/
    |-- profile/
    |-- settings/
    `-- theme/
```

## Startup and Composition

main.dart is the composition root.

Current startup sequence:

1. Initialize Flutter bindings and load .env.
2. Initialize Firebase via DefaultFirebaseOptions.currentPlatform.
3. Initialize notifications (local + messaging listeners).
4. Initialize theme and local database services.
5. Build app providers in this order:
   - Infrastructure services
   - Repositories
   - Domain services
   - BLoCs

Important composition detail:

- Provider order matters for dependent services (for example PresenceService before AuthSessionService).

## App-Level Providers

Main app scope includes:

- Infrastructure services: FirestoreService, AuthService, CloudFunctionsService, MessagingService, ThemeService, LocalDatabaseService.
- Repositories: Auth, Presence, Friends, Profile, Board, CanvasSync, Settings, Notification, Invitation.
- Domain services: Presence, AuthSession, Friends, Settings, Notification, Invitation, Board, Profile.
- App-level BLoCs: ThemeBloc, NavBloc, DashboardBloc, AuthBloc, FriendsBloc, NotificationsBloc, BoardInvitationsBloc.

## Routing and Feature Composition

Routing entry:

- app_view.dart routes Authenticated users to MainWrapper.
- Unauthenticated/loading/error auth states route to LoginScreen.

Main wrapper responsibilities:

- Hosts Home, Friends, and Settings tabs.
- Observes app lifecycle and updates online/offline presence.

Route-level builders:

- features/canvas/view/canvas_route.dart
- features/profile/view/profile_route.dart
- features/notifications/view/notifications_route.dart

These provide feature-scoped dependencies so screen files stay focused on rendering and dispatching events.

## Current Feature Coverage

- Auth: session restore, email/password auth, Google sign-in, sign-out.
- Dashboard: board list and board create/join/update/delete actions.
- Canvas: CRDT-based board sync and session-scoped editing state.
- Friends: search, request lifecycle, block/report/unfriend flows.
- Invitations: board invite inbox and decisions.
- Notifications: stream and lifecycle updates.
- Profile: profile load/update and image upload workflow.
- Settings: preferences and cache-related actions.
- Theme + Navigation: app-wide visual mode and tab state.

## Guardrails and Validation

Architecture checks:

- No direct Firebase singleton use outside approved core paths.
- No repository/core DB imports in BLoCs.
- No repository/service imports in feature screen files.
- No Cloud Functions imports/calls from repository files.
- No repository imports of domain services.

Run before significant refactors:

```bash
dart run tool/architecture_guardrails.dart
flutter analyze
flutter test
```

## Related Docs

- Project overview and setup: ../README.md
- Backend callable functions and conventions: ../functions/README.md
