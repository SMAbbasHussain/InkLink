# Canvas roadmap — what an artist needs next

An artist's-eye audit of the canvas, ordered by how much each missing capability
blocks real art-making. Written after reading the canvas source (models,
geometry, bloc events, trays, export), not from user testing.

Each item states **what exists today** (with the file that proves it), **what is
missing**, **why it matters**, and a rough **scope** so it can be sequenced.

Ordering rule: things that change *what an artist can physically draw* come
before things that make drawing *more convenient*.

---

## What already works (do not rebuild)

| Capability | Where |
| --- | --- |
| 8 brush presets with pressure/tilt, jitter, spacing, taper | `lib/features/canvas/models/brush_preset.dart` |
| Six layer blend modes, opacity, lock, hide, drag reorder | `LayerElement` in `canvas_element.dart`, `view/trays/layers_tray.dart` |
| Guides, snapping, symmetry (vertical/horizontal/radial), perspective vanishing points | `lib/domain/models/canvas/canvas_board_settings.dart` |
| Eyedropper that samples the topmost visible element | `lib/features/canvas/geometry/canvas_color_sampling.dart` |
| Marquee + freehand lasso element selection | `CanvasSelectInLasso`, `models/canvas_selection_mode.dart` |
| Free-aspect scale, rotate, flip, duplicate, align/distribute | `geometry/canvas_selection_transform.dart`, `CanvasArrangeSelection` |
| Vector fill of closed doodles | `CanvasFillStroke`, closure tolerance in `canvas_element_geometry.dart` |
| Image crop, flip, rounded clip, border, brightness/contrast/saturation, reference fade | `ImageElement`, `view/widgets/image_crop_dialog.dart` |
| Page presets (A4 etc.), rulers, page bounds | `canvas_board_settings.dart` |
| PNG / PDF / SVG export, 1–4× scale, transparent background, board or frame scope | `lib/domain/models/canvas/canvas_export_options.dart` |
| Collaborative undo/redo, history screen, milestones, revert review | `lib/features/canvas/bloc/`, `view/history_screen.dart` |

---

## Tier 1 — blocks professional drawing

### 1. A real brush engine (custom presets, dynamics, rendered texture)

- **Today:** `brush_preset.dart` defines eight fixed presets and already carries
  `spacing`, `jitter`, `pressureAffectsSize`, `pressureAffectsOpacity`,
  `taperStart/End`, `blurSigma` and `texture`. The file states the limit
  plainly: *only `BrushTexture.wash` changes rendering; `grain` is metadata.*
  Pencil, charcoal and textured therefore paint as plain width-profiled strokes.
- **Missing:** rendered grain/stamp textures, per-stroke size and opacity flow,
  hardness, a pressure response curve, a custom-brush builder, and saving
  personal presets (ideally synced per user).
- **Why it matters:** the largest single "is this a drawing app" signal. Without
  visible material, an artist can sketch here but not finish here.
- **Scope:** large. Renderer work in `canvas_render_utils.dart` plus
  `paintCanvasStroke`, a preset editor surface, a JSON-serialised brush schema,
  and golden coverage per brush to keep PNG/PDF/SVG in step.

### 2. Canvas rotation

- **Today:** `canvas_viewport_math.dart` supports pan and zoom only
  (`minCanvasZoom` 0.1, `maxCanvasZoom` 4.0); there is no view rotation anywhere
  in the canvas feature.
- **Missing:** two-finger view rotation, snap to 0/90/180, rotate-to-selection,
  and a "reset rotation" affordance.
- **Why it matters:** every digital artist rotates the canvas to draw a
  comfortable stroke direction. It is felt within minutes of lineart.
- **Scope:** medium. The viewport transform is centralised, but every screen
  point ↔ world point conversion, hit test, overlay and gesture path must
  account for the extra rotation.

### 3. Smudge / blend / blur / sharpen tools

- **Today:** `smudge` appears nowhere in the canvas feature; the only softening
  is the watercolor preset's `blurSigma`.
- **Missing:** a smudge tool that pushes existing pigment, plus local
  blur/sharpen/liquify tools.
- **Why it matters:** form rendering and colour transitions are done with a
  blender in nearly every painterly workflow. Today an artist can only add
  pigment, never move what is already down.
- **Scope:** large. Pulling pigment requires sampling the composited raster
  under the cursor, which the vector-element model does not currently expose.

### 4. Pressure calibration and stylus ergonomics

- **Today:** pressure and tilt are captured per point and persisted per stroke.
- **Missing:** input pressure curve, minimum-pressure threshold, stylus-button
  mapping, palm-rejection tuning, and configurable gestures (two-finger tap =
  undo, drag = brush size/opacity).
- **Why it matters:** one brush feels completely different across tablets;
  without calibration, brush tuning is guesswork.
- **Scope:** small–medium, mostly a settings surface plus a curve applied in the
  stroke input path.

---

## Tier 2 — blocks professional finishing

### 5. Layer masks, alpha lock, clipping masks

- **Today:** `LayerElement` has `name`, `elementIds`, `blendMode`, `opacity`
  and inherited `hidden`/`locked`. That is a group with faders, not a
  compositing layer.
- **Missing:** layer masks, alpha lock, clipping to the layer below, nested
  groups, merge/flatten.
- **Why it matters:** this is how shading, highlights and texture stay
  non-destructive. Without it every pass must be committed, so lighting cannot
  be revised later.
- **Scope:** large. Needs a composited render target per layer (offscreen raster
  or an element-mask model) and matching export support.

### 6. Non-destructive adjustments for layers and the whole board

- **Today:** brightness/contrast/saturation exist only as `ImageElement` fields,
  applied through a 4×5 colour matrix in `canvas_element_geometry.dart`.
- **Missing:** hue/saturation, levels/curves, colour balance, applied to a layer
  or the whole board non-destructively.
- **Why it matters:** finishing is largely tonal correction. Per-image-only
  sliders force early rasterising.
- **Scope:** medium once a layer render target exists (item 5); the colour-matrix
  plumbing is already there and shared with export.

### 7. Pixel-level selection

- **Today:** selection is element-level — marquee and lasso choose whole
  elements whose geometry falls inside the path.
- **Missing:** magic wand, feather, grow/shrink, invert, select-by-colour.
- **Why it matters:** an artist cannot isolate a shadow, a hair mass or a
  background wash to move or recolour it. Element selection is excellent for
  diagrams but limiting for painting.
- **Scope:** large, and depends on the raster/compositing work in items 5–6.

### 8. Gradient and pattern fills

- **Today:** gradients exist only as a `ShapeElement` fill mode
  (`gradientStart/End/Angle`); fill only fills closed doodles.
- **Missing:** linear/radial/angle gradient tool over any region, hatch/pattern
  fills, fill tolerance control.
- **Why it matters:** skies, atmospheric perspective and hatching currently cost
  dozens of manual strokes.
- **Scope:** medium. Gradients can reuse the existing shape-fill renderer; the
  pattern part needs a tile source and export parity.

---

## Tier 3 — workflow and output quality

### 9. Text that is usable for design

- **Today:** `fontFamily` is a text-element field, but no font library or picker
  surface exists; the edit bar exposes size, colour and rotation only.
- **Missing:** font picker with real families, letter/line spacing, weight and
  italic, text outline, text on a path.
- **Why it matters:** covers, labels, comic lettering and poster mockups depend
  on typography.
- **Scope:** medium; bundling fonts adds app size, so a curated set plus
  variable-font support is the cheaper route.

### 10. Export built for delivery

- **Today:** `BoardExportFormat { png, pdf, svg }`, 1–4× scale, transparent
  background, board or frame scope.
- **Missing:** JPEG/WebP, explicit DPI and print size with bleed, export
  selection only, per-layer PNG sequence.
- **Why it matters:** artists deliver to clients, print shops and social.
- **Scope:** small–medium. The raster pipeline already exists; this is mostly
  encoders and an options surface.

### 11. Reference and tracing upgrades

- **Today:** `isReference` with reference fade, plus a working eyedropper — this
  is already ahead of most whiteboard apps.
- **Missing:** pinned/floating reference pane, split view, sample colour without
  leaving the current tool (Alt-modifier), per-reference opacity/blur/desaturate.
- **Why it matters:** reference use is constant and currently competes with the
  canvas for screen space.
- **Scope:** small; `ImageElement` already has the fields for most of it.

### 12. Stamps, stickers and a reusable asset library

- **Today:** shapes, tables, frames and pasted images.
- **Missing:** stamp brushes (foliage, rubble, hair strands), a personal asset
  shelf, drag-from-library placement.
- **Why it matters:** environment and texture work is largely stamping — the
  fastest quality-per-hour win for background-heavy art.
- **Scope:** medium; a stamp is a textured brush plus an asset store.

### 13. Colour workflow depth

- **Today:** HSV picker with alpha, hex entry, recent colours, user palettes.
- **Missing:** palette extraction from a reference image, harmony suggestions,
  mixing well.
- **Why it matters:** building a palette from a photo is standard practice.
- **Scope:** small–medium; extraction can reuse `sampleCanvasColorAt`-style
  sampling over the image's decoded bytes.

---

## Tier 4 — differentiators

### 14. Frame-by-frame animation and onion skin

- **Today:** `onion` and `timelapse` return zero hits in the canvas feature;
  frames are layout containers only.
- **Missing:** frames as cels, onion skin, playback, exposure sheet.
- **Why it matters:** opens animatics and simple 2D animation — an optional,
  sizeable capability rather than a gap in stills work.
- **Scope:** large.

### 15. Timelapse / process replay export

- **Today:** history is strong (CRDT undo, milestones, per-user timelines,
  revert review), so the data for a replay largely exists.
- **Missing:** rendering that history into a video.
- **Why it matters:** timelapses drive social proof and study.
- **Scope:** medium, additive on top of the history service.

---

## Suggested build order

1. **Canvas rotation** — removes constant friction, contained blast radius.
2. **Rendered brush grain + per-stroke size/opacity** — turns eight presets into
   an engine.
3. **Layer masks / alpha lock** — unlocks non-destructive finishing and is the
   prerequisite for items 5–7.

Those three move the canvas from "shared whiteboard with a strong draw tool" to
"a drawing app an artist would choose". Items 4, 9, 10, 11 are the next cheap
wins; 3, 7 and 14 are the large investments.

---

## Definition of done per item

- Both render paths agree: `test/features/canvas/paint_parity_test.dart`,
  `test/features/canvas/cross_path_equivalence_test.dart` and
  `test/features/canvas/view/canvas_painter_golden_test.dart` stay green.
- New scroll/gesture surfaces are covered where the existing canvas tests cover
  comparable interactions.
- The feature persists through CRDT (survives reload and collaborator sync) and
  through export (PNG, PDF, SVG) before it is called done.
