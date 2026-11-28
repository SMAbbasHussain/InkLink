# InkLink on the web

The browser version of InkLink: your boards, workspaces, invites, friends, notifications and profile, and **the board itself** (drawing and live editing, see [WEB_CANVAS.md](WEB_CANVAS.md)).

It is a **separate entry point** (`lib/web/main_web.dart`). The phone app (`lib/main.dart`) builds and behaves as before: web code never imports the phone's offline database (Isar), `path_provider` or Agora, and the few shared files that changed only add web-only branches or behaviour-preserving refactors (listed in WEB_CANVAS_PLAN.md and the commit messages).

## Pages

| Page | What you can do |
|---|---|
| **Sign in** | Email/password **and account creation in the browser** (both with email verification and password reset), or Google for existing accounts. A board link opened while signed out says a board is waiting and continues to it after sign-in |
| **Home** | Your boards, live: My Boards / Joined / Archived, search, and a note when invites are waiting. Click a board to open it; the header creates or joins by code, and each card's menu renames, tags, re-configures, copies, archives, pauses or deletes it |
| **Workspaces** | Your workspaces (owned and joined), live, with search. Create one, use **Manage boards** to add or remove boards, and see every member with their role: the owner can change a role, remove a member, invite by email, edit the name and description, or delete the workspace, and a member can leave |
| **Discover** | Public boards with search and tag filters; join a public board from its card menu |
| **Invites** | Accept or decline board and workspace invites (same Cloud Functions as the app) |
| **Friends** | Accept or decline friend requests; see your friends; add a friend by email; block, unblock or unfriend; see your blocked list |
| **Notifications** | The in-app feed (newest 100, chat messages hidden, as on mobile); unread dots, mark all read, type filters, tap-through to the board, and remove items |
| **Profile** | View, edit name and bio, and change the profile photo |
| **Settings** | Canvas preferences, alert preferences, privacy (public profile, online status, email), preferred content tags, clear cache, sign out and delete account |

Not on the web: chat (direct messages), voice calls, push notifications, offline use, and board thumbnails (the browser has no local preview image).

Signing up in the browser writes the same `users/{uid}` profile document the phone creates on first sign-in (`uid`, `email`, `displayName`, `searchKeywords`, `friendCount`, `boardCount`, `createdAt`, `lastActive`) and sends the verification email; the new account then has to verify its email exactly like an existing password account.

Board and section URLs use hash routing (`#/board/<id>`, `#/workspaces`, ...), so a shared or bookmarked link opens that board or section.

## Installable app

The build is an installable PWA. `web/manifest.webmanifest` (linked from
`index.html`) declares the name, standalone display, the app's accent and desk
colours and real any/maskable icons generated from `images/app_icon.png`;
`web/sw.js` is a minimal, network-first service worker so the browser offers
installation without ever caching the app shell (a stale bundle cannot be
served). Both files, and `apple-touch-icon.png`, are copied into `build/web` by
the normal build.

## Design

The mobile app's look (Ink theme, desk background, board cards, sticky notes, paper cards, light and dark mode with a switch in the top bar), laid out for desktop: a top bar with your account, and a labelled sidebar with counts. Small windows get the phone's floating nav bar instead. Screen-reader support is on from the start (`ensureSemantics()`).

## Run and build

```bash
flutter run -d chrome -t lib/web/main_web.dart --web-port 3000
flutter build web --release -t lib/web/main_web.dart    # -> build/web

# Sample data, no Firebase (design preview): ?light / ?dark / ?signedOut /
# ?section=workspaces|discover|invites|friends|notifications|profile
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
│                                 (+ discover), workspaces, invites, friends, notifications,
│                                 profile
└── widgets/web_widgets.dart      Shared headers, lists, empty states, dialogs
test/web/                         Page tests, mappers, import guard
```

## Before putting it online (needs the project Owner)

Firebase Hosting, Firebase Auth authorized domains, the sync server's `CORS_ORIGIN`, and R2 CORS: see [WEB_CANVAS.md](WEB_CANVAS.md#before-putting-it-online-needs-the-project-owner).

## Known limitations

- Board previews (thumbnails) are stored on each phone, so web board cards show a placeholder.
- Link previews (`web/index.html` Open Graph tags) describe the app, not an individual board: board links are hash routes. Prefix `og:image` with the hosting origin before launch.
- Role for joined boards is shown without the exact role (it lives in a subcollection the list doesn't read); inside a board the real role is used.
- `web/index.html` splash CSS is managed by `flutter_native_splash`; re-running that generator may reset it.
