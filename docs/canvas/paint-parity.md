# Canvas paint parity

Two code paths render a board: the export pipeline (`BoardExportServiceImpl`
in `lib/domain/services/canvas/board_export_service.dart`) and the on-screen
painter (`_CanvasPainter` in `lib/features/canvas/view/canvas_painter.dart`).
Both are supposed to draw the same picture, and most of the work is genuinely
shared:

| Shared implementation | File | Used by |
| --- | --- | --- |
| `paintStrokeFill` | `lib/domain/services/canvas/canvas_render_utils.dart` | export stroke fill, canvas stroke fill |
| `paintCanvasStroke` | `lib/domain/services/canvas/canvas_render_utils.dart` | export stroke ink, canvas stroke ink |
| `paintShapeElement` | `lib/features/canvas/geometry/canvas_element_geometry.dart` | export shapes, canvas shapes, shape previews |
| `paintTextLayoutBox` | `canvas_element_geometry.dart` | export text, canvas text |
| `paintStickyNoteElement`, `paintFrameElement`, `paintTableElement`, `paintConnectorElement`, `paintImageElement` | `canvas_element_geometry.dart` | export and canvas, both formats |
| `CanvasTextLayout.forElement` | `canvas_element_geometry.dart` | export text layout, canvas text layout |
| `paintSharedElement` | `lib/features/canvas/geometry/canvas_element_drawer.dart` | the one element dispatch: export feeds persisted elements, the painter feeds its view models through `_CanvasElement.toPaintable` |

This document records the places where the two paths **deliberately differ**,
why the difference exists, and which test pins it. Anything not listed here is
expected to be pixel-identical, and is enforced by the tests in the last
section.

## How parity is proven

- `test/features/canvas/cross_path_equivalence_test.dart` renders every
  element of the shared scene (`paint_golden_scene.dart`) through both paths
  into the same world rectangle at 1:1 and compares the RGBA bytes **exactly**
  (zero differing pixels allowed). Eight tests, named
  `<element id> rasterizes identically through export and canvas`.
- `test/features/canvas/paint_parity_test.dart` pins the export raster
  (digest `bb16e6bffea56427`) and the shared painter call sequences. Its
  `ablating any single element changes the exported bytes` test re-renders the
  scene with each element removed in turn and requires every element to change
  the bytes, so a paint branch that stops drawing fails the build instead of
  being absorbed by a golden refresh.
- `test/features/canvas/view/canvas_painter_golden_test.dart` pins the
  interactive raster
  (`test/features/canvas/view/goldens/canvas_painter_interactive.png`).

A change that alters either golden, or that makes any equivalence test
disagree, is a rendering change and needs to be treated as such — not as a
golden refresh.

## 1. Stroke fill — no preserved difference

Both paths call `paintStrokeFill` before the ink pass, with the same inputs:
export passes `StrokeElement.fillColor`/`opacity`, the canvas passes
`data['fillColor']` (written by `StrokeElement.toMap`) and `element.opacity`. The closed-polygon-only rule (fewer than three points, or no
fill colour, draws nothing) lives in the shared helper, so it cannot diverge.

**Why:** the fill is part of the stroke's appearance, not of a view; both
renders must show it. This used to be duplicated in each painter and was
extracted precisely so it could not drift.

**Pinned by:** `paintStrokeFill` group in `paint_parity_test.dart` (alpha
scaling, two-point path, missing colour) plus the `stroke` case of
`cross_path_equivalence_test.dart`.

## 2. Stroke spacing and texture seed — spacing differs for textured brushes

- **Texture seed:** shared. Both paths pass `StrokeElement.textureSeed` into
  `paintCanvasStroke`, which feeds `DeterministicBrushRandom`. No difference.
- **Spacing:** *does* differ for stamped brushes. The canvas passes
  `strokeSpacing: element.spacing` (persisted; `StrokeElement.spacing`
  defaults to `0.15`). The exporter passes no spacing at all (the drawer's
  `strokeSpacing` stays null), so `paintCanvasStroke` → `resampleStroke` falls
  back to the brush preset's `CanvasBrushStyle.spacing` (pen `0.1`, pencil
  `0.18`, charcoal `0.22`, …). The parameter exists on the shared drawer
  precisely so the divergence is one explicit argument rather than two
  near-copies of the stroke sequence.

**Why it is preserved rather than unified:** the solid pen is a smoothed path
(`_drawSmoothPath`) and never resamples, so the scene's pen stroke is
unaffected. Spacing only matters for wash/grain brushes, and only where the
preset differs from the element default (`pencil` 0.18, `textured` 0.2,
`charcoal` 0.22, `watercolor` 0.25 — `airbrush` is 0.15 and so happens to
match). Making
the exporter honour `element.spacing` would change exported bytes for every
existing board that uses those brushes; making the canvas use the preset
spacing would change the on-screen texture of already-saved boards. Either is
a deliberate rendering decision, not a cleanup, so the divergence stands.

**Pinned by:** nothing yet. The equivalence scene uses only the solid pen,
where spacing is unused — which is exactly why the scene passes while the
divergence exists. To pin it, add a pencil/charcoal stroke with a
non-default `spacing` to `paint_golden_scene.dart`; that test will fail until
the two paths are reconciled on purpose, and it will then lock in whichever
behaviour is chosen.

## 3. Shape geometry — shared renderer, different source of truth

`paintShapeElement` is the only shape renderer in both paths. What differs is
the element handed to it:

- **Export** passes the persisted `ShapeElement` (center/size/width/height and
  every fill/stroke option exactly as stored).
- **Canvas** reconstructs a `ShapeElement` from `element.data` in
  `_paintShape` and overlays the mapped element's live geometry
  (`center`, `size`, `width`, `height`, `rotation`). During a drag, resize or
  rotate the screen rewrites the payload or applies a transform draft, so the
  canvas must draw the in-progress geometry; the exporter is only ever given
  the committed board.

**Why it must differ:** exports render saved state, never a gesture in
progress. The preview geometry is not part of the document.

**Pinned by:** the `shape` case of `cross_path_equivalence_test.dart` proves
committed geometry rasterizes identically through both paths;
`paintShapeElement` in `paint_parity_test.dart` pins the shared call sequence
(save → translate to centre → stroked path → restore). The rebuild-from-data
in `_paintShape` also applies preview-era defaults (for example `endArrowhead`
falling back to "arrow shapes have heads", `fillMode` falling back to
`solid`/`none`); that is why it was not replaced with
`CanvasElement.fromMap`, which would change output for gradient/dash shapes
outside the golden scene.

## 4. Text padding — formerly 4 vs element padding; now unified

The interactive painter used to hardcode `backgroundPadding: 4` while the
exporter used `TextElement.padding` (default `4`, but a user-set inset such as
`5` is persisted). The cross-path test caught it as 584 differing pixels
around the text plate.

**Current behaviour:** both paths pass `element.padding` to
`paintTextLayoutBox`. The canvas reads it from the payload with `4` as the
fallback for payloads that omit the key — `4` is `TextElement`'s own default,
so a board without the field renders exactly as before.

**Why it must not differ:** the plate is part of the text element, and the
canvas is the WYSIWYG surface for what gets exported. This entry is kept in
the catalogue as a resolved difference so it is not "re-discovered" as an
intentional divergence.

**Pinned by:** the `text` case of `cross_path_equivalence_test.dart` (exact
bytes, including the rotated plate) and the `paintTextLayoutBox` group in
`paint_parity_test.dart`.

## 5. Schematic preview renderer (`revert_review_sheet.dart`)

The revert-review sheet draws its own thumbnails through local `_paintShape` /
`_paintStroke` helpers instead of the shared painters. The comment above them
states the intent: flat inks, no brush texture, no gradients or dash fills,
and simplified geometry keyed to `_boundsFor` for a card-sized schematic.

**Why it must differ:** it is a diagram of the board, not a render of it.
Delegating to the shared painters would visibly change every preview card
(texture, blur and gradients at 40 px are noise, not information).

**Pinned by:** `test/features/canvas/view/widgets/revert_review_sheet_test.dart`
(`shows a visual preview and swaps it with the decision`).

## 6. Background handling — paper colour shared, view aids are canvas-only

| Aspect | Export | Canvas |
| --- | --- | --- |
| Paper colour | `settings.backgroundColor` over `exportBounds` | `settings.backgroundColor` over the widget |
| Pattern | world-anchored, drawn only when `includePattern` and the pattern is not `none` | screen-anchored (`viewportOffset % spacing`) and scaled by `viewportScale`; drawn whenever the pattern is not `none` |
| Transparent export | first pixel keeps alpha 0 when `transparentBackground: true` | not applicable — the canvas is always on paper |
| Page bounds | not drawn | optional white/bordered page rectangle when `pageBoundsEnabled` |
| Rulers | not drawn | drawn in screen space when `rulersEnabled` |
| Guides / symmetry axes / eraser previews / selection highlights | not drawn | drawn as view chrome |

**Why it must differ:** the paper colour is document content and must match,
which is why the equivalence scene (both defaults: white paper, pattern `none`,
page bounds off) proves the background pixels are identical. The pattern
anchor, page rectangle, rulers and overlays are navigation aids tied to the
viewport and must never be baked into a file. The pattern is also world-anchored
in exports so a printed board is independent of how the author had panned.

**Pinned by:** `cross_path_equivalence_test.dart` (identical paper at the
defaults, for every element), `paint_parity_test.dart` (export digest rendered
with `includePattern: false`), and
`test/domain/services/canvas/canvas_export_options_render_test.dart`
(transparent and opaque PNG/SVG backgrounds). The canvas-side chrome is
covered by `canvas_painter_golden_test.dart`, whose scene has no guides,
symmetry or selection.

## 7. Image bleed — a resolved non-difference

An earlier comment claimed the interactive painter drew a 60 px image at
~66 px. That was the canvas auto-fit zoom: the interactive golden captures at
the screen's fit scale (~1.13×), so the image spans ~68 px **in that capture**.
At 1:1 both paths call the same `paintImageElement` with the same rect.

**Current behaviour:** no bleed difference. The golden test's pixel assertion
keeps a tolerance that only absorbs the capture zoom, and the `image` case of
`cross_path_equivalence_test.dart` proves 1:1 equality.

## Tests that must stay green

```bash
flutter test test/features/canvas/cross_path_equivalence_test.dart
flutter test test/features/canvas/paint_parity_test.dart
flutter test test/features/canvas/view/canvas_painter_golden_test.dart
flutter test test/features/canvas/view/widgets/revert_review_sheet_test.dart
flutter test test/domain/services/canvas/canvas_export_options_render_test.dart
```

When changing shared paint code, run the first three: they are the parity
gate. Do not regenerate a golden to make a parity failure disappear; a failed
equivalence test means one path drifted from the other.
