# InkLink UI Redesign — "Desk" direction

You are restyling the InkLink Flutter app. **This is a visual-only redesign.** The app must behave exactly as it does today.

The idea: InkLink is a whiteboard, so the whole app should feel like a desk. Screens sit on a dot-grid surface. Boards are paper sheets taped down. Invites and requests are sticky notes. All controls are frosted glass floating above the surface. The chrome stays neutral, with one violet accent, so the colorful part of the app is always the users' own drawings.

---

## Reference mockups

Every screen has an approved mockup on the "InkLink Redesign — Desk" design canvas, which I'll share with you as screenshots. Match them as closely as Flutter allows. The rows are:

- **Sign in & Home:** Login, Register, Home, Home (dark)
- **Boards & Canvas:** Create Board, Board Settings, and the canvas with each tray open (Brush & Color, Shapes with a selected element, Tools + Media, Members)
- **Workspaces:** list, Create, Detail, Settings
- **Friends & Profile:** Friends, Friend Requests, Blocked (empty state), Profile (self, with the menu open), Profile (other user)
- **Notifications & Settings:** Notifications, Board Invites, Settings

The names, emails, boards and counts in the mockups are sample data. Always render the app's real data.

If a mockup and this document disagree, this document wins on **behavior** (no logic, copy or feature changes) and the mockup wins on **look**.

Some mockup details only appear where the screen already supports them:
- **Tray close buttons:** the mockups show a title and a close "×" on the Shapes, Media and Members trays. Add the title, but add the "×" only if the tray already has a close action.
- **Join-code copy button:** add it only where a copy action already exists.

---

## 0. Hard rules (read first, never break)

**Do not change any of these:**
- State management (providers, blocs, controllers, notifiers), services, repositories, models, Firebase/API calls, local DB.
- Routes, navigation flow, deep links, or the order of screens.
- Function signatures, public class names, constructor parameters, widget `Key`s.
- Any user-facing text. Copy stays character-for-character identical: titles, labels, hints, errors, snackbars, dialogs.
- Features. Add none and remove none. "Coming soon" items stay "coming soon".
- Callbacks. Every `onTap`, `onChanged` and `onPressed` must still call the same code with the same arguments.

**You may change:**
- `ThemeData`, colors, typography, spacing, radii, shadows, icons, and decoration.
- Widget composition, but only for presentation. For example, you can wrap a `ListTile` in a new styled container. If you have to restructure a widget tree, move the existing callbacks and controllers across untouched.
- New files, as long as they are presentation-only: theme files and reusable styled widgets under `lib/ui/`.

**Process rules:**
- Work on a new branch: `git checkout -b redesign/desk`.
- Do one phase at a time, in the order below. After each phase:
  1. Run `flutter analyze` and get it to zero new issues.
  2. Run `flutter test` if tests exist.
  3. Make sure the app builds.
  4. Commit as `redesign: <phase name>`.
- If a change would require touching logic, **stop and ask me** instead of doing it.
- Light **and** dark mode must both look finished for every screen you touch.

---

## Phase 0 — Audit (no edits)

Before changing anything, report back:
1. Where the theme is defined, and how light/dark switching works.
2. Every file with hardcoded colors: grep for `Color(0x`, `Colors.`, `LinearGradient`, `#6A11CB`, `#2575FC`, `#FF5F6D`, `#FFC371`, `#11998E`, `#38EF7D`.
3. Every `Icons.` usage, with a count per file.
4. The bottom nav implementation, and the canvas tray / edge-trigger widgets.
5. The current font setup and `pubspec.yaml` dependencies.

Wait for my "go" before Phase 1.

---

## Phase 1 — Design tokens & theme

### Packages
- `google_fonts`, for **Bricolage Grotesque** (display) and **Geist** (UI/body). If the installed `google_fonts` version lacks either family, download them from fonts.google.com, bundle them under `assets/fonts/`, and register them in `pubspec.yaml`.
- `lucide_icons_flutter`, as the single icon set for the whole app. If it's unavailable, use `lucide_icons`, but pick one and use only that.

### Files to create
- `lib/ui/theme/ink_colors.dart`
- `lib/ui/theme/ink_type.dart`
- `lib/ui/theme/ink_tokens.dart` (spacing, radii, shadows, blur)
- `lib/ui/theme/ink_theme.dart`

`ink_theme.dart` builds the light and dark `ThemeData` and exposes tokens via `ThemeExtension<InkTokens>`. Read them anywhere with `context.ink`.

Wire the new themes into the existing `MaterialApp` `theme` and `darkTheme`. Keep the existing theme-mode switching logic exactly as it is.

### Colors

| Token | Light | Dark | Used for |
|---|---|---|---|
| `surfaceDesk` | `#EDEDF0` | `#121418` | Scaffold background (the "desk") |
| `deskDot` | `#CFCFD6` | `#2A2D35` | Dot-grid dots |
| `paper` | `#FFFFFF` | `#1B1E24` | Cards, sheets, board "paper" |
| `glass` | `#FFFFFF` @ 72% | `#1F2229` @ 78% | Floating bars, trays, nav |
| `glassStroke` | `#0B0B0F` @ 6% | `#FFFFFF` @ 8% | 1px borders on glass and paper |
| `ink` | `#0B0B0F` | `#F2F2F5` | Primary text and icons |
| `inkSecondary` | `#5A5A64` | `#A6A9B4` | Secondary text |
| `inkMuted` | `#75757F` | `#8C909B` | Metadata ("Edited 2d ago") |
| `field` | `#F0F0F3` | `#22252D` | Input fills, secondary buttons |
| `accent` | `#6A4EFF` | `#6A4EFF` | Primary actions, selection, active nav, focus |
| `accentText` | `#4B32D9` | `#A996FF` | Accent-colored text and links |
| `accentSoft` | `#E7E3FF` | `#2A2452` | Selected backgrounds, avatar fallback |
| `success` | `#16A34A` | `#22C55E` | Online, accepted |
| `pending` | `#D97706` | `#F59E0B` | Pending invites/requests |
| `danger` | `#DC2626` | `#F87171` | Delete, remove, block, logout |

**Sticky-note palette.** These colors are for content-like surfaces only, never for buttons:
- Butter `#FDE68A`
- Rose `#FBCFE8`
- Mint `#BBF7D0`
- Sky `#BFDBFE`
- Lilac `#DDD6FE`
- Peach `#FED7AA`

On a sticky, text is dark ink (`#422006` on butter, `#0B0B0F` on the rest) in both themes.

**Gradient.** There is exactly one: `accentGradient` = `#6A4EFF → #9579FF` at 135°. It is used **only** on:
- the Login button
- the Sign Up button
- the "New Board" button

Delete the three old gradients everywhere. Avatar fallbacks become `accentSoft` with `accentText` initials, or a sticky pastel chosen deterministically from a hash of the user's ID.

**Color rules:**
- Brand violet is never used for status.
- Status colors are never used for brand.
- No color carries meaning alone. Every status also gets a label or an icon.

### Typography

| Style | Font | Size / line height | Weight | Tracking |
|---|---|---|---|---|
| `display` | Bricolage Grotesque | 36 / 0.98 | 800 | −1.6 |
| `headline` | Bricolage Grotesque | 28 / 1.05 | 800 | −1.0 |
| `title` | Bricolage Grotesque | 20 / 1.1 | 700 | −0.5 |
| `cardTitle` | Bricolage Grotesque | 15 / 1.2 | 700 | −0.3 |
| `body` | Geist | 15 / 1.45 | 400 | 0 |
| `bodyStrong` | Geist | 15 / 1.45 | 600 | 0 |
| `label` | Geist | 13 / 1.3 | 600 | 0 |
| `caption` | Geist | 11.5 / 1.3 | 500 | 0 |

Bricolage Grotesque is for headlines, screen titles, the "InkLink" wordmark and board/workspace names. Everything else uses Geist. Map these styles onto `TextTheme` so existing `Theme.of(context).textTheme.*` calls pick them up automatically.

### Spacing, radii, shadows
- **Spacing:** 4-pt scale (4, 8, 12, 16, 20, 24, 32). The screen gutter is 20.
- **Radii:**
  - chip 8
  - segmented tab 10
  - input and button 14
  - command bar and glass bars 22
  - bottom sheet 28
  - paper board card **6** (deliberately small, it's paper)
  - sticky note 3 with a 22 bottom-left corner
- **Paper shadow:** three layers, at 6% black each:
  - `0 1 1`
  - `0 6 12`
  - `0 18 28`
- **Glass:**
  - `BackdropFilter` with `ImageFilter.blur(sigmaX: 20, sigmaY: 20)`
  - 1px `glassStroke` border
  - shadow `0 8 24` at 8% black (light) or 35% (dark)
- **Accent glow** (command bar only): 1.5px `accent` border at 35%, plus a blurred `accent` shadow at 22%, radius 32.

---

## Phase 2 — Reusable components (`lib/ui/widgets/`)

Build these once and reuse them everywhere. They must be stateless or presentation-only, take callbacks as parameters, and support both themes.

- **`DeskBackground`** — a `CustomPainter` dot grid with 20px spacing and 1.3px dots in `deskDot`, over `surfaceDesk`. It's used behind:
  - Login and Register
  - Home
  - Workspaces and Workspace Detail
  - Friends
  - Profile header
- **`GlassPanel`** — a `ClipRRect`, `BackdropFilter` and container with the glass tokens. It takes `radius` and `padding`.
- **`PaperCard`** — a white or `paper` sheet:
  - radius 6 and the paper shadow
  - an optional **tape strip**: 46×16, white at 55% (dark: white at 12%), rotated ±4°, centered on the top edge
  - an optional **tilt**, between −2.5° and +2.5°, derived deterministically from the item's ID so it never changes between rebuilds
  - Tilt is applied with `Transform.rotate` and must not break hit-testing or layout bounds.
  - Used for form sections, list rows and similar grouped content. **Not** used for board cards — see `BoardCardFrame` below.
- **`StickyNote`** — a sticky-palette fill with the sticky radius, a tape strip, a soft warm shadow and a slight tilt. It takes `color`, `child` and `onTap`.
- **`BoardCardFrame`** — "frame with glass label": the board-card chrome used on Home (My Boards / Joined Boards) and in Workspace Detail. No tilt, no tape, no solid pastel/icon fill.
  - Card: 196px tall, radius 24, `clipBehavior: antiAlias`. Border 1px at 6% black. Shadow `0 12 28` at 8% black.
  - The full card background is a dedicated dot-grid (not the desk grid): light `#FFFFFF` with `#DCDCE2` dots at 10px spacing, 1px dots; dark `#1B1E24` with `#2A2D35` dots.
  - **Preview**: the board's existing preview image fills the top ~132px (`BoxFit.cover`) when one exists.
  - **Empty board** (no preview / blank board): only the dot grid, plus a faint dashed squiggle centered in the top area — 80×44, 2px stroke, 4-on/5-off dash, color light `#C4C4CC` / dark `#4B4F59`. No icon, no color fill, no extra text.
  - **Glass label**: floats inset 6px from left/right/bottom, height 56, radius 18. `BackdropFilter` blur 16 (note: a different sigma from `GlassPanel`'s 20). Fill/border reuse the `glass`/`glassStroke` tokens; shadow is `0 4 14` at 8% black in both themes.
    - Contents: title (`cardTitle`, one line, ellipsis), caption below ("Edited Xd ago", Geist 11, `inkSecondary`), and the existing owner menu as a 34×34 vertical-ellipsis (Lucide `ellipsis-vertical`) icon button with tooltip "Board options" — omitted entirely (no reserved space) when the caller has no menu for that card.
  - Grid: 2 columns, 12px gap both axes, `mainAxisExtent: 196` (not `childAspectRatio`, so the 196px height is exact regardless of screen width).
  - Takes `previewPath`, `title`, `caption`, `onTap` and an optional `menuButton` — the caller supplies its own data/callbacks/menu items; the widget is visual-only.
- **`CommandBar`** — a glass bar with the accent glow, a sparkles icon and a text field. It has trailing action slots.
- **`InkButton`** — four variants, all 48 high with radius 14 and `label` text:
  - `primary`: solid `accent`
  - `hero`: `accentGradient` with an inner top highlight
  - `secondary`: `field` background
  - `danger`: `danger` text on a transparent background, solid `danger` for confirmations
- **`InkTextField`** — `field` fill, radius 14, 52 high, and an optional leading Lucide icon. On focus it gets a 1.5px `accent` border and a 4px `accent` ring at 12%. Errors use the `danger` border with the existing error text below.
- **`InkSegmented`** — a glass track with 4px padding. The selected segment is solid `ink` with inverse text.
- **`InkChip`** — radius 8, `field` background. Selected chips use `accentSoft` with `accentText`.
- **`InkAvatar`** — a circle with a 2px surface gap and a 1.5px `accent` ring when `ring: true`. It has the fallback described in Phase 1 and an optional presence dot (`success` online, `inkMuted` offline).
- **`StatusChip`** — pending, accepted, declined or blocked. It has a dot plus text in the semantic color on that color at 12%.
- **`EmptyState`** — a `StickyNote` holding a Lucide icon and the screen's **existing** empty-state copy.
- **`GlassNavBar`** — a floating bottom nav: inset 12, bottom 20, height 64, radius 22, glass.
  - The active item is the filled icon plus label in `ink`.
  - Inactive items are outline icons plus labels in `inkMuted`.
  - It takes the **same** `currentIndex` and `onTap` the existing nav uses. Replace only the visual layer.
- **`CollaboratorCursor`** — a decorative arrow cursor plus a name pill, used on the Login hero.

### Icon mapping
Replace every `Icons.*` with Lucide at a 1.75 stroke, 20px default size. For example:
- home → `house`
- people → `users`
- workspaces → `layout-grid`
- settings → `sliders-horizontal`
- notifications → `bell`
- dark mode → `moon` / `sun`
- add → `plus`
- join/login → `log-in`
- more → `ellipsis`
- delete → `trash-2`
- undo / redo → `undo-2` / `redo-2`
- shapes → `shapes`
- image → `image`
- brush → `pen-line`
- eraser → `eraser`
- copy → `copy`
- search → `search`
- mail → `mail`
- chat → `message-circle`
- call → `phone`
- block → `ban`
- AI → `sparkles`

---

## Phase 3 — Auth (Login, Register)

**Layout.** The form lives on a white `paper` bottom sheet with a 30px top radius:
- on Login the sheet starts about 39% down the screen
- on Register it starts about 25% down

The app logo tile overlaps the top edge of the sheet.

**Background.** The `DeskBackground` covers the full screen. The area above the sheet is a decorative "live board" hero:
- a few hand-drawn strokes and shapes in sticky and accent colors, drawn with `CustomPaint`
- two `CollaboratorCursor`s labeled with generic first names

The hero is static and decorative, and is excluded from semantics.

**App logo.** A 68px paper tile with a 48px accent-gradient mark inside, overlapping the hero edge.

**Text.** `display` headline ("Welcome Back!" / "Create Account") and `body` subtext in `inkSecondary`. Copy is unchanged.

**Fields.** Use `InkTextField` with Lucide leading icons (mail, lock, user). Keep the existing controllers, validators and obscure toggles.

**Login screen:**
- "Forgot Password?" is an `accentText` link, right-aligned.
- Login is an `InkButton.hero`.
- The "OR" divider is hairlines with `caption` text.
- "Continue with Google" is an `InkButton.secondary`.
- The footer link uses `accentText`.

**Register screen:**
- Sign Up is an `InkButton.hero`.
- The terms line is in `caption`.

**Loading and errors.** The loading overlay becomes a `GlassPanel` with a spinner in `accent`. Snackbars are floating, radius 14, `ink` background with inverse text, and use the danger icon for errors.

---

## Phase 4 — App shell & Home

**Bottom nav.** Swap the visuals for `GlassNavBar`. Content scrolls underneath it, with bottom padding of 100.

**Home, top to bottom, all on `DeskBackground`:**

1. **Header** — a `GlassPanel` bar, radius 20, 54 high, inset 12.
   - Left: logo mark plus the "InkLink" wordmark in Bricolage Grotesque 18/800.
   - Right: the dark/light toggle, the bell with an `accent` unread dot (keep the existing count logic) and an `InkAvatar` with a ring.
2. **Greeting** — "Ready to bring your ideas to life?" in `display`, constrained to about 220px wide so it breaks into 3–4 tight lines.
3. **Pending board invites** — a `StickyNote` (butter) placed to the **right of the greeting**, tilted +5°. It shows the existing banner text and a small "Review" affordance, and its tap behavior is unchanged. When there are no invites it isn't rendered, exactly as today.
4. **Tabs** — "My Boards" / "Joined Boards" as `InkSegmented`. Keep the existing `TabController` or index logic.
5. **Board grid** — two columns of `BoardCardFrame`s (see the component section above): flat, no tilt, no tape, 12px gap both axes, 196px fixed card height. Each card contains:
   - the existing thumbnail preview filling the top ~132px, over the card's own dot-grid background; an empty/blank board shows only the dot grid plus the faint dashed squiggle (no icon, no color fill)
   - a floating glass label (inset 6px, height 56, radius 18) holding the title in `cardTitle`, "Edited Xd ago" below it, and the owner menu as a 34×34 vertical-ellipsis icon button with the same menu items
6. **Command bar** — a `CommandBar` floating above the nav (bottom 98, inset 12). It contains:
   - the existing AI search field, with hint "Ask AI to generate a template..."
   - a **Join Board** square icon button (`field` background, `log-in` icon, with tooltip and semantics label "Join Board") that opens the existing Join Board dialog
   - a **New Board** square button with `accentGradient` and a `plus` icon (tooltip and semantics label "New Board") that opens Create Board
   - These two replace the old blue and orange quick-action buttons visually; they must call the same handlers.

**Join Board dialog.** A `GlassPanel` dialog, radius 28, with an `InkTextField` and the existing copy.

**Empty board list.** An `EmptyState` sticky note using the existing text.

---

## Phase 5 — Create Board & Board Settings

**Layout.** Both screens use a `paper` background with sections as grouped `PaperCard`s, without tilt or tape on forms. Section titles are in `title`.

**Create Board:**
- Board name uses `InkTextField`.
- The Private/Public visibility control is `InkSegmented`.
- Dropdowns are styled like `InkTextField`, with a `chevron-down` icon.
- Tags are `InkChip`s showing "#tag". Keep the 5-tag limit logic.
- "Configure Invite Settings" opens a bottom sheet: a `GlassPanel` with radius 28 and a drag handle.
- Friend picker filter chips use `InkChip`.
- "Create Board" is an `InkButton.primary`, full width.

**Board Settings:**
- The Join Code row is a mono-free `bodyStrong` code with a copy icon button.
- Member groups (Owner / Editors / Viewers) have small `label` headers. Rows use `InkAvatar` with a role `InkChip` and the existing menu.
- Email invite chips: valid chips use `accentSoft`, invalid chips use `danger` at 12% with danger text.
- **Danger Zone** is a separate card with a `danger` 1px border at 30%. "Delete Board" is an `InkButton.danger`, and the existing confirm dialog is restyled.

---

## Phase 6 — Canvas editor

**Do not touch** the drawing surface logic, gestures, pan/zoom, the element model or the tray open/close state. Only restyle.

**Canvas surface.** Light mode uses `surfaceDesk` with the dot grid. Dark mode uses `#121418` with dots at 8% white. If the canvas already paints its own background, change only its colors.

**App bar.** Remove the opaque bar. It becomes two floating `GlassPanel` pills at the top:
- **Left pill:** back (`chevron-left`, calls the existing exit), then the board title in `title` with a `chevron-down`. Tapping the title still opens Board Settings.
- **Right pill:** an overlapping `InkAvatar` stack of members currently on the board (use data already available; if none is exposed, omit the stack rather than adding logic), "Reset View" as a `scan` icon with the same handler, and the overflow menu (`ellipsis`) with the same three items.

**Edge triggers.** Keep their positions and behavior. Restyle each as a small glass tab: 36×56, radius 14 on the inner side, with a Lucide icon.

**Trays.** Every tray (Tools, Brush & Color, Shapes, Media, Members) becomes a floating `GlassPanel`:
- radius 22
- inset 12 from the screen edges, instead of edge-flush
- the same slide-in animation and direction as today

**Brush & Color tray:**
- The size-preview swatch is a 52px `field` tile with a dot in the current color.
- Sliders are thin: a 4px track in `accent` and a 16px white thumb with a shadow.
- Brush types (Solid / Textured / Watercolor / Eraser) use `InkSegmented`.
- The eraser-target and smooth-doodles toggles become `Switch`es themed with `accent`.
- The palette shows all 17 existing colors as circles. The selected color gets a 2px gap and a 2px `ink` ring.
- HEX and RGB inputs use small `InkTextField`s.

**Shapes tray.** A 4-column grid of 56px `field` tiles with Lucide or custom-painted shape outlines. The selected tile uses `accentSoft` with an `accent` icon.

**Media tray:**
- The AI prompt field is an `InkTextField` with a `sparkles` icon.
- "Generate Image (Soon)" is a disabled `InkButton.secondary`.
- Recent Uploads is a row of radius-10 thumbnails.
- "Upload Image" and "Add Prompt As Text Note" are `InkButton.secondary`.

**Members tray.** The Call and Chat icons are disabled ghost buttons, with the existing "coming soon" behavior. Add search via `InkTextField`. Groups have `label` headers.

**Selected-element mini-toolbar.** A dark glass pill (`#1F2229` at 85%, even in light mode, for contrast against the canvas) with 38px icon buttons:
- color dot
- fill toggle
- corner radius
- rotate
- resize
- then a divider, then delete in `danger`

Selection handles are 10px white squares with a 1.5px `accent` border, and the selection outline is 1.5px `accent`.

**Image editor.** Use glass bars, the thin slider style, and "Remove Background" as an `InkButton.secondary`. Save is an `InkButton.primary`.

---

## Phase 7 — Workspaces

**Workspaces list:**
- `DeskBackground`, with the title "Workspaces" in `headline`. The invites mail icon gets a `pending`-colored count badge.
- Each workspace is a **stack of paper**: a `PaperCard` with one or two offset sheets peeking behind it (2–4px offset, slight rotation). It shows up to 3 preview board thumbnails, the name in `cardTitle`, and the existing owner/member menu.
- The empty state is an `EmptyState` sticky note with the existing copy. "Create Workspace" is an `InkButton.primary`.

**Create Workspace.** Form cards like Create Board. The board checklist uses `accent` checkboxes on `paper` rows.

**Workspace Detail.** The title is tappable as before. The board grid uses the same `BoardCardFrame`s as Home (flat, no tilt — see the component section). The FAB becomes a 56px `accentGradient` rounded-square (radius 18) with a `plus` icon, and opens the same sheet, restyled as a glass bottom sheet.

**Workspace Settings.** Same pattern as Board Settings, with role `InkChip`s, a `StatusChip` for member status, and a Danger Zone card.

---

## Phase 8 — Friends, Requests, Blocked, Profile

**Friends:**
- `DeskBackground`, with the title in `headline` and an add-friend icon (`user-plus`).
- Search uses `InkTextField`.
- The offline banner is a `GlassPanel` strip with a `wifi-off` icon in `inkSecondary`.
- The incoming-friend-request banner is a `StickyNote` (rose) with the existing text and tap.
- Collaborators appear as rows on a single `paper` card with hairline dividers. Each row has an `InkAvatar` with a presence dot, the name in `bodyStrong`, and a chat icon (`message-circle`).
- The "Add Collaborator" sheet is a glass bottom sheet. In the result card, the Add / Message / Pending button uses `InkButton` variants and `StatusChip` for pending.

**Friend Requests.** Tabs use `InkSegmented`. Cards are `paper` rows: Accept is `InkButton.primary` (small, 36 high), Decline is `secondary`, and Cancel is `secondary`. Empty states are `EmptyState`.

**Blocked Users.** `paper` rows with an Unblock `secondary` button, and an `EmptyState`.

**Profile:**
- The header is a `DeskBackground` band, 180 high, with a 96px `InkAvatar` with a ring overlapping its bottom edge.
- The name is in `headline` and the email in `inkSecondary`.
- **Self view:**
  - the join date in `caption`
  - the bio in a `paper` card (editable as today)
  - the overflow menu with the same items
- **Other-user view:**
  - Stats (Boards, Friends, status) sit as three small `PaperCard`s in a row, with no tilt.
  - The number is in `title` and the label in `caption`. Online status uses a `success` dot.
  - The blocked banner is a `danger`-tinted strip.
  - The primary action is a full-width `InkButton`:
    - Collaborate → `primary`
    - Message → `secondary`
    - Accept + Decline → `primary` + `secondary` side by side
    - Request pending → `secondary` with a `StatusChip`
    - Blocked → disabled

---

## Phase 9 — Notifications, Invites, Settings

**Notifications.** The "Mark all read" action is an `accentText` text button. Cards are `paper` rows containing:
- the sender `InkAvatar`
- the name in `bodyStrong`
- the time in `caption`
- the title and body
- a `StatusChip`
- inline Accept/Decline as small `InkButton`s

Unread rows get a 6px `accent` dot on the left. The empty state is an `EmptyState`.

**Board Invites.** Each invite is a `StickyNote` (butter, alternating tilt) showing the sender, the board title in `cardTitle`, and the expiration in `caption`. Decline is `secondary` and Accept is `primary`. The empty state is an `EmptyState`.

**Settings.** Every row gets a leading 34px `field` icon tile, radius 10, with a Lucide icon. The Logout tile uses `danger` at 8%. The screen is an iOS-style grouped list on `surfaceDesk`:
- The profile card is a `PaperCard` with an `InkAvatar`, name and email.
- Groups are titled "Appearance", "Canvas", "Storage" and "Account" (existing labels) as `label` headers in `inkMuted`.
- Rows sit on `paper` cards, radius 16, with hairline dividers. Switches are themed with `accent`, and the dropdown is styled like `InkTextField`.
- "Clear Cache" is an `InkButton.secondary`.
- "Logout" is a full-width row with `danger` text and a `log-out` icon. The existing confirmation dialog is restyled.

---

## Phase 10 — Sweep & verification

1. Grep again for `Color(0x`, `Colors.` (except `Colors.transparent`), `LinearGradient`, `Icons.` and the old gradient hex codes. There should be none left outside `lib/ui/theme/`.
2. Grep for any text literal you changed. There should be zero copy diffs:

   ```
   git diff main -- lib | grep '^[-+].*["'\'']'
   ```

   Review every hit.
3. Toggle dark mode on every screen and fix anything unthemed.
4. Check accessibility:
   - text contrast is at least 4.5:1 (3:1 for 24px and larger)
   - tap targets are at least 44×44
   - every icon-only button has a `tooltip` or `Semantics` label
   - tilted cards remain readable
5. Run `flutter analyze` and `flutter test`, and build for Android.
6. Give me a summary: files changed per phase, any place you couldn't restyle without touching logic, and screenshots if you can generate them.
