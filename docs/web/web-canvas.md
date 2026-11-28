# InkLink boards on the web

Open a board from the web app (`lib/web/main_web.dart`) and draw, edit and collaborate in the browser, live with phones. The board is the **same canvas as the mobile app** (same tools and sync code), with a desktop layout. Phones are unchanged: everything web-specific is behind a browser check, a conditional import or the web entry point.

See [web-companion.md](web-companion.md) for the rest of the web app (boards list, invites, friends, notifications, profile) and [../decisions/web-canvas-plan.md](../decisions/web-canvas-plan.md) for the historical design decisions.

## Run and build

```bash
# Run locally in Chrome (any port works with the local sync server)
flutter run -d chrome -t lib/web/main_web.dart --web-port 3000

# Production build -> build/web
flutter build web --release -t lib/web/main_web.dart
```

Always pass `-t lib/web/main_web.dart`; `lib/main.dart` is the phone app and does not compile for the web. `.env` is public in a web build: it may only hold non-secret values (the sync server URL is read from `WEBSOCKET_URL`).

## What works on the web

| Feature | Web |
|---|---|
| Pen, highlighter, eraser, shapes, arrows, sticky notes, text, frames, tables, images from your computer | Yes |
| Select (one click), move, resize, rotate, layers | Yes |
| Live sync with phones (same Socket.IO server and protocol) | Yes |
| AI images (generate, edit, repaint) | Yes (needs R2 CORS, below) |
| Comments, board chat, history, undo (redo has a known bug shared with mobile) | Yes |
| Export PNG / PDF / SVG | Yes, as a browser download |
| Voice calls | Mobile only (shows a message) |
| Full board settings (members, roles, delete) | Mobile only (shows a message) |
| Offline drawing | No: the web keeps the board in memory and reloads it from the server |

## Desktop layout

Floating bars in the corners: back, board menu, save status and title, export, search (top left); comments, chat, AI and media, layers, members, **Share**, edit requests (top right); a tool rail (left); minimap toggle (bottom left); selection mode, zoom, undo/redo and history (bottom right). Trays are compact panels instead of phone sheets. The board always uses the light theme. Phones keep their layout.

## Keyboard and mouse

| Action | Shortcut |
|---|---|
| Undo / Redo | Ctrl+Z / Ctrl+Y or Ctrl+Shift+Z |
| Delete selection | Delete or Backspace |
| Clear selection, close panels | Escape |
| Copy / Paste / Duplicate | Ctrl+C / Ctrl+V / Ctrl+D |
| Select all | Ctrl+A |
| Zoom in / out / reset | Ctrl+= / Ctrl+- / Ctrl+0, or Ctrl+mouse wheel |
| Tools | V select, H hand, P pen, E eraser, T text, S shapes |
| Pan | Mouse wheel / trackpad, middle-button drag, or Space+drag |
| Canvas menu | Right-click |

(Cmd instead of Ctrl on a Mac.) Shortcuts are ignored while you type in a text box or dialog.

## Before putting it online (needs the project Owner)

1. **Firebase Hosting:** add to `firebase.json`, then `firebase deploy --only hosting`:
   ```json
   "hosting": {
     "public": "build/web",
     "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
     "rewrites": [{ "source": "**", "destination": "/index.html" }]
   }
   ```
2. **Firebase Auth → Settings → Authorized domains:** add the hosting domain (Google sign-in). `localhost` already works.
3. **Sync server CORS:** set `CORS_ORIGIN` on the Node server to include the hosting origin (comma-separated, e.g. `https://inklink-xxxx.web.app`) and redeploy it. Any `localhost` port is already allowed.
4. **R2 CORS** (AI images, avatars and exports that include them): on the R2 bucket, allow `GET` from the web origins, for example:
   ```json
   [{ "AllowedOrigins": ["http://localhost:3000", "https://inklink-xxxx.web.app"],
      "AllowedMethods": ["GET"], "AllowedHeaders": ["*"], "MaxAgeSeconds": 3600 }]
   ```

## How it is built (for developers)

- **Entry and services:** `lib/web/features/canvas/view/web_canvas_route.dart` (composed via `lib/app/composition/web_dependencies.dart` and `SharedCanvasDependencies`) builds the canvas with web-safe services: `WebBoardRepository`, `WebSettingsRepository`, `WebNotificationRepository`, `WebVoiceService`, and the shared `FirestoreCanvasSyncRepository` on `MemoryCrdtLocalStore`.
- **Storage seam:** the sync repository stores updates through `CrdtLocalStore` (`IsarCrdtLocalStore` on phones, `MemoryCrdtLocalStore` on the web). `LocalCrdtUpdate` comes through `lib/domain/models/canvas/crdt_update.dart`, a conditional export (the Isar class on phones, a plain class on the web).
- **Conditional imports:** board settings opener and export folders (`path_provider`) have web versions.
- **Layout and input:** `lib/features/canvas/view/canvas_screen_web.dart` (desktop bars, rail, shortcuts); trays in `widgets/sliding_tray.dart`. All behind `SlidingTray.useWebLayout`, which is false on phones.
- **Guard test:** `test/web/web_companion_imports_test.dart` fails if the web app ever reaches Isar, `path_provider` or Agora.

## Test checklist

Web (signed in, two windows or web + phone on the same board): open a board; draw with every tool; select, move, resize, delete, undo; see each other's changes live; add a sticky note and text; add an image from the computer; generate and edit an AI image; add a comment and a chat message; open history; export PNG, PDF and SVG; try the shortcuts; reload and confirm the board loads.

Phone regression (Android, `flutter run -d <device>`): draw with each tool, live sync with another device, offline drawing then reconnect, undo, AI generate/edit, comments, board chat, voice join, export, open an old board.

## Known limitations

- Redo after undo can fail (existing bug, shared with mobile; being fixed separately).
- Selecting a text element and then resizing can leave the selection frame at the old size until it is reselected (seen on the web; likely shared).
- The board is online-only on the web; a very slow first connection waits up to 10 seconds.
- Board previews (thumbnails) are stored on each phone, so web board cards show a placeholder.
