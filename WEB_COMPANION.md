# InkLink on the web

The browser version of InkLink: your boards, invites, friends, notifications and profile, and **the board itself** (drawing and live editing, see [WEB_CANVAS.md](WEB_CANVAS.md)).

It is a **separate entry point** (`lib/web/main_web.dart`). The phone app (`lib/main.dart`) builds and behaves as before: web code never imports the phone's offline database (Isar), `path_provider` or Agora, and the few shared files that changed only add web-only branches or behaviour-preserving refactors (listed in WEB_CANVAS_PLAN.md and the commit messages).

## Pages

| Page | What you can do |
|---|---|
| **Sign in** | Email/password (with email verification and password reset), or Google. Only **existing** accounts; new accounts are created in the mobile app |
| **Home** | Your boards, live: My Boards / Joined / Archived, search, and a note when invites are waiting. Click a board to open it |
| **Discover** | Public boards with search and tag filters |
| **Invites** | Accept or decline board and workspace invites (same Cloud Functions as the app) |
| **Friends** | Accept or decline friend requests; see your friends |
| **Notifications** | The in-app feed (newest 100, chat messages hidden, as on mobile); remove items |
| **Profile** | View, and edit name and bio. The photo is changed in the app |

Not on the web: creating accounts and boards, chat (direct messages), voice calls, push notifications, offline use.

## Design

The mobile app's look (Ink theme, desk background, board cards, sticky notes, paper cards, light and dark mode with a switch in the top bar), laid out for desktop: a top bar with your account, and a labelled sidebar with counts. Small windows get the phone's floating nav bar instead. Screen-reader support is on from the start (`ensureSemantics()`).

## Run and build

```bash
flutter run -d chrome -t lib/web/main_web.dart --web-port 3000
flutter build web --release -t lib/web/main_web.dart    # -> build/web

# Sample data, no Firebase (design preview): ?light / ?dark / ?signedOut /
# ?section=discover|invites|friends|notifications|profile
flutter run -d chrome -t lib/web/preview/main_web_preview.dart
```

Always pass `-t`. `.env` is bundled into the web build and is **publicly downloadable**: non-secret values only.

## Code layout

```
lib/web/
├── main_web.dart                 Entry point: dotenv, Firebase, canvas services
├── web_companion_app.dart        Ink theme (light/dark), services, sign-in gate
├── web_theme.dart                Light/dark switch, remembered in the browser
├── canvas/                       The board on the web (see WEB_CANVAS.md)
├── data/                         Firestore reads + Cloud Function calls, mappers
├── preview/                      Sample-data preview entry
├── screens/                      sign_in, home_shell (top bar, sidebar), boards
│                                 (+ discover), invites, friends, notifications,
│                                 profile
└── widgets/web_widgets.dart      Shared headers, lists, empty states, dialogs
test/web/                         Page tests, mappers, import guard
```

## Before putting it online (needs the project Owner)

Firebase Hosting, Firebase Auth authorized domains, the sync server's `CORS_ORIGIN`, and R2 CORS: see [WEB_CANVAS.md](WEB_CANVAS.md#before-putting-it-online-needs-the-project-owner).

## Known limitations

- Board previews (thumbnails) are stored on each phone, so web board cards show a placeholder.
- Role for joined boards is shown without the exact role (it lives in a subcollection the list doesn't read); inside a board the real role is used.
- `web/index.html` splash CSS is managed by `flutter_native_splash`; re-running that generator may reset it.
