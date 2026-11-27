# Dead code removal & duplicated logic — what changed

A complete record of the refactoring pass in this working tree: what was dead,
what was duplicated, what it looks like now, why it is better, and how the
"nothing broke" claim is verified. Every number and symbol below was checked
against the working tree with `git diff --numstat`, `git diff` and `grep`, not
carried over from memory.

Scope: the Flutter app (`lib/`), the Node realtime/history server (`server/`),
and the render/parity test suite (`test/`). Every change here was made with the
same rule: **existing rendered output must stay byte-identical**. A changed
golden digest is treated as a bug in the change, never as a golden to refresh.

---

## 1. At a glance

| Metric | Value |
| --- | --- |
| Tracked files touched | 37 |
| Lines removed (tracked) | 3,183 |
| Lines added (tracked) | 531 |
| Net reduction (tracked) | −2,652 |
| New shared modules | 4 files, 187 lines |
| New parity tests | 6 files, 1,080 lines |
| Duplicate `_parseDate` copies deleted | 6 |
| Duplicate `_toInt` copies deleted | 5 |
| Duplicate clock-format copies deleted | 2 |
| Duplicate palette literals collapsed | 2 literals, 4 swatch loops |
| Per-element paint implementations deleted | 14 methods (8 canvas, 6 exporter) |
| Per-element edit panels deleted | 7 panels + 4 banners / 2,185 lines |
| Test suite | 877 / 877 passing |
| `dart analyze lib test` | No issues found |
| Export raster digest | `bb16e6bffea56427` (unchanged) |
| Interactive golden sha256 | `437c875191a7d707c2bc4c2927d68fef16e02a0a186d8016490f4e92e6368ebc` (unchanged) |

Roughly: **6 lines deleted for every line added**, with the rendering output
provably identical.

> **Update (CI hardening):** the byte-level export digest and the checked-in
> interactive golden in the table above were later retired. Ubuntu CI rendered
> text with different anti-aliasing (771 px, 0.18%) even though both render
> paths still agreed exactly with each other on the same host. The current
> tests assert platform-neutral structure instead: per-element signature
> colours, per-element ablation, run-to-run determinism, and exact cross-path
> RGBA. See `docs/canvas/paint-parity.md` for the current gate.

---

## 2. Verification gate

Every step below was staged, and both render goldens were re-run after each
step rather than once at the end.

```bash
dart analyze lib test                     # No issues found!
flutter test                              # 877 tests, all pass

# the parity gate, when touching shared paint code:
flutter test test/features/canvas/cross_path_equivalence_test.dart
flutter test test/features/canvas/paint_parity_test.dart
flutter test test/features/canvas/view/canvas_painter_golden_test.dart
```

Three independent proofs that the two render paths still agree:

1. **Export digest** — `paint_parity_test.dart`, test *"exported element scene
   is pixel-stable"*, hashes the rasterised export of the shared scene:
   `bb16e6bffea56427`.
2. **Interactive golden** — `canvas_painter_golden_test.dart` compares the
   on-screen painter against `goldens/canvas_painter_interactive.png`
   (sha256 `437c8751…8ebc`, verified on disk).
3. **Exact-RGBA cross-path equivalence** — `cross_path_equivalence_test.dart`
   renders each of the eight scene elements through *both* paths into the same
   world rect at 1:1 and requires **zero** differing pixels, one test per
   element (`stroke`, `shape`, `text`, `connector`, `frame`, `sticky`, `image`,
   `table`).

Plus an **ablation guard**: *"ablating any single element changes the exported
bytes"* removes each element in turn and requires the output to change, so a
paint branch that silently stops drawing fails the build instead of being
absorbed by a golden update. (Verified by temporarily sabotaging a branch: the
digest moved to `804440f1d7a80163` and the test failed as designed.)

> **Later update:** proofs 1 and 2 were replaced by platform-neutral raster
> checks (see the note in §1); proof 3 and the ablation guard remain unchanged.

---

## 3. Canvas element painting — one dispatch instead of two

### Before

Two independent switch statements decided how an element type is drawn:

- `BoardExportServiceImpl._paintElement` (raster/PDF) → six private helpers
  `_paintStroke`, `_paintShape`, `_paintText`, `_paintStickyNote`,
  `_paintImage`, `_paintConnector`, plus direct calls for frame/table.
- `_CanvasPainter.paint` switched on its own `_ElementKind` view models → eight
  methods `_paintStroke`, `_paintShape`, `_paintText`, `_paintImage`,
  `_paintStickyNote`, `_paintFrame`, `_paintTable`, `_paintConnector`, plus
  `_resolveAnchor`.

Adding a ninth element type meant editing two switches, two sets of helpers, and
hoping both were kept in sync. The stroke *fill* pass was written twice
verbatim, and the text plate (rotation → background → glyphs) was written twice.

### Now

One file owns the dispatch:

```
lib/features/canvas/geometry/canvas_element_drawer.dart
```

```dart
void paintSharedElement(
  Canvas canvas,
  CanvasElement element, {
  Map<String, CanvasElement> elementMap = const {},
  ui.Image? decodedImage,
  double? strokeSpacing,
  ImagePlaceholderPainter? imagePlaceholder,
  (Offset, Offset)? resolvedConnectorEnds,
})
```

Both paths feed it:

| Path | Feeds |
| --- | --- |
| Exporter (PNG/PDF raster) | persisted `CanvasElement` straight in (`board_export_service.dart:635`) |
| Interactive painter | its view models through `_CanvasElement.toPaintable(siblings)` (`canvas_painter.dart:491`) |

`toPaintable` is a pure adapter: it turns a live view model into the domain
element the drawer expects, carrying over the canvas's own defaults verbatim
(shape `fillMode`/`endArrowhead` fallbacks, the `sourceElement ?? fromMap`
overlay used during transform previews, `padding: data['padding'] ?? 4`).

The three places the paths legitimately disagree are **explicit parameters**,
not duplicated code:

| Parameter | Export | Canvas |
| --- | --- | --- |
| `strokeSpacing` | omitted → brush preset decides | the element's persisted spacing |
| `imagePlaceholder` | neutral `🖼 Image` plate (`_paintImagePlaceholder`) | `[Image: WxH]` pending-size label (`_paintCanvasImagePlaceholder`) |
| `resolvedConnectorEnds` | omitted → resolves against persisted `elementMap` | resolved against live view models |

Each divergence is documented in `docs/canvas/paint-parity.md` with the reason
and the test that pins it.

The painter's `paint()` loop is now: stroke highlight → `toPaintable` →
`paintSharedElement` → connector highlight. The live stroke preview, the
symmetry-mirrored copies and the shape-creation preview also route through the
drawer (`canvas_painter.dart:1094`, `:1111`, `:1265`).

### Also extracted in the same layer

- `paintStrokeFill` (`canvas_render_utils.dart:424`) — the closed-polygon fill
  under a freehand stroke. This was duplicated verbatim in both painters; now a
  two-point or unfilled stroke cannot diverge between screen and file.
- `paintTextLayoutBox` (`canvas_element_geometry.dart:111`) — rotation about the
  box centre, the rounded background plate, and the glyph paint. The exporter
  and the canvas were two copies of this sequence.

### Deleted as a consequence

| Deleted | Where |
| --- | --- |
| `_paintStroke`, `_paintShape`, `_paintText`, `_paintImage`, `_paintStickyNote`, `_paintFrame`, `_paintTable`, `_paintConnector`, `_resolveAnchor` | `canvas_painter.dart` (canvas-only defaults preserved in the adapter) |
| `_paintStroke`, `_paintShape`, `_paintText`, `_paintStickyNote`, `_paintImage`, `_paintConnector` | `board_export_service.dart` (image placeholder body kept as `_paintImagePlaceholder`) |

`_paintConnectorHighlight` was added to the painter for selection chrome, and
`_paintCanvasImagePlaceholder` was moved to module level so the drawer can call
it without reaching into painter state. The exporter's
`_resolveConnectorEndpoints` wrapper was kept: the SVG serialiser and the bounds
pass still use it.

`lib/domain/services/canvas/canvas_geometry.dart` gained one line — a
re-export of the drawer — so `lib/domain/**` can reach the shared painters
without importing deep into `lib/features/**`.

Sites that were **not** unified here: the exporter's SVG markup switch and its
`computeElementsBounds` ladder. They emit XML and rects rather than `Canvas`
draw calls, so the shared drawer cannot serve them (see §14).

---

## 4. Canvas edit chrome — seven panels collapsed into one bar

### Before

`canvas_screen.dart` carried one bespoke editor per element type, each with its
own sliders, swatches, chips and banners:

Seven panels — `_buildSelectedElementPanel`, `_buildSelectedFramePanel`,
`_buildSelectedShapePanel`, `_buildSelectedTextPanel`,
`_buildSelectedStrokePanel`, `_buildSelectedConnectorPanel`,
`_buildSelectedImagePanel` — plus four banners (`_buildShapeEditBanner`,
`_buildTextEditBanner`, `_buildStrokeEditBanner`,
`_buildStickyNoteEditBanner`), and a pile of state for it:
`_isShapeEditTrayExpanded`, `_isStrokeEditExpanded`, `_pendingTextFontSize`,
`_pendingTextRotation`, `_deferredSetSelectedShapeProperty`,
`_deferredResizeSelectedShape`, `_deferredRotateSelectedShape`,
`_deferredSetSelectedShapeBorderRadius`, `_setSelectedShapeColor`,
`_scheduleShapeEditCommit`, `_dashIndexFor`, `_dashPatternFor`,
`_shapeFillColorRow`, `_shapePanelSlider`, `_labelAlignChip`, `_dashChip`,
`_buildSectionLabel`, `_openImageCrop`.

### Now

One bar, driven by data instead of eight code paths:

```dart
Widget _buildElementEditingBar(CanvasState state, List<_CanvasElement> elements)
```

- A per-`_ElementKind` **action list** (`fill`, `color`, `outline`, `stroke`,
  `flip`, `opacity`, `edit`, `size`, `rotation`, `title`, `radius`, `clip`,
  `tableLayout`, `duplicate`, `delete`) replaces eight widget trees.
- `_activeEditControl` (a `String?`) replaces four booleans and two pending
  numeric fields; opening another control replaces the open one.
- `_elementEditPanel` / `_elementEditControlBody` render the active control;
  shared widgets (`_fillSwatch`, `_elementEditAction`,
  `_elementEditorLabel`) replace the per-panel copies of the same swatch and
  slider code.
- Result: **2,185 lines removed, 6 added** in `canvas_screen.dart`.

Behaviour is preserved: the same controls, the same block events
(`CanvasUpdateSelectedShapeStrokeColor`, `CanvasFlipSelectedShape`,
`CanvasDuplicateElements`, …), the same dialogs for text/sticky/table/frame
title, and frame deletion still goes through its confirmation.

### Also deleted (unused UI)

- `lib/features/canvas/view/widgets/canvas_search_sheet.dart` — 181-line
  `CanvasSearchSheet` + `CanvasSearchEntry` widget set with **no remaining
  references** anywhere in `lib/` or `test/` (verified by grep).

A stale import of `widgets/image_crop_dialog.dart` and of
`models/brush_preset.dart` went with the removed panels; `image_crop_dialog.dart`
itself is still used elsewhere and was not deleted.

---

## 5. Loosely-typed payload parsing — one implementation

Six domain models and five repositories/services each carried a private,
byte-identical copy of the same two coercions.

### Before

`_parseDate` (11 lines) was pasted verbatim into `board.dart`,
`friend_request.dart`, `board_invitation.dart`, `in_app_notification.dart`,
`user_model.dart`, `workspace_board.dart`. `_toInt` (6 lines) was pasted into
`board_repository_impl.dart`, `friends_repository_impl.dart`,
`invitation_repository_impl.dart`, `profile_repository_impl.dart`,
`profile_service.dart`.

### Now

```dart
// lib/core/utils/dynamic_parsing.dart (28 lines)
DateTime parseDateTimeValue(dynamic value)  // missing/odd value → DateTime.now()
int      parseIntValue(dynamic value)       // missing/odd value → 0
```

Call sites swap one identifier (`_parseDate` → `parseDateTimeValue`,
`_toInt` → `parseIntValue`) and nothing else. The fallbacks are identical to
the copies, which matters: `parseDateTimeValue` still accepts `DateTime`,
ISO strings, epoch millis and Firestore `Timestamp` (via `toDate()`), and still
falls back to "now" — moving a value between readers cannot change a result.

Deleted: 6 × `_parseDate`, 5 × `_toInt`, 66 lines in total.

---

## 6. Clock formatting — one implementation

### Before

`chat_bubble.dart` and `canvas/view/chat/board_chat_drawer.dart` each held a
private `_formatTime` producing `HH:mm` — one from a `DateTime`, one from epoch
millis.

### Now

```dart
// lib/core/utils/time_format.dart (13 lines)
String formatClockTime(DateTime time)
String formatClockTimeFromMillis(int millisecondsSinceEpoch)  // delegates
```

Both call sites use it (`chat_bubble.dart:382`,
`board_chat_drawer.dart:287`); both private copies deleted. There is now exactly
one place where a chat timestamp can be formatted differently from the rest.

---

## 7. Editor palette — one list

### Before

The same eight-colour list was written out twice as a constant,
`_CanvasScreenState._editorPalette` and `CanvasSelectionStyleSheet.palette`, and
the swatch rows were then repeated four times in `canvas_screen.dart` (colour,
outline, tint and border rows). Divergence was a matter of time: a colour added
to one editor would silently be missing from the other.

### Now

```dart
// lib/features/canvas/models/canvas_editor_palette.dart (17 lines)
const List<Color> canvasEditorPalette = <Color>[ … ];
```

`CanvasSelectionStyleSheet.palette` is now `= canvasEditorPalette` (its public
name and type are unchanged, so no caller changed), and the four swatch rows in
`canvas_screen.dart` iterate the shared list.

---

## 8. Dead symbols removed (no callers)

Each was verified to have zero references in `lib/` and `test/` before deletion,
and is verified absent now. (`boardInvites` still appears in the codebase only
as part of the unrelated `boardInvitesBloc` identifiers; the removed
`FirestorePaths` constant is gone.)

| Symbol | File | Kind |
| --- | --- | --- |
| `FirestorePaths.boardInvites`, `friendRequests`, `friendsSubcollection`, `notificationsSubcollection`, `boardMembersSubcollection` | `core/constants/firestore_paths.dart` | unused path constants (5) |
| `AppErrorFormatter.cleanTitle` | `core/utils/app_error_formatter.dart` | unused wrapper over `format()` |
| `isValidPassword` | `core/utils/helpers.dart` | unused wrapper over `getPasswordStrengthError` |
| `AiImageService.aspectRatios`, `maxPromptLength` | `domain/services/ai/ai_image_service.dart` | unused constants |
| `measureTextElementBounds` | `features/canvas/bloc/canvas_helpers.dart` | unused (superseded by `textElementRect`) |
| `CanvasCreating`, `CanvasReady`, `CanvasErrorState` | `features/canvas/bloc/canvas_state.dart` | three unused `CanvasState` subclasses |
| `StrokeStabilizer.lastRaw` | `features/canvas/geometry/stroke_input.dart` | unused public getter (the private `_lastRaw` field it read still exists and is still used internally) |
| `FrameElement.titleBarHeight` | `features/canvas/models/canvas_element.dart` | unused constant |
| `CanvasTextLayout.defaultPadding`, `CanvasTextLayout.textAlignName` | `canvas_element_geometry.dart` | unused members |
| `tableCellRect` | `canvas_element_geometry.dart` | unused helper |
| `CanvasSearchSheet`, `CanvasSearchEntry` | `widgets/canvas_search_sheet.dart` | unused file (181 lines) |

Two more silent removals came with the edit-chrome rewrite in §4 (the seven
panels, four banners and their helper/state fields) and with the paint-layer
rewrite in §3 (the fourteen helpers).

---

## 9. Server (`server/`) and small library fixes

### 9.1 Dead code removed

| Symbol | File | Note |
| --- | --- | --- |
| `colorName`, `centerOf`, `sizeOf`, `diffFields` | `history/describe.js` | exported but never imported by `revert.js`, `timeline.js` or `index.js` (which import only `describeChange`, `summarizeOperation`, `elementNoun`); the functions themselves are still used inside `describe.js` |
| `purgeBoardPrefix` (+ `DeleteObjectsCommand` import) | `history/r2.js` | never called; the import existed only for it |
| `BUCKET` | `history/r2.js` | removed from `module.exports` only — still the module's internal bucket name |
| `DEFAULT_PAGE_SIZE` | `history/timeline.js` | removed from `module.exports` only — still used internally as the 100-row default |
| `getConnectedSocketsInRoom` | `index.js` | never called |

### 9.2 Correctness/robustness changes in the same diff (not refactors)

These are behaviour changes, called out separately so they are not mistaken for
cleanup:

- **Payload ceilings** in `isValidUpdate` / `isValidPreview`: an update must now
  carry a non-empty `payloadBase64` under 4 MiB with IDs ≤ 128 chars; a preview
  is limited to 16 keys, string values under 1 MiB and finite numbers. Socket.IO
  caps a frame at 5 MB, so this bounds what can be persisted and fanned out to a
  whole room by a single socket.
- **Resolved undo requests are not re-planned**: a request whose `status` is
  set to anything other than `pending` now returns `request_not_pending`
  instead of being turned into a fresh revert. Legacy requests without the
  field stay allowed.
- **`leave_board` clears `socket.data.currentBoardId`** when it matches the room
  being left, so a later rejoin cannot act on a stale board id.
- Handlers destructure `{ boardId, update } = {}` / `{ boardId, preview } = {}`,
  so an event with no payload reports an error instead of throwing.
- `AuthSessionService` (`lib/domain/services/auth/auth_session_service.dart`)
  no longer logs the user's email address in its "verification dispatched"
  line.

---

## 10. Repository hygiene

| Change | Why |
| --- | --- |
| `.gitignore`: `firestore.rules` is now un-ignored (`!firestore.rules`) | security rules must be reviewable and deployable from the repo; `.env`, service accounts and indexes stay ignored. The rules file is currently staged as a new file (outside this unstaged diff) |
| `.env.example`: `CLODFLARE_R2_PUBLIC_URL` → `CLOUDFLARE_R2_PUBLIC_URL` | the documented variable name was misspelled, so anyone copying the example got a name nothing recognises. No code in this repo reads either spelling, so this is a documentation fix, not a behaviour change |
| `.gitignore`: `.tools/`, `.claude/`, `.cloud-attachments/` ignored | installed third-party tooling, not project source |
| `.gitignore`: `docs/*` with `!docs/canvas/` and `!docs/refactoring/` | local notes/research stay out; the paint-parity catalogue the render tests link to and this report are trackable |

---

## 11. Coverage map — every changed file

Tracked modifications and deletions (37), and what the report says about each:

| File | Section |
| --- | --- |
| `.env.example` | §10 |
| `.gitignore` | §10 |
| `lib/core/constants/firestore_paths.dart` | §8 |
| `lib/core/utils/app_error_formatter.dart` | §8 |
| `lib/core/utils/helpers.dart` | §8 |
| `lib/domain/models/board.dart` | §5 |
| `lib/domain/models/friends/friend_request.dart` | §5 |
| `lib/domain/models/invitation/board_invitation.dart` | §5 |
| `lib/domain/models/notification/in_app_notification.dart` | §5 |
| `lib/domain/models/user_model.dart` | §5 |
| `lib/domain/models/workspace_board.dart` | §5 |
| `lib/domain/repositories/board/board_repository_impl.dart` | §5 |
| `lib/domain/repositories/friends/friends_repository_impl.dart` | §5 |
| `lib/domain/repositories/invitation/invitation_repository_impl.dart` | §5 |
| `lib/domain/repositories/profile/profile_repository_impl.dart` | §5 |
| `lib/domain/services/ai/ai_image_service.dart` | §8 |
| `lib/domain/services/auth/auth_session_service.dart` | §9.2 |
| `lib/domain/services/canvas/board_export_service.dart` | §3 |
| `lib/domain/services/canvas/canvas_geometry.dart` | §3 (drawer re-export) |
| `lib/domain/services/canvas/canvas_render_utils.dart` | §3 (`paintStrokeFill`) |
| `lib/domain/services/profile/profile_service.dart` | §5 |
| `lib/features/canvas/bloc/canvas_helpers.dart` | §8 |
| `lib/features/canvas/bloc/canvas_state.dart` | §8 |
| `lib/features/canvas/geometry/canvas_element_geometry.dart` | §3, §8 |
| `lib/features/canvas/geometry/stroke_input.dart` | §8 |
| `lib/features/canvas/models/canvas_element.dart` | §8 |
| `lib/features/canvas/view/canvas_painter.dart` | §3 |
| `lib/features/canvas/view/canvas_screen.dart` | §4 |
| `lib/features/canvas/view/chat/board_chat_drawer.dart` | §6 |
| `lib/features/canvas/view/widgets/canvas_search_sheet.dart` (deleted) | §4 |
| `lib/features/canvas/view/widgets/canvas_selection_style_sheet.dart` | §7 |
| `lib/features/canvas/view/widgets/revert_review_sheet.dart` | §14 (comment added recording why it keeps its own painters) |
| `lib/features/chat/view/widgets/chat_bubble.dart` | §6 |
| `server/src/history/describe.js` | §9.1 |
| `server/src/history/r2.js` | §9.1 |
| `server/src/history/timeline.js` | §9.1 |
| `server/src/index.js` | §9.1, §9.2 |

New (untracked) files:

| File | Section |
| --- | --- |
| `lib/core/utils/dynamic_parsing.dart` | §5 |
| `lib/core/utils/time_format.dart` | §6 |
| `lib/features/canvas/geometry/canvas_element_drawer.dart` | §3 |
| `lib/features/canvas/models/canvas_editor_palette.dart` | §7 |
| `docs/canvas/paint-parity.md` | §2, §3 (preserved-difference catalogue) |
| `docs/refactoring/dead-code-and-duplication-report.md` | this file |
| `test/features/canvas/paint_parity_test.dart` | §12 |
| `test/features/canvas/cross_path_equivalence_test.dart` | §12 |
| `test/features/canvas/view/canvas_painter_golden_test.dart` | §12 |
| `test/features/canvas/paint_golden_scene.dart` | §12 |
| `test/features/canvas/paint_golden_pixels.dart` | §12 |
| `test/features/canvas/canvas_render_test_harness.dart` | §12 |
| `test/features/canvas/view/goldens/canvas_painter_interactive.png` | §2, §12 |

---

## 12. Tests added (the safety net for all of the above)

| File | Lines | Purpose |
| --- | --- | --- |
| `test/features/canvas/paint_parity_test.dart` | 328 | signature-colour export raster, ablation guard, determinism, `paintStrokeFill` / `paintShapeElement` / `paintTextLayoutBox` call sequences (9 tests) |
| `test/features/canvas/cross_path_equivalence_test.dart` | 263 | 8 exact-RGBA export-vs-canvas tests, one per scene element |
| `test/features/canvas/view/canvas_painter_golden_test.dart` | 168 | interactive painter raster check |
| `test/features/canvas/paint_golden_scene.dart` | 133 | the shared scene every element type appears in |
| `test/features/canvas/paint_golden_pixels.dart` | 122 | pixel comparison helpers |
| `test/features/canvas/canvas_render_test_harness.dart` | 66 | render-to-image harness |

`docs/canvas/paint-parity.md` catalogues every place the two paths
**deliberately** differ, with the reason and the pinning test — so a future
"cleanup" cannot quietly unify something that was separated on purpose.

---

## 13. Benefits

**Correctness**
- An element type can no longer be wired into export and forgotten on screen
  (or vice versa): there is one `switch`, in one file, feeding both.
- Text plate padding had already drifted (hardcoded `4` on canvas vs
  `element.padding` on export — 584 differing pixels, caught by the new
  equivalence test; see `docs/canvas/paint-parity.md` §4). That class of drift
  is now structurally impossible for the shared pieces.
- Chat timestamps, date parsing and numeric parsing each have exactly one
  implementation, so a fix lands everywhere at once.
- Strict parsing/limits on the socket boundary stop one client from making the
  server persist or fan out unbounded payloads.

**Maintainability**
- Adding an element type: one drawer case + one adapter case, instead of two
  switches and up to 14 helpers.
- Adding an editor control: one action entry + one control body, instead of a
  new panel per element type.
- 2,652 fewer lines of production code to read, review and keep in sync.

**Reviewability**
- Rendering changes are now *visible as failures*. Before, a duplicated painter
  drifting from its twin was silent; now the digest or an equivalence test goes
  red.

**Leaner compiled surface**
- Removed constants, unused state classes, unused widget files and unused
  server exports.

---

## 14. What deliberately did **not** change

Called out so nobody "finishes" these by accident:

| Left alone | Why |
| --- | --- |
| Exporter's SVG markup switch (~`board_export_service.dart:1038`) and `computeElementsBounds` ladder | they emit XML / rects, not `Canvas` draws — a shared *painter* cannot serve them |
| `_CanvasPainter._resolveConnectorEnd` | converts view models to anchor geometry for hit-testing with subtly different defaults; not the same job as the drawer's endpoint resolution |
| `revert_review_sheet.dart` local `_paintStroke` / `_paintShape` | schematic thumbnails at card scale: flat inks, no texture/gradients. Delegating would visibly change every preview card. A comment was added above them stating this |
| Stroke spacing (canvas: element value, export: brush preset) | reconciling it would change exported bytes or on-screen texture of existing boards — a rendering decision, not a cleanup |
| Canvas paper pattern anchor, rulers, page bounds, selection highlights, guides | view chrome that must never be baked into a file |

---

## 15. How to re-verify after any future change

```bash
dart analyze lib test
flutter test
```

If you touched shared paint code, also run the three parity tests listed in
§2. **Never** run `flutter test --update-goldens` to silence a parity failure:
a moved digest means one path drifted, and the fix belongs in the code.
