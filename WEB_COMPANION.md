# InkLink web companion

A small browser version of InkLink for managing your account from a computer. **Drawing and editing boards stay in the mobile app.**

It is a **separate entry point** (`lib/web/main_web.dart`). It reuses only the web-safe parts of the codebase (Firebase wrappers, data models, the Ink design system) and never imports the mobile app's offline database (Isar), screens or Agora Chat. **No existing file was changed**, so the phone app builds and behaves exactly as before. See WEB_AUDIT.md for why the full app can't run on the web as-is.

## What it does

| Page | What you can do |
|---|---|
| **Sign in** | Email/password (with email verification and password reset), or Google via a browser popup. Only **existing** InkLink accounts; new accounts are created in the mobile app |
| **Boards** | Your owned and joined boards, live, with search by title/tag and All / Owned / Joined / Archived filters. Opening a board shows a link that opens it in the phone app |
| **Discover** | Public boards (the newest 40) |
| **Invites** | Accept or decline board and workspace invites (same Cloud Functions as the app) |
| **Friends** | Accept or decline friend requests; see your friends |
| **Notifications** | The in-app feed (newest 100, chat messages hidden, as on mobile); remove items |
| **Profile** | View, and edit name and bio (the same fields the app writes). The photo is changed in the app |

Not on the web: drawing and editing boards, AI images, chat, voice, push notifications, creating accounts, offline use. It works **online only**.

Layout: a side rail on wide screens, a bottom bar on narrow ones, light and dark mode following the system.

## Run and build

```bash
# Run locally in Chrome
flutter run -d chrome -t lib/web/main_web.dart

# Production build -> build/web
flutter build web --release -t lib/web/main_web.dart
```

Always pass `-t lib/web/main_web.dart`. Without it, Flutter builds the mobile entry point (`lib/main.dart`), which **cannot** compile for the web (Isar).

`.env` is bundled into the web build and is **publicly downloadable**. It must only ever hold non-secret values (as today: Firebase web API keys, the server URL, feature flags).

## Code layout (all new files)

```
lib/web/
├── main_web.dart                 Entry point: dotenv, Firebase, runApp
├── web_companion_app.dart        Theme, services, sign-in gate
├── data/
│   ├── web_companion_repository.dart   Firestore reads + Cloud Function calls
│   └── web_mappers.dart                Pure helpers (tested)
├── screens/                      sign_in, home_shell, boards (+ discover),
│                                 invites, friends, notifications, profile
└── widgets/web_widgets.dart      Shared tiles, lists, dialogs
test/web/
├── web_mappers_test.dart
└── web_companion_imports_test.dart   Fails if lib/web ever reaches Isar,
                                      path_provider or Agora Chat
```

## Before putting it online (needs the project Owner)

1. **Firebase Hosting:** add a `hosting` block to `firebase.json` pointing at `build/web` (with a rewrite of `**` to `/index.html`), then `firebase deploy --only hosting`.
2. **Firebase Auth → Settings → Authorized domains:** add the hosting domain (for Google sign-in popups). `localhost` already works for testing.
3. **R2 CORS (optional):** profile photos are loaded by the browser. If avatars show initials instead of photos on the web, add a CORS rule on the R2 bucket allowing the web origin.

## Known limitations
- `web/index.html` and `web/manifest.json` still say "inklink" / "A new Flutter project." They were left unchanged to keep this change additive. Rename later if wanted.
- Board previews (thumbnails) are stored on each phone, not in the cloud, so the web shows board cards without previews.
- The "open in the app" link (`https://inklink.app/board/<id>`) opens the board on a phone with InkLink installed and app links verified.
- Role for joined boards is shown as "Member" (the exact role lives in a subcollection the companion doesn't read).
