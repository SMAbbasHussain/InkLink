# Web companion follow-ups: what was implemented

This pass took the top code-only items from the ranked follow-up list for the
web companion (`WEB_COMPANION.md`) and implemented them end to end with tests.
Items that need an owner decision, hosting credentials, storage products or a
browser-automation harness were deliberately left for a later pass; they are
listed at the end with the reason.

Nothing here is committed.

## 1. Self-serve account creation in the browser (ranked item 2)

Before: the web companion could only sign in to accounts that already existed,
because sign-up lived in the mobile app. A person who received a board link,
had no phone app, and clicked through to the site hit a form they could not
complete.

Now the sign-in screen has two modes and the reference flow is complete:

- **Repository contract** — `WebCompanionRepository.signUpWithEmail({name,
  email, password})` (`lib/web/data/web_companion_repository.dart`).
- **Firebase implementation** (`lib/web/data/firebase_web_companion_repository.dart`)
  creates the Firebase user, sets its display name, writes the same
  `users/{uid}` profile document the phone writes on first sign-in (`uid`,
  `email`, `displayName`, `photoURL`, `searchKeywords` from
  `generateSearchKeywords`, `friendCount: 0`, `boardCount: 0`, `createdAt`,
  `lastActive`), and sends the verification email. It uses `set(..., merge:
  true)`, so it can never clobber an existing profile. No Cloud Function is
  needed: `firestore.rules` already allows a signed-in user to write their own
  `users/{uid}` document.
- **Failure handling** — the display-name write and the verification email are
  best-effort: if either fails, the account still exists, the profile can be
  written on the next sign-in and the verify screen can resend. Auth errors map
  to readable messages, with three new codes: `email-already-in-use`,
  `weak-password`, `operation-not-allowed`.
- **Sample repository** (`lib/web/preview/sample_web_repository.dart`) follows
  the same rules (name, a real-looking address, 6+ character password, no
  duplicate email) so the preview and the page tests exercise the same shape.
  Its `reloadEmailVerified()` now actually marks the account verified and
  emits, which is what `user.reload()` does in the real app.
- **UI** (`lib/web/screens/sign_in_screen.dart`): a `Create account` link
  switches the form to a name + email + password form ("Create your account",
  "Free, in the browser. No phone needed."). Client-side checks report a
  missing name or a password under six characters before any network call.
  Google sign-in stays in the sign-in form only, because its popup is wired to
  an existing InkLink profile.
- **Verification still applies**: a newly created password account has
  `emailVerified == false`, so the existing auth gate shows the verify screen
  (with resend) before the pages. That is the same treatment as an existing
  password account that has not verified, and it is now covered by a test.

## 2. Board links no longer dead-end when signed out (ranked item 2/13)

`WebCompanionApp` passes the deep-linked board id into the sign-in screen
(`WebSignInScreen(targetBoardId: initialBoardId)`). When a `#/board/<id>` link
arrives signed out, the form shows a highlighted note — "A board is waiting for
you. Sign in or create an account to open it." — and after successful sign-in
the shell's existing post-frame deep-link handler opens that board (or reports
it, in the sample preview). This closes the loop that board sharing exists for:
the link now explains itself and continues where it left off.

## 3. Board cards have a real accessible name (ranked item 7)

`lib/web/screens/boards_page.dart` wrapped each card in `Semantics(button:
true, label: board.title)` without `container: true`. In a live browser run the
card nodes were absent from the accessibility tree (only the unlabelled "Board
options" buttons appeared), so the grid read as anonymous buttons.

The card node is now a semantics container with a full sentence: `Board
<name>. <tags> • Edited <when>`. The per-card menu button keeps its own name
inside that node, so a screen reader announces "Board Q3 roadmap. #planning
#team • Edited 12m ago, button" and then "Board options, button". No behaviour
changed: `find.byTooltip('Board options')` still works for the existing tests.

## 4. Share metadata for links (ranked item 13)

`web/index.html` now ships Open Graph and Twitter card tags (title,
description, image, `summary_large_image`) so board links unfurl with the
product name and description in Slack, Discord, Messages and social apps
instead of a bare URL. A comment records the two known limits: board links are
hash routes, so the tags describe the app rather than one board, and `og:image`
should be prefixed with the hosting origin before launch because crawlers
prefer absolute URLs.

## 5. Installable web app (PWA, ranked item 16)

Before this pass the build shipped Flutter's default template manifest
(`manifest.json`), the stock Flutter logo icons, and no service worker at all:
Chrome never offered to install it, and the icons did not represent InkLink.

What the shell now contains (all under `web/`, copied verbatim into
`build/web`):

- **`web/manifest.webmanifest`** — `name`/`short_name` "InkLink",
  `description`, `id`/`start_url`/`scope` all `./` so it works from the site
  root or a hosting path, `display: standalone`, `orientation: any`,
  `theme_color #6A4EFF` (the app's accent) and `background_color #EDEDF0` (the
  light desk surface), plus four icons covering `any` and `maskable` at 192 and
  512. The old `manifest.json` was deleted so there is one source of truth.
- **Icons generated from the app's own artwork.** `.tmp_probe/gen_pwa_icons.py`
  (a throwaway generator, since removed) rasterised `images/app_icon.png`:
  `pwa-192.png`/`pwa-512.png` flattened on white for `any`, and
  `pwa-maskable-192.png`/`pwa-maskable-512.png` with the palette on a 58% white
  card over the accent, which keeps the artwork inside Android's maskable safe
  circle. The stock Flutter `Icon-*.png` files were deleted, and
  `apple-touch-icon.png` (180) and `favicon.png` (32) were regenerated from the
  same artwork. Apple's asset was already declared in `index.html`; it now
  points at a real, correctly sized file.
- **`web/sw.js`** — a deliberately minimal service worker: `install` skips
  waiting, `activate` claims clients, and `fetch` is network-first, passing
  through to the network and only substituting a small offline page for
  navigations. It exists because browsers require a fetch handler before they
  offer to install; it never caches the app shell, so a new deploy (or a later
  offline-caching design) cannot silently serve stale code.
- **`web/index.html`** links `manifest.webmanifest`, keeps the matching
  `theme-color #6A4EFF`, and registers `sw.js` on `load` with a caught failure,
  so a blocked worker can never stop the app booting.

### Verification beyond the unit test

The release build was produced and served locally, then loaded in the browser:

- `build/web` contains `manifest.webmanifest`, `sw.js`, the four generated
  icons and `apple-touch-icon.png`; the stale `manifest.json` and stock icons
  are gone.
- `document.querySelector('link[rel=manifest]')` resolves; the manifest fetches
  **200**, parses with `name: InkLink`, `display: standalone` and four icons,
  and all four icon URLs fetch **200**.
- `navigator.serviceWorker.getRegistration()` reports an **activated** worker
  scoped to the origin, and after a reload the page is **controlled** by it.
- The app still boots: the Flutter view mounts and the signed-out "Welcome
  back" screen renders, with no console errors (only Firebase/Firestore debug
  logs) and every request 200.

No owner decision was needed: the name and colours come from the existing app
(theme accent and desk surface), and the artwork is the app's own icon. The
only genuine branding question left is a designed store-quality icon set, which
this replaces the Flutter logo with a faithful app icon but does not
commission.

## Shared canvas bugs: investigation outcome

This pass was also asked to own the two bugs `WEB_CANVAS.md` lists as open. Both
were investigated; **neither could be reproduced**, so neither was "fixed" —
inventing a change and calling it a fix would have been worse than recording the
evidence. What the investigation did produce is a regression suite around the
exact behaviours the bug reports describe.

### "Redo after undo can fail"

Investigated top-down with a new suite, `test/features/canvas/canvas_redo_after_undo_test.dart`,
which drives the real `CanvasBloc` with an in-memory `CanvasService` (the same
harness pattern as `undo_conflict_flow_test.dart`), so the local CRDT adapter,
the undo manager, the redo conflict gate and the publishing path all run:

| Sequence | Expected | Result |
|---|---|---|
| create shape → undo → redo | shape returns, message "Redone" | passes |
| create two shapes (separated) → undo ×2 → redo ×2 | empty, then 1, then 2 | passes |
| create → undo/redo ×3 cycles | shape returns every cycle | passes |
| create → move → undo → redo | move re-applied | passes |

Adapter-level behaviour was already covered by `test/core/crdt/` (19 tests, all
passing): create/update/delete/batch undo, two-step undo/redo, and the
peer-overwrite ledger cases. Nothing in either layer loses redo.

The documentation's own description of the bug — "redo after undo **re-applies
the snapshot**" (`WEB_CANVAS_PLAN.md`) — points away from the local undo stack:
a snapshot restore arrives as a `__snapshot__` update, and the bloc deliberately
clears local history when one applies (D14), so any redo after a snapshot is
unsupported by design. Reproducing that needs two clients and the sync server,
which is outside a unit harness and was not attempted here. **Status: not
reproduced locally; the failure therefore does not lie in the local undo/redo
path exercised above.** The new suite stays as a regression guard.

### "Text resize leaves the selection frame at the old size"

Investigated at both layers:

- **State layer**: the bloc applies the width, re-measures the height from the
  wrapped text, keeps the element selected and persists the new box. Verified
  with a probe (width 220 → 60, height 76 → 247, selection unchanged); no
  defect found.
- **View layer**: a new widget test,
  `test/features/canvas/view/text_resize_selection_frame_test.dart`, pumps the
  real `CanvasScreen`, creates and selects a text element, finds the real
  resize handle, drags it 120 px and asserts both that the element widened and
  that the handle (bottom-right corner of the frame) moved right with it. This
  **passes** — the frame follows the new box without reselecting.

So the reported symptom does not occur in the widget-level gesture path either.
The remaining difference between that test and the browser is the renderer and
input plumbing (CanvasKit pointer handling), where the report says it was "seen
on the web". Pinning that down needs a browser-driven gesture test — the
Playwright/`integration_test` harness listed as ranked item 3 — rather than
another shared-code change made blind. **Status: un-reproducible in the
available harnesses; kept open with a view-layer regression guard in place.**

No production code changed in this part of the pass: the honest outcome after
reproduction attempts was "already correct in both layers", not a code change.

Responsive hardening for narrow viewports (the other optional item) was not
started in this pass: with PWA green and the full suite passing, a layout change
would have put the verified installable build at risk without a failing test to
drive it. It stays on the open list.

## Tests and checks

New file `test/web/web_sign_up_test.dart` (8 tests):

1. The sign-in form offers account creation, switches modes both ways, and
   hides Google/forgot-password in the sign-up form.
2. Creating an account without a name is refused locally.
3. A short password is refused locally.
4. A new account lands on "Verify your email"; after confirming, the boards
   page loads.
5. An existing email is rejected with the repository's message.
6. A board deep link shows the "board is waiting" note and continues to the
   board after sign-in.
7. Board cards expose `Board <name>. <tags> • Edited …` as their accessible
   name while the menu keeps "Board options".
8. `web/index.html` contains the link-preview metadata.

New file `test/web/web_pwa_test.dart` (4 tests, all failing before the change):

9. `index.html` links `manifest.webmanifest` and registers `sw.js`.
10. The manifest parses and carries `name`, `short_name`, `start_url`, `scope`,
    `display`, `theme_color #6A4EFF`, `background_color #EDEDF0` and a
    description.
11. Every declared icon exists, is a real PNG whose IHDR pixel size matches the
    declared `sizes`, covers both `any` and `maskable`, and both the 192 and 512
    sizes for each purpose.
12. `sw.js` has `install` and `fetch` handlers and does not blindly cache the
    app shell.

Results on this machine (Flutter 3.44.0, Windows, Git Bash):

| Check | Result |
|---|---|
| `flutter analyze` | No issues found (exit 0) |
| `flutter test test/web/web_sign_up_test.dart` | 8 passed |
| `flutter test test/web` | **123 passed** (111 before + 8 sign-up/accessibility + 4 PWA) |
| `flutter test test/features/canvas/canvas_redo_after_undo_test.dart test/features/canvas/view/text_resize_selection_frame_test.dart` | **5 passed** (4 redo scenarios + 1 view-layer text-resize scenario) |
| `flutter test test/core/crdt` | 19 passed (existing undo/redo ledger coverage, re-run during the investigation) |
| `flutter build web --release -t lib/web/main_web.dart` | Built `build/web` (exit 0); output inspected for the manifest, worker and icons |
| Built app loaded from a local static server | Boots to the sign-in screen, manifest + 4 icons 200, service worker **activated** and **controlling**, no console errors |

The shared canvas suites above are unchanged from the previous pass. This pass
added `test/web/web_pwa_test.dart` and the `web/` PWA assets; no Dart source in
`lib/` changed, so the web import guard is untouched and still passes.

Docs updated in `WEB_COMPANION.md`: the sign-in row now says accounts can be
created in the browser, the "not on the web" list no longer claims account
creation is mobile-only, the profile document written by web sign-up is
described, and the link-preview limit is recorded under known limitations.

## How to try it manually

```bash
# Sample data, no Firebase
flutter run -d chrome -t lib/web/preview/main_web_preview.dart --web-port 3000
# open http://localhost:3000/?signedOut  → "Create an account"
# open http://localhost:3000/?signedOut#/board/b5 → "A board is waiting for you."
```

The preview mirrors real behaviour: a new sample account starts unverified,
"I've verified" confirms it and drops you on the boards page.

To check installability by hand:

```bash
flutter build web --release -t lib/web/main_web.dart
python -m http.server 8790 --bind 127.0.0.1 --directory build/web
# open http://127.0.0.1:8790 in Chrome: the install icon appears in the
# address bar; DevTools → Application shows the manifest, icons and the
# activated service worker.
```

## Still open, and what happened to each item

| Ranked item | Why it is still open |
|---|---|
| 1. Hosting, auth domains, sync/R2 CORS | Needs the project owner's Firebase/Cloudflare credentials and a deploy decision; the checklist in `WEB_CANVAS.md` is unchanged. |
| 3. Automated browser regression (Playwright / `integration_test`) | Worth doing next, but it is a new harness with browser-driver dependencies; the 8 new widget tests cover the new logic meanwhile. |
| 4. Board thumbnails on the web | Needs a storage/product decision (R2 vs a Firestore field) and a save-time thumbnail generator. |
| 5. Board settings and member management inside the web canvas | Larger wiring task through the shared canvas route; the companion's workspace member management is the pattern to reuse. |
| 6. Offline / reload-resilient canvas (IndexedDB `CrdtLocalStore`) | Substantial new adapter plus reconnect semantics; should be designed with the sync server, not bolted on. |
| 8. Redo-after-undo and text-resize selection bugs | **Investigated this pass, not reproduced** (evidence above). Redo is intact in the local undo/redo path; the remaining suspect is the server/snapshot restore path, which needs two clients. The text frame follows the resize in a real widget gesture, so the remaining suspect is CanvasKit pointer/repaint behaviour — needs a browser-driven test (item 3). Regression guards added for both. |
| 9–17 minus PWA. Presence/notifications, DMs, observability, bundle splitting, CSP/secret audit, bulk actions | Each needs either a backend/service choice, a measurement run, or is polish behind the items above. |
| 14. Responsive hardening for narrow viewports | Offered for this pass but deliberately not started once PWA was green: a layout change with no failing test to drive it would have risked the verified installable build. |
| 16. PWA installability | **Done this pass** (section 5). A designed store-quality icon set remains an owner/brand decision; the current icons are generated from the app's own artwork. |

No production code outside `lib/web/` changed, and the web import guard
(`test/web/web_companion_imports_test.dart`) still passes, so the web entry
point still never reaches Isar, `path_provider` or Agora.
