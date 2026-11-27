# InkLink Large-File Refactor Plan

**Status:** Proposal
**Baseline commit:** `9589bde` (2026-11-22)
**Scope:** Flutter client (`lib/`), with the canvas feature as the primary target
**Goal:** Reduce the largest files to reviewable, single-responsibility modules, create reusable building blocks, and prevent regression with guardrails.

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [How this analysis was done](#2-how-this-analysis-was-done)
3. [Current state](#3-current-state)
4. [Target architecture](#4-target-architecture)
5. [Detailed split maps](#5-detailed-split-maps)
6. [Reuse plan](#6-reuse-plan)
7. [Phased roadmap](#7-phased-roadmap)
8. [Guardrails and CI](#8-guardrails-and-ci)
9. [Risk register](#9-risk-register)
10. [Definition of done](#10-definition-of-done)
11. [Appendix A: CanvasScreen method inventory](#appendix-a-canvasscreen-method-inventory)
12. [Appendix B: CanvasBloc handler inventory](#appendix-b-canvasbloc-handler-inventory)
13. [Appendix C: first-PR checklist](#appendix-c-first-pr-checklist)

---

## 1. Executive summary

The client has **281 non-generated Dart files and 105,147 lines** in `lib/`. The distribution is extremely top-heavy:

| Metric | Count |
|---|---:|
| Files over 1,000 lines | 18 |
| Files over 800 lines | 26 |
| Files over 500 lines | 47 |
| Lines in the top 20 files | 51,497 (**49% of `lib/`**) |

The canvas feature alone accounts for roughly **26,600 lines** across five files:

| File | Lines |
|---|---:|
| `lib/features/canvas/view/canvas_screen.dart` | 12,827 |
| `lib/features/canvas/bloc/canvas_bloc.dart` | 9,800 |
| `lib/features/canvas/geometry/canvas_element_geometry.dart` | 2,303 |
| `lib/features/canvas/models/canvas_element.dart` | 1,851 |
| `lib/features/canvas/bloc/canvas_event.dart` | 1,831 |
| `lib/features/canvas/view/canvas_painter.dart` | 1,692 |
| `lib/features/canvas/bloc/canvas_helpers.dart` | 437 |

The two files the request calls out are therefore **larger than estimated**:

- `canvas_screen.dart`: 12,827 lines, 195+ methods, 197 field-like declarations, a single `build()` method of ~1,435 lines, and 50+ `_build…` methods.
- `canvas_bloc.dart`: 9,800 lines, 186 event registrations, 245 field-like declarations, and handlers covering CRDT sync, element CRUD, selection, layers, undo/redo, history scrubbing, undo requests, chat, comments, voice, members, and export.

**Recommended approach:** a seven-phase, move-first refactor. Phase 1–3 are mechanical splits that keep behavior identical and rely on the existing 457 canvas tests. Phase 4 extracts reusable widgets and controllers. Phase 5 handles the other large files. Phase 6 is an optional state/render-model redesign. Phase 7 ratchets the line-count guardrail down.

**Expected outcome:**

- `canvas_screen.dart` ≤ 800 lines; no canvas view file over ~900 lines.
- `canvas_bloc.dart` ≤ 600 lines; handlers grouped by concern in files of ~400–900 lines.
- Pure models, geometry, and rendering in small, testable files that can be reused by the painter, exporter, history preview, media editor, and future element types.
- CI prevents new files from becoming god files.

---

## 2. How this analysis was done

1. Counted every non-generated `.dart` file in `lib/` (blank lines included).
2. Extracted class, method, and handler inventories from the largest files.
3. Traced imports and call sites to find reuse and layering problems.
4. Inventoried the existing tests to confirm which splits have a safety net.
5. Read the architecture guardrails (`tool/architecture_guardrails.dart`) and CI workflow.
6. Inspected the rendering pipeline shared by the canvas, exporter, history preview, media editor, and brush tray.

Line ranges in this document are from baseline `9589bde`. They are **navigation aids, not contracts**; after the first move, use method names as anchors.

---

## 3. Current state

### 3.1 Largest files

| # | Lines | File | Dominant responsibilities |
|---:|---:|---|---|
| 1 | 12,827 | `features/canvas/view/canvas_screen.dart` | Viewport, gestures, selection, editing, overlays, panels, sheets, AI, preview, history |
| 2 | 9,800 | `features/canvas/bloc/canvas_bloc.dart` | CRDT sync, all element handlers, selection, layers, undo/redo, history, chat/voice |
| 3 | 3,637 | `domain/services/chat/agora_chat_service.dart` | SDK gateway, login lifecycle, conversation sync, message mapping, offline queue |
| 4 | 2,303 | `features/canvas/geometry/canvas_element_geometry.dart` | Text, shapes, frames, connectors, images, sticky notes, tables, paint order, hit testing |
| 5 | 1,972 | `domain/services/canvas/board_export_service.dart` | PNG rendering, PDF generation, SVG serialization, file paths, sharing |
| 6 | 1,851 | `features/canvas/models/canvas_element.dart` | Sealed base + 9 element subclasses + table cell model |
| 7 | 1,831 | `features/canvas/bloc/canvas_event.dart` | 186 event classes |
| 8 | 1,734 | `domain/repositories/chat/chat_repository_impl.dart` | Isar conversation/message queries + key scoping + mapping |
| 9 | 1,714 | `domain/repositories/board/board_repository_impl.dart` | Board sync engine, local cache, previews, CRUD |
| 10 | 1,692 | `features/canvas/view/canvas_painter.dart` | Render model + interactive painting + overlays + repaint checks |
| 11 | 1,587 | `domain/repositories/canvas/canvas_sync_repository_impl.dart` | Socket lifecycle, watch board, cursors, gap recovery, batch sync |
| 12 | 1,412 | `features/dashboard/view/board_settings_screen.dart` | Settings form, invite section, member/role section, dialogs |
| 13 | 1,345 | `features/workspaces/bloc/workspace_bloc.dart` | Events, state, handlers, subscriptions, invite decisions |
| 14 | 1,305 | `features/canvas/view/history_screen.dart` | Filters, list, rows, dialogs, refresh control |
| 15 | 1,201 | `features/chat/view/widgets/chat_bubble.dart` | Bubble, animations, swipe-to-reply, media, share cards, actions |
| 16 | 1,189 | `features/notifications/view/notifications_screen.dart` | Four invitation decision flows + list UI + filter bar |
| 17 | 1,164 | `domain/repositories/workspace/workspace_repository_impl.dart` | Workspace sync streams, invites, members, mapping |
| 18 | 1,017 | `features/canvas/view/widgets/revert_review_sheet.dart` | Review sheet + element preview painter + decision widgets |

Additional files over 800 lines: `friends_repository_impl.dart` (989), `settings_screen.dart` (927), `board_template.dart` (918), `brush_tray.dart` (904), `layers_tray.dart` (880), `profile_screen.dart` (842), `color_picker_sheet.dart` (836).

### 3.2 `CanvasScreen` anatomy

`_CanvasScreenState` is a single `State` object that owns every concern in the canvas:

| Current lines | Cluster | What it does |
|---:|---|---|
| 1–293 | Imports, widget, fields | 100+ mutable fields covering viewport, strokes, selection, AI, text, history, marquee, lasso |
| 294–472 | Lifecycle, preferences, tray | `initState`, app lifecycle, color preferences, tray tips |
| 473–839 | History actions | Open history, restore version, scrub, undo-request scope, area selection |
| 840–1106 | Pointer and selection primitives | Raw pointer capture, world/screen conversion, stroke start/append/end, shape selection |
| 1107–1425 | Shape editing | Select, move, resize, rotate, label debounce, edge auto-pan |
| 1426–1751 | AI images | Generate, subscribe, recent images, action bar, edit/repaint/regenerate |
| 1752–2044 | Image pipeline | Pick/upload, read dimensions, decode cache, sync decoded images |
| 2045–2282 | Viewport | Apply transform, center, reset, fit-to-content, auto-frame, snap, undo/redo |
| 2283–3047 | Dialogs | Frame title, add/edit table cell, context menu, sticky note, connector |
| 3048–3227 | Preview and exit | Render blank board, save preview, exit, open settings |
| 3228–3423 | Zoom and minimap | Pointer signal zoom, zoom buttons, minimap, undo/redo controls |
| 3424–4548 | Sheets | Canvas settings (517), symmetry (168), export (316), export tiles |
| 4549–5983 | `build()` | Listener + gesture detector + painter + 20+ overlay layers (1,435 lines) |
| 5984–6238 | `_mapElements` | Converts domain elements to `_CanvasElement`, applies previews, sorts |
| 6240–6392 | Hit testing | Connectable shape, topmost fill, shape hit |
| 6393–7293 | Editing bar and panel | Element editing bar, control body, selected element panel |
| 7294–7636 | Selection overlays | Selection outline, multi-selection outline, group scale/rotate handles |
| 7637–8093 | Element overlays | Frame panel, sticky note banner, connector selection and rewiring |
| 8094–8384 | Toolbar overlays | Canvas toolbar, shapes popup, lasso, selection mode toggle, marquee |
| 8385–8664 | Multi-select | Multi-select bar, selection style sheet |
| 8665–9020 | Text editing | Begin/commit text editing, text editor overlay, selected text panel, banner |
| 9020–9291 | Stroke editing | Stroke selection overlay, edit banner, selected stroke panel |
| 9292–9951 | Shape panel | Selected shape panel (495) + slider/chip helpers |
| 9952–10373 | Connector panel | Selected connector panel (395) |
| 10374–10692 | Image panel | Selected image panel (300) |
| 10693–11283 | Shape transform overlay | Drag/resize/rotate handles and geometry (591) |
| 11284–11637 | Status and banners | History plan listener, undo conflict listener, sync indicator, archived/paused banners |
| 11638–12127 | Top bar | Top pills, menu, request-edit dialog, member avatar stack |
| 12128–12442 | Edge UI | Edge triggers, undo-request hints, area selection hint |
| 12443–12634 | Comments and dispose | Comment prompt, pinned comment pins, dispose |
| 12635–12826 | Private classes | Viewport transform, text/shape drafts, triangle/lasso painters, dialogs |

The `build()` method is the composition root for the whole canvas. It nests three separate `Offstage` + `IgnorePointer` + `Stack` layers and interleaves state reads, layout math, and widget construction.

### 3.3 `CanvasBloc` anatomy

`CanvasBloc` registers **186 event handlers** in one constructor. Its mutable state includes CRDT adapters, subscriptions, preview maps, undo/redo payload maps, stroke sessions, eraser sessions, history scrub adapters, and export state.

Handler clusters (line ranges are indicative):

| Current lines | Cluster | Notes |
|---:|---|---|
| 62–393 | Fields, constructor, registration, getters | 186 `on<…>` calls |
| 399–472 | Board title/rename/unavailable | Small |
| 473–1276 | CRDT initialization and sync | Listeners, remote update/preview, publish, queue, rebuild |
| 1277–1705 | CRDT materialization and z-order | Rebuild elements, z-index helpers |
| 1706–2011 | Stroke input | Start/append/end/cancel, quick shape, stabilizer |
| 2012–2096 | Shape creation | Add shape, commit new shape |
| 2097–2293 | Text | Add, measure, update |
| 2294–2633 | Images | Add, update, replace, style, AI fields, fit |
| 2634–2778 | Sticky notes | Add, convert, update |
| 2779–2858 | Import | Import elements |
| 2859–2933 | Board settings and guides | Settings, add/move/remove guide |
| 2934–3145 | Frames | Add, update, delete, capture, host frame, attach/detach, move |
| 3146–3343 | Tables | Add, cell update, style update |
| 3344–3526 | Connectors | Add, update, rewire |
| 3527–3642 | Conflict records | Deep copy/equality, commit records, redo targets |
| 3643–3876 | Undo/redo/clear/delete | Undo, redo, clear all, delete |
| 3877–4049 | Brush/tool settings | Color, width, opacity, type, preset, eraser scope, stylus, stabilizer, tool mode |
| 4050–4242 | Shape drawing | Start/update/end/cancel |
| 4243–4544 | Selection | Select shape/elements, rect, lasso, mode, translate/scale/rotate, align |
| 4545–4866 | Arrange | Grid/row/column/tree/flow layout |
| 4867–5056 | Clipboard | Duplicate, delete, copy, paste |
| 5057–5410 | Layers and ordering | Visibility, lock, opacity, reorder, move to layer, add/rename/delete layer |
| 5411–5619 | Element metadata and deltas | Update meta, apply selection deltas, translated payload |
| 5620–6188 | Selected shape operations | Move, rotate, resize, fill, colors, flip, radius, stroke, dash, label, arrowheads, commit |
| 6189–6505 | Selected stroke operations | Move, fill, clear fill, style, layer, retry, color/width/opacity/brush, commit |
| 6506–6790 | Write primitives | Update stroke/shape, attached connector updates, sync |
| 6791–6938 | Preview edits | Pending shape edits, preview move/resize/rotate |
| 6939–7221 | Eraser | Begin/extend/publish cursor/finish/commit/overlay/prune |
| 7222–7243 | Trays | Toggle tray, tips |
| 7244–7343 | Members | Members updated, search, remove, role |
| 7344–7390 | Preview and pause | Save preview, set paused |
| 7391–7510 | Export and messages | Export board, consume export/info messages, request edit |
| 7511–9226 | History | Feed, load older, live tail, preview, evidence, area selection, undo request draft/preview/submit, revert, user ops, scrub, compare, apply |
| 9227–9311 | Undo own and conflicts | Undo own via log, dismiss conflict, undo requests updated |
| 9312–9409 | Permission checks | Viewer/archived/paused warnings |
| 9410–9752 | Communication | Comments, chat, voice listeners and actions |
| 9753–9800 | `close()` | Cancel subscriptions, timers, adapters |

### 3.4 Rendering, models, and geometry

Three layers currently define "what an element looks like":

1. **Domain models** (`canvas_element.dart`): sealed `CanvasElement` with `toMap`/`fromMap`.
2. **Interactive render model** (`canvas_painter.dart`): private `_CanvasElement` duplicates every field of every domain element and stores a full `data` map per element.
3. **Shared geometry/painters** (`canvas_element_geometry.dart`): paint functions for shapes, frames, connectors, images, sticky notes, tables; plus bounds, hit testing, and paint order.

Consequences:

- `_mapElements` calls `e.toMap()` for every element on **every build**, then stores that map in `_CanvasElement`.
- The painter reconstructs domain objects from `data` at paint time (`CanvasElement.fromMap`, manual `ShapeElement(...)` construction, `ImageElement.copyWith`). Shape, image, sticky note, and connector paint paths each do their own parsing.
- Adding a new element type requires touching the model, the render model, `_mapElements`, the painter switch, the geometry file, the export switch, the bloc handlers, and at least one panel.
- The painter cannot be tested independently because it is a `part of canvas_screen.dart`.
- The export service and history preview have their own simplified element painters (for example `revert_review_sheet.dart` has a local `_paintStroke`), so visual behavior can drift.

### 3.5 Layering and reuse findings

1. **Feature models are the de facto domain models.** Domain services import `features/canvas/models/*` and `features/canvas/geometry/*` directly:
   - `domain/services/canvas/board_export_service.dart` imports `canvas_geometry.dart`, which re-exports the feature geometry.
   - `domain/services/voice/voice_service.dart` imports `features/canvas/models/voice_participant.dart`.
   - `domain/services/canvas/board_comments_service.dart` imports `features/canvas/models/canvas_comment.dart`.
   - `domain/repositories/canvas/board_comments_repository.dart` does the same.
   `domain/models/canvas/canvas_element.dart` is only an export shim back to the feature file.
2. **The screen is not UI-only.** `CanvasScreen` directly reads preferences, creates image pickers, renders previews, shares files, and owns AI image state. The architecture guardrail only checks for service/repository imports, so these leaks are invisible.
3. **The bloc owns too many domains.** History, CRDT sync, chat/comments/voice, and element editing share one state object and one event stream. This makes every new event a change to a 9,800-line file.
4. **The state is a god object.** `CanvasState` has **96 final fields** and a ~180-line `copyWith`. Many fields are only relevant to one concern (history, export, collaboration).
5. **The painter is private to the screen.** `canvas_painter.dart` is `part of canvas_screen.dart`, so no other widget or test can reuse `_CanvasPainter`, `_CanvasElement`, or its repaint logic.
6. **Guardrails do not cover parts or file size.** `_checkBlocLayerBoundaries` only matches `*_bloc.dart`; a `part` file under `bloc/` would bypass it. There is no line-count rule.

### 3.6 What is already good

- **Tests are organized by concern.** There are 116 test files and roughly 457 canvas tests, including `canvas_bloc_test.dart`, `canvas_selection_bloc_test.dart`, `canvas_history_bloc_test.dart`, `canvas_layers_bloc_test.dart`, geometry tests, tray tests, and performance tests. This is the safety net that makes mechanical splits low-risk.
- **Geometry is already the single source of truth** for bounds, hit testing, paint order, frames, connectors, and element paint functions. The split only needs to organize it, not redesign it.
- **Stroke rendering is already shared** through `paintCanvasStroke` in `canvas_render_utils.dart`, used by the interactive painter, exporter, and brush tray. The remaining duplication is in preview painters.
- **The architecture guardrail script is simple and extensible.** Adding part-file coverage and a size budget is a small change.
- **The route wrapper already owns composition.** `canvas_route.dart` creates `CanvasBloc` and `AiImageBloc`, so screen extraction does not require provider changes.

---

## 4. Target architecture

### 4.1 Principles

1. **One reason to change per file.** Split by responsibility, never by arbitrary line count.
2. **Move first, improve second.** Every extraction PR should be behavior-preserving. Refactors of logic get their own PR with tests.
3. **Pure core, thin shell.** Models, geometry, rendering, and algorithms should not depend on `CanvasState`, `BuildContext`, or the bloc.
4. **Compose, don't inherit.** The screen composes layer widgets; the bloc composes handler mixins.
5. **Explicit contracts for reusable widgets.** A reusable panel takes data and callbacks, not the entire `CanvasState` or `CanvasBloc`.
6. **Barrels preserve public paths.** Keep `canvas_element.dart`, `canvas_event.dart`, `canvas_element_geometry.dart`, and `canvas_geometry.dart` as re-export barrels during the migration.
7. **Ratchet, don't big-bang.** The file-size guardrail allows current sizes but only permits them to decrease.

### 4.2 Dependency rule

```
domain/models/canvas (pure data)
        ↑
features/canvas/geometry (pure math + dart:ui paint)
        ↑
features/canvas/rendering (pure render pipeline)
        ↑
features/canvas/bloc (state, events, handlers)
        ↑
features/canvas/view (widgets, screen, overlays)
```

No arrows may point downward. In particular:

- Geometry and rendering must not import the bloc or view.
- Bloc must not import widgets or `BuildContext`.
- View may import bloc, geometry, rendering, and UI kit.
- Domain services may import pure canvas models and rendering, but not the feature's bloc or view.

### 4.3 Target tree for the canvas feature

```
lib/features/canvas/
  models/                        # only view-specific enums/models + compatibility shims
  geometry/
    canvas_text_layout.dart
    canvas_shape_geometry.dart
    canvas_frame_geometry.dart
    canvas_connector_geometry.dart
    canvas_image_geometry.dart
    canvas_sticky_note_geometry.dart
    canvas_table_geometry.dart
    canvas_paint_order.dart
    canvas_bounds.dart
    canvas_hit_test.dart
    canvas_element_geometry.dart      # barrel, re-exports the above
  rendering/
    canvas_stroke_renderer.dart       # paintCanvasStroke, resampling, brush styles
    canvas_element_renderer.dart      # one switch: element -> paint
    canvas_render_model.dart          # render overrides / mapped element
    canvas_background_renderer.dart
    canvas_overlay_renderer.dart      # previews, erasers, selection highlights
  bloc/
    canvas_bloc.dart                  # fields, constructor, registration, close
    state/
      canvas_state.dart               # composition + copyWith + getters
      canvas_tool_state.dart
      canvas_selection_state.dart
      canvas_history_state.dart
      canvas_collaboration_state.dart
      canvas_export_state.dart
      canvas_ui_state.dart
    events/
      canvas_event.dart               # base + barrel
      canvas_board_events.dart
      canvas_sync_events.dart
      canvas_stroke_events.dart
      canvas_shape_events.dart
      canvas_text_events.dart
      canvas_image_events.dart
      canvas_sticky_note_events.dart
      canvas_frame_events.dart
      canvas_table_events.dart
      canvas_connector_events.dart
      canvas_selection_events.dart
      canvas_layer_events.dart
      canvas_history_events.dart
      canvas_undo_request_events.dart
      canvas_communication_events.dart
      canvas_member_events.dart
      canvas_export_events.dart
    handlers/
      canvas_crdt_handlers.dart
      canvas_stroke_handlers.dart
      canvas_shape_handlers.dart
      canvas_text_handlers.dart
      canvas_image_handlers.dart
      canvas_sticky_note_handlers.dart
      canvas_structure_handlers.dart  # frames, tables, connectors, guides
      canvas_selection_handlers.dart
      canvas_layer_handlers.dart
      canvas_undo_handlers.dart
      canvas_history_handlers.dart
      canvas_undo_request_handlers.dart
      canvas_communication_handlers.dart
      canvas_board_handlers.dart      # members, permissions, export, trays
      canvas_helpers.dart             # small shared helpers
  view/
    canvas_screen.dart                # widget, lifecycle, composition, dispose
    screen/                           # transitional parts for private state
      canvas_screen_viewport.dart
      canvas_screen_gestures.dart
      canvas_screen_selection.dart
      canvas_screen_shape_editing.dart
      canvas_screen_ai_images.dart
      canvas_screen_history_actions.dart
      canvas_screen_preview.dart
      canvas_screen_dialogs.dart
      canvas_screen_build.dart
    layers/
      canvas_ink_layer.dart           # Listener + GestureDetector + CustomPaint
      canvas_overlay_stack.dart
    overlays/
      selection_outline.dart
      group_transform_overlay.dart
      shape_transform_overlay.dart
      connector_selection_overlay.dart
      canvas_top_bar.dart
      canvas_edge_triggers.dart
      canvas_status_banners.dart
      comment_pins.dart
      history_preview_layer.dart
    panels/
      element_editing_bar.dart
      element_edit_controls.dart
      selected_element_panel.dart
      selected_shape_panel.dart
      selected_connector_panel.dart
      selected_image_panel.dart
      selected_text_panel.dart
      selected_stroke_panel.dart
      selected_frame_panel.dart
      multi_select_bar.dart
      panel_controls.dart             # shared slider, swatch, section, chip
    sheets/
      canvas_settings_sheet.dart
      symmetry_sheet.dart
      export_sheet.dart
      selection_style_sheet.dart
    dialogs/
      table_dialogs.dart
      connector_dialog.dart
      sticky_note_dialogs.dart
      frame_title_dialog.dart
      canvas_context_menu.dart
      undo_request_sheets.dart
    widgets/                          # existing shared widgets remain
    trays/                            # existing trays remain
    chat/                             # existing chat drawer remains
    voice/                            # existing voice HUD remains
```

### 4.4 `part` vs. library decision matrix

| Situation | Use | Why |
|---|---|---|
| Code needs private fields of `_CanvasScreenState` | `part` + extension | Same library gives private access without exposing internals |
| Code needs private fields of `CanvasBloc` | `part` + mixin `on CanvasBloc` | Mixin can access library-private members and register handlers |
| Reusable widget with explicit props | Separate library | Own imports, testable in isolation, no private coupling |
| Pure model/geometry/rendering | Separate library | Reusable by domain services, exporter, tests |
| Event classes | Separate library + barrel | No private access needed; UI can import only events |
| State sub-objects | Separate library | Composable, testable `copyWith` |

**Rule:** `part` files are a transitional tool for private implementation. Anything reusable must become its own library by the end of Phase 4.

### 4.5 Naming conventions

- Handler mixins: `_CanvasHistoryHandlers`, `_CanvasCrdtHandlers`, etc. (private, same library).
- Screen extensions: `_CanvasViewportScreen`, `_CanvasGestureScreen`, etc.
- Extracted widgets: public names (`CanvasTopBar`, `SelectedShapePanel`).
- Controllers: `CanvasViewportController`, `CanvasTextEditingController`, `CanvasAiImageController`, `CanvasPreviewController`.
- Render model: `CanvasRenderElement` (public, replaces private `_CanvasElement`).
- Events: keep existing names to avoid breaking tests.

---

## 5. Detailed split maps

### 5.1 `CanvasScreen` → files

**Target:** `canvas_screen.dart` ≤ 800 lines. Transitional parts ≤ 900 lines. Extracted widgets ≤ 500 lines.

| Current lines | Move to | Contents |
|---:|---|---|
| 1–293 | `canvas_screen.dart` + controllers | Widget, constructor, remaining shared fields, lifecycle |
| 294–472 | `canvas_screen.dart` + `canvas_screen_preferences.dart` | `initState`, `didUpdateWidget`, lifecycle, preferences, color palette persistence |
| 473–839 | `screen/canvas_screen_history_actions.dart` | Open history, restore version, scrub, undo-request scope, area selection |
| 840–1106 | `screen/canvas_screen_gestures.dart` | Pointer capture, world/screen conversion, stroke lifecycle, shape selection |
| 1107–1425 | `screen/canvas_screen_shape_editing.dart` | Shape select/move/resize/rotate, label debounce, edge auto-pan |
| 1426–1751 | `screen/canvas_screen_ai_images.dart` + `CanvasAiImageController` | AI generate/subscribe/recent/action bar/edit/repaint/regenerate |
| 1752–2044 | `CanvasImagePipeline` (view service) | Pick/upload, dimensions, decode cache, sync decoded images |
| 2045–2282 | `screen/canvas_screen_viewport.dart` + `CanvasViewportController` | Transform, center, reset, fit, auto-frame, snap, undo/redo |
| 2283–3047 | `dialogs/` | Frame title, table dialogs, context menu, sticky note, connector |
| 3048–3227 | `CanvasPreviewController` | Render blank board, save preview, exit, open settings |
| 3228–3423 | `overlays/zoom_controls.dart` + existing minimap | Zoom buttons, pointer zoom, minimap placement |
| 3424–4548 | `sheets/` | Canvas settings (517), symmetry (168), export (316), export tile |
| 4549–5983 | `canvas_screen.dart` + `layers/canvas_ink_layer.dart` + `layers/canvas_overlay_stack.dart` | `build()` composition; gesture handler delegates to controllers |
| 5984–6238 | `rendering/canvas_render_model.dart` | `_mapElements`, group preview, pending edits, drag previews, sorting |
| 6240–6392 | `geometry/canvas_hit_test.dart` | Connectable hit, topmost fill, shape hit |
| 6393–7293 | `panels/` | Element editing bar, edit controls, selected element panel |
| 7294–7636 | `overlays/selection_outline.dart`, `overlays/group_transform_overlay.dart` | Selection box, multi-selection outline, group handles |
| 7637–8093 | `overlays/` | Frame panel, sticky note banner, connector overlay/rewire |
| 8094–8384 | `overlays/` | Toolbar, shapes popup, lasso, selection mode, marquee |
| 8385–8664 | `panels/multi_select_bar.dart`, `sheets/selection_style_sheet.dart` | Multi-select actions, style sheet |
| 8665–9020 | `panels/text_editor_overlay.dart` + `CanvasTextEditingController` | Text draft, begin/commit, overlay, text panel, banner |
| 9020–9291 | `panels/selected_stroke_panel.dart` | Stroke overlay, banner, panel |
| 9292–9951 | `panels/selected_shape_panel.dart`, `panels/panel_controls.dart` | Shape panel, section label, sliders, dash chips, align chips |
| 9952–10373 | `panels/selected_connector_panel.dart` | Connector panel |
| 10374–10692 | `panels/selected_image_panel.dart` | Image panel, crop entry |
| 10693–11283 | `overlays/shape_transform_overlay.dart` | Shape transform handles and geometry |
| 11284–11637 | `overlays/canvas_status_banners.dart` | History/undo listeners, sync indicator, archived/paused/read-only banners |
| 11638–12127 | `overlays/canvas_top_bar.dart` | Top pills, menu, request-edit dialog, avatar stack |
| 12128–12442 | `overlays/canvas_edge_triggers.dart`, `overlays/undo_request_hints.dart` | Edge tabs, pick hint, pending notice, area hint |
| 12443–12634 | `overlays/comment_pins.dart` + `canvas_screen.dart` | Comment prompt/pins; `dispose` stays |
| 12635–12826 | Moved with owners | `_ViewportTransform`, `_TextEditorDraft`, `_ShapeTransformDraft`, painters, dialogs |

**Screen split sequence:**

1. Move `build()` and the layer composition into `screen/canvas_screen_build.dart` as an extension; keep the `build` override delegating to `_buildScreen(context)`.
2. Move viewport and gesture methods into their parts; replace `setState` calls with controller notifiers only in Phase 4.
3. Move panel builders into parts; then convert each part into a standalone widget one at a time.
4. Move sheets/dialogs directly to standalone libraries (they already have clear inputs).
5. Remove empty parts as widgets are extracted.

### 5.2 `CanvasBloc` → files

**Target:** `canvas_bloc.dart` ≤ 600 lines. Handler files ≤ 900 lines.

Use mixins in `part` files:

```dart
// canvas_bloc.dart
part 'handlers/canvas_crdt_handlers.dart';
part 'handlers/canvas_history_handlers.dart';
...

class CanvasBloc extends Bloc<CanvasEvent, CanvasState>
    with
        _CanvasBoardHandlers,
        _CanvasCrdtHandlers,
        _CanvasStrokeHandlers,
        _CanvasShapeHandlers,
        _CanvasTextHandlers,
        _CanvasImageHandlers,
        _CanvasStickyNoteHandlers,
        _CanvasStructureHandlers,
        _CanvasSelectionHandlers,
        _CanvasLayerHandlers,
        _CanvasUndoHandlers,
        _CanvasHistoryHandlers,
        _CanvasUndoRequestHandlers,
        _CanvasCommunicationHandlers {
```

Each part:

```dart
part of '../canvas_bloc.dart';

mixin _CanvasHistoryHandlers on CanvasBloc {
  Future<void> _onHistoryFeedRequested(...) async { ... }
}
```

| Current lines | Move to | Contents |
|---:|---|---|
| 62–393, 9753–9800 | `canvas_bloc.dart` | Fields, constructor, handler registration, getters, `close()` |
| 399–472, 7222–7510, 9312–9409 | `handlers/canvas_board_handlers.dart` | Board title/rename/unavailable, trays, members, preview/pause, export, request edit, permissions |
| 473–1705, 3527–3642 | `handlers/canvas_crdt_handlers.dart` | Init, listeners, remote update/preview, publish, queue, rebuild, conflict records |
| 1706–2011, 3877–4049, 6939–7221 | `handlers/canvas_stroke_handlers.dart` | Stroke input, quick shape, brush settings, tool mode, eraser |
| 2012–2096, 4050–4242, 5620–6188, 6506–6790 | `handlers/canvas_shape_handlers.dart` | Shape creation/draw, selected shape ops, write primitives |
| 2097–2293 | `handlers/canvas_text_handlers.dart` | Text add/measure/update |
| 2294–2633 | `handlers/canvas_image_handlers.dart` | Image add/update/replace/style/AI fields |
| 2634–2858 | `handlers/canvas_sticky_note_handlers.dart` | Sticky notes + import |
| 2859–3526 | `handlers/canvas_structure_handlers.dart` | Guides, frames, tables, connectors |
| 4243–5619, 6189–6505, 6791–6938 | `handlers/canvas_selection_handlers.dart` | Selection, transforms, align, arrange, clipboard, element meta, previews |
| 5057–5410 | `handlers/canvas_layer_handlers.dart` | Visibility, lock, opacity, reorder, layers |
| 3643–3876 | `handlers/canvas_undo_handlers.dart` | Undo, redo, clear, delete |
| 7511–9226 | `handlers/canvas_history_handlers.dart` | History feed, preview, evidence, scrub, revert, user ops |
| 9227–9311 + undo-request handlers | `handlers/canvas_undo_request_handlers.dart` | Draft, scope, preview, submit, conflict, own undo |
| 9410–9752 | `handlers/canvas_communication_handlers.dart` | Comments, chat, voice |
| 5411–5619 (shared) | `handlers/canvas_helpers.dart` | `_updateElementMeta`, `_applySelectionDeltas`, `_translatedPayload` |

**Important:** keep all 186 `on<…>` registrations in the main file for discoverability. Each handler mixin provides the method; registration stays centralized.

**Phase 2b (optional, after mechanical split):** extract the three largest clusters into collaborator classes with explicit dependencies:

- `CanvasCrdtCoordinator` — owns adapter, subscriptions, preview maps, publish queue, conflict records.
- `CanvasHistoryCoordinator` — owns history feed, scrub adapter, preview state, revert plans.
- `CanvasCommunicationCoordinator` — owns comments/chat/voice subscriptions.

This removes the need for private access and makes each coordinator testable with fakes. It is a larger change; do it only after the mixin split is stable.

### 5.3 `CanvasEvent` → files

Events are public data classes and need no private access. Convert `canvas_event.dart` from a `part` to a library with a barrel:

```
bloc/events/
  canvas_event.dart                 # abstract base + export barrel
  canvas_board_events.dart
  canvas_sync_events.dart
  canvas_stroke_events.dart
  canvas_tool_events.dart
  canvas_shape_events.dart
  canvas_text_events.dart
  canvas_image_events.dart
  canvas_sticky_note_events.dart
  canvas_frame_events.dart
  canvas_table_events.dart
  canvas_connector_events.dart
  canvas_selection_events.dart
  canvas_layer_events.dart
  canvas_undo_events.dart
  canvas_history_events.dart
  canvas_undo_request_events.dart
  canvas_communication_events.dart
  canvas_member_events.dart
  canvas_export_events.dart
```

Compatibility:

- Keep `bloc/canvas_event.dart` as a barrel re-exporting `events/*.dart`.
- `canvas_bloc.dart` imports the barrel and **exports** it so existing test imports keep working.
- Later, update tests and UI to import `events/` directly; the barrel can remain.

Mapping (by class groups in the current file):

| Event group | Target file |
|---|---|
| `CanvasRenameBoardRequested`, `CanvasBoardTitleUpdated`, `CanvasBoardUnavailable`, `CanvasSetBoardPausedRequested` | `canvas_board_events.dart` |
| `CanvasInitializeCrdt`, `CanvasApplyRemoteUpdate`, `CanvasApplyRemotePreview`, `CanvasRetrySync` | `canvas_sync_events.dart` |
| `CanvasStartStroke`, `CanvasAppendStroke`, `CanvasEndStroke`, `CanvasCancelStroke`, `CanvasCommitQuickShape` | `canvas_stroke_events.dart` |
| `CanvasUpdateColor`, `CanvasUpdateStrokeWidth`, `CanvasUpdateBrushOpacity`, `CanvasUpdateBrushType`, `CanvasApplyBrushPreset`, `CanvasUpdateStylusPressure`, `CanvasUpdateStabilizer`, `CanvasUpdateEraserScope`, `CanvasSetToolMode`, `CanvasSetFingerDrawing`, `CanvasSetQuickShapeEnabled` | `canvas_tool_events.dart` |
| `CanvasAddShape`, `CanvasStartShapeDraw`, `CanvasUpdateShapeDraw`, `CanvasEndShapeDraw`, `CanvasCancelShapeDraw`, selected shape events | `canvas_shape_events.dart` |
| `CanvasAddText`, `CanvasAddAiText`, `CanvasUpdateText` | `canvas_text_events.dart` |
| `CanvasAddImageElement`, `CanvasAddAiImageElement`, `CanvasReplaceImageSource`, `CanvasPreviewImageElement`, `CanvasUpdateImageElement`, `CanvasUpdateImageStyle`, `CanvasReplaceImageElement` | `canvas_image_events.dart` |
| Sticky note events | `canvas_sticky_note_events.dart` |
| Frame events | `canvas_frame_events.dart` |
| Table events | `canvas_table_events.dart` |
| Connector events | `canvas_connector_events.dart` |
| Selection, transform, align, arrange, clipboard events | `canvas_selection_events.dart` |
| Layer, visibility, lock, opacity, ordering events | `canvas_layer_events.dart` |
| Undo, redo, clear, delete events | `canvas_undo_events.dart` |
| History feed/preview/scrub/revert events | `canvas_history_events.dart` |
| Undo request draft/preview/submit events | `canvas_undo_request_events.dart` |
| Comments, chat, voice events | `canvas_communication_events.dart` |
| Member, tray, preview, pause events | `canvas_member_events.dart` |
| Export and message events | `canvas_export_events.dart` |

### 5.4 `CanvasState` → files

**Near-term (Phase 2):** split by `part` files while keeping the flat class. This is purely cosmetic but reduces the 800-line file.

```
bloc/state/
  canvas_state.dart          # class, constructor, copyWith, getters
  canvas_tool_state.dart     # part: fields/helpers for tools
  canvas_selection_state.dart
  canvas_history_state.dart
  canvas_collaboration_state.dart
  canvas_export_state.dart
```

**Long-term (Phase 6, optional):** compose sub-states:

```dart
class CanvasState {
  final CanvasDocumentState document;   // boardTitle, elements, boardSettings
  final CanvasToolState tool;           // color, widths, brush, stylus, stabilizer
  final CanvasSelectionState selection; // selected ids, shape flags, mode
  final CanvasHistoryState history;     // preview, scrub, activity, undo requests
  final CanvasCollaborationState collab;// members, comments, chat, voice
  final CanvasExportState export;       // exporting, messages, path
  final CanvasUiState ui;               // trays, tips, errors, sync

  // Backward-compatible getters:
  String? get boardTitle => document.boardTitle;
  List<CanvasElement> get elements => document.elements;
  // ...
}
```

This lets `copyWith` be split per sub-state and makes `BlocSelector`/`buildWhen` checks cheap. It is a high-churn change (every `state.x` stays valid through getters, but constructors and tests may need updates), so keep it last.

**Recommended sub-state boundaries:**

| Sub-state | Fields |
|---|---|
| `CanvasDocumentState` | `boardTitle`, `elements`, `boardSettings`, `activeLayerId`, `currentUserRole`, `isArchived`, `isPaused`, `currentUserId` |
| `CanvasToolState` | `selectedColor`, `strokeWidth`, `brushWidths`, `brushOpacity`, `brushType`, `eraserEraseEverything`, `currentToolMode`, `selectionMode`, `pendingShapeType`, `stylusPressureEnabled`, `quickShapeEnabled`, `fingerDrawingEnabled`, `stabilizerStrength` |
| `CanvasSelectionState` | `selectedShapeId`, `selectedIds`, `selectedShapeIsFilled`, `selectedShapeRotation`, `selectedShapeBorderRadius`, `selectedStrokeColor`, `selectedStrokeWidth`, `selectedStrokeOpacity`, `selectedStrokeBrushType`, `isDrawingShape`, `shapeDrawStart`, `shapeDrawCurrent` |
| `CanvasHistoryState` | `isViewingHistory`, `historyPreview*`, `historyScrub*`, `isSelecting*Area`, `activityBlocks`, `hasMoreHistoryVersions`, `historyNextBeforeVersion`, `undoRequests`, `myUndoRequests`, `activeRevertPlan`, `isHistoryLoading`, `undoConflict`, `undoRequestDraft`, `selectedUserUid`, `userOps`, `hasMoreUserOps`, `userOpsNextBeforeVersion` |
| `CanvasCollaborationState` | `boardMembers`, `memberSearchQuery`, `comments`, `chatMessages`, `voiceParticipants`, `isVoiceCallActive`, `isMicMuted`, `isSpeakerOn`, `isChatDrawerOpen`, `isCommentsTrayOpen`, `activeCommentId`, `isPlacingComment` |
| `CanvasExportState` | `isExporting`, `exportSuccessMessage`, `lastExportedFilePath` |
| `CanvasUiState` | `activeTray`, `showTrayTips`, `isLoading`, `error`, `infoMessage`, `infoMessageUndoable`, `infoMessageRedoable`, `syncStatus`, `syncMessage`, `hasClipboard` |

### 5.5 `CanvasElement` models → files

The sealed base requires subclasses in the same library, so use `part` files:

```
models/
  canvas_element.dart              # sealed base, fromMap dispatch, common equality
  elements/
    stroke_element.dart
    shape_element.dart
    text_element.dart
    image_element.dart
    sticky_note_element.dart
    frame_element.dart
    table_element.dart             # TableElement + TableCellData
    layer_element.dart
    connector_element.dart
```

Keep `models/canvas_element.dart` as the library root and re-export nothing else. The existing `domain/models/canvas/canvas_element.dart` shim continues to point at it until Phase 6.

**Long-term:** move the library to `lib/domain/models/canvas/elements/` and leave the feature file as a re-export. This fixes the current inversion where domain services import feature models.

### 5.6 `canvas_element_geometry.dart` → files

Split by element family and by algorithm. Keep a barrel at the old path so no call site changes.

| Current lines | Target file | Contents |
|---:|---|---|
| 20–160 | `canvas_text_layout.dart` | `CanvasTextLayout`, text rect/layout helpers |
| 161–450 | `canvas_shape_geometry.dart` | Shape rect/path, polygon, dash, arrowheads, `paintShapeElement` |
| 451–518 | `canvas_bounds.dart` | `rotatePoint`, `rotatedRectBounds`, sampling helpers |
| 519–739 | `canvas_frame_geometry.dart` | Frame rect/contains/clip/host frame, background pattern, `paintFrameElement` |
| 740–830 | `canvas_bounds.dart` | `elementBounds` |
| 831–1111 | `canvas_connector_geometry.dart` | Distance, polyline, path, anchors, arrowheads, label box, `paintConnectorElement` |
| 1112–1271 | `canvas_connector_geometry.dart` | `ConnectorLabelBox` |
| 1272–1372 | `canvas_hit_test.dart` | `elementContains`, stroke hit, shape hit |
| 1373–1556 | `canvas_paint_order.dart` | `CanvasPaintBand`, `CanvasLayerPaintEffect`, `CanvasPaintOrder`, blend modes |
| 1557–1724 | `canvas_bounds.dart` | `elementsBounds`, connector anchor resolution |
| 1725–1896 | `canvas_image_geometry.dart` | Image rect, crop clamp/apply/source, color matrix, `paintImageElement` |
| 1897–2027 | `canvas_sticky_note_geometry.dart` | Sticky rect/tape/text layout, fit height, `paintStickyNoteElement` |
| 2028–2186 | `canvas_table_geometry.dart` | Table rect, column/row offsets, cell rect, `paintTableElement` |
| 2187–2302 | `canvas_symmetry.dart` | Symmetry mirrored copies/polylines, snap bounds |

The barrel:

```dart
// canvas_element_geometry.dart
export 'canvas_bounds.dart';
export 'canvas_connector_geometry.dart';
export 'canvas_frame_geometry.dart';
export 'canvas_hit_test.dart';
export 'canvas_image_geometry.dart';
export 'canvas_paint_order.dart';
export 'canvas_shape_geometry.dart';
export 'canvas_sticky_note_geometry.dart';
export 'canvas_symmetry.dart';
export 'canvas_table_geometry.dart';
export 'canvas_text_layout.dart';
```

Internal files import only the siblings they need. Avoid a cycle by keeping `canvas_bounds.dart` dependent only on element models and the per-family rect functions.

### 5.7 Painter and render model → files

**Step 1 (mechanical):** make the painter a standalone library, not a part of the screen.

```
view/painting/
  canvas_painter.dart              # CustomPainter orchestration + shouldRepaint
  canvas_render_element.dart       # CanvasRenderElement (formerly _CanvasElement)
  canvas_element_painters.dart     # per-element paint methods
  canvas_background_painter.dart   # board background, guides, symmetry, rulers
  canvas_overlay_painters.dart     # eraser, remote cursors, shape draw preview, area selection
  canvas_connector_preview_painter.dart
```

**Step 2 (semantic):** replace `_CanvasElement` with `CanvasRenderElement` that either:

- **Option A (lower risk):** wraps a `CanvasElement source` plus override fields (`center`, `size`, `rotation`, `opacity`, `layerBounds`, `pendingEdits`). Remove the duplicated `data` map. Paint methods use `source` and apply overrides explicitly.
- **Option B (cleaner):** have `_mapElements` return `List<CanvasElement>` with previews already applied via `CanvasElement.fromMap`/copy helpers. The painter switches on the sealed subclasses and calls shared paint functions directly. This removes the render model entirely but requires copy helpers for every element type.

Recommendation: **Option A first**, then evaluate Option B with a golden-test spike. Option A removes the per-frame `toMap` duplication and the painter's manual reconstruction without changing the public model.

**Step 3 (reuse):** create `rendering/canvas_element_renderer.dart` with a single `paintCanvasElement` switch used by:

- interactive painter,
- `BoardExportService` PNG rendering,
- history/revert preview,
- media editor preview.

SVG/PDF remain format-specific but can share geometry and text layout.

### 5.8 `BoardExportService` → files

```
domain/services/canvas/export/
  board_export_service.dart        # interface + impl orchestration (exportBoard/exportCanvas/share)
  board_export_paths.dart          # directory resolution, file naming, MIME
  board_png_renderer.dart          # element painting to PNG, image decoding
  board_pdf_exporter.dart          # PDF pages, text sanitization
  board_svg_exporter.dart          # SVG serialization by element type
  board_export_bounds.dart         # bounds, selection/frame/page presets
```

Keep `board_export_service.dart` at the current path as a barrel exporting the interface and implementation. Existing imports keep working.

### 5.9 Other large files → targets

| File | Lines | Target split |
|---|---:|---|
| `agora_chat_service.dart` | 3,637 | `agora_chat_gateway.dart` (interface + live SDK), `agora_chat_service_impl.dart` (orchestration), `agora_chat_login_manager.dart` (login/logout/session), `agora_chat_message_mapper.dart` (send/receive/convert), `agora_chat_conversation_sync.dart` (local/remote sync), `agora_chat_offline_queue.dart`, `agora_chat_presence.dart` |
| `chat_repository_impl.dart` | 1,734 | `chat_repository_impl.dart` (public contract), `chat_storage_keys.dart` (scoped key parsing), `chat_conversation_mapper.dart`, `chat_message_mapper.dart`, `chat_queries.dart` |
| `board_repository_impl.dart` | 1,714 | `board_repository_impl.dart`, `board_local_mapper.dart`, `board_sync_engine.dart` (start/stop/activate/bind), `board_preview_store.dart`, `board_crud.dart` |
| `canvas_sync_repository_impl.dart` | 1,587 | `canvas_sync_repository_impl.dart`, `canvas_socket_client.dart` (connect/handlers), `canvas_update_store.dart` (save/mark/sync), `canvas_cursor_store.dart`, `canvas_gap_recovery.dart`, `canvas_peer_updates.dart` |
| `board_settings_screen.dart` | 1,412 | `board_settings_screen.dart` (shell), `widgets/general_settings_section.dart`, `widgets/invite_section.dart`, `widgets/role_section.dart`, `widgets/member_list.dart`, `dialogs/board_settings_dialogs.dart` (rename, tag, delete, leave, duplicate, pause, archive), `board_settings_controller.dart` (form state + validation) |
| `workspace_bloc.dart` | 1,345 | `workspace_event.dart`, `workspace_state.dart`, `workspace_bloc.dart`, `handlers/workspace_load_handlers.dart`, `handlers/workspace_crud_handlers.dart`, `handlers/workspace_invite_handlers.dart`, `handlers/workspace_board_handlers.dart` |
| `history_screen.dart` | 1,305 | `history_screen.dart`, `history_filters.dart` (filter model + predicates), `widgets/history_filter_panel.dart`, `widgets/history_list.dart`, `widgets/history_rows.dart` (`_BlockRow`, `_UndoRequestRow`, `_Tag`, `_VersionMenu`), `dialogs/history_dialogs.dart` (`_DenyNoteDialog`, `_VersionInputDialog`), `widgets/rotating_refresh_button.dart` |
| `chat_bubble.dart` | 1,201 | `chat_bubble.dart` (content), `widgets/animated_message_bubble.dart`, `widgets/swipe_to_reply_wrapper.dart`, `widgets/chat_media.dart` (image/GIF/file/fallback), `widgets/chat_share_cards.dart`, `widgets/chat_bubble_actions.dart` (reactions, context menu, edit dialog), `chat_bubble_formatters.dart` |
| `notifications_screen.dart` | 1,189 | `notifications_screen.dart`, `notifications_filter_bar.dart`, `widgets/notification_tile.dart`, `widgets/invitation_action_buttons.dart`, `notifications_actions.dart` (four decision flows), `notifications_formatters.dart` |
| `workspace_repository_impl.dart` | 1,164 | `workspace_repository_impl.dart`, `workspace_sync_streams.dart`, `workspace_invite_store.dart`, `workspace_member_store.dart`, `workspace_mapper.dart` |
| `revert_review_sheet.dart` | 1,017 | `revert_review_sheet.dart`, `widgets/revert_review_cards.dart`, `widgets/revert_element_preview.dart` (use shared renderer), `widgets/revert_decision_controls.dart` |
| `friends_repository_impl.dart` | 989 | `friends_repository_impl.dart`, `friend_request_mapper.dart`, `friend_sync.dart`, `blocked_user_store.dart` |
| `settings_screen.dart` | 927 | `settings_screen.dart`, `widgets/settings_sections.dart`, `widgets/settings_tiles.dart`, `dialogs/settings_dialogs.dart` |
| `board_template.dart` | 918 | `templates/template_element_builders.dart`, `templates/basic_templates.dart`, `templates/planning_templates.dart`, `templates/creative_templates.dart`, `board_template.dart` (model + registry) |
| `brush_tray.dart` | 904 | `brush_tray.dart`, `widgets/brush_preset_grid.dart`, `widgets/brush_preview.dart`, `widgets/brush_size_controls.dart` |
| `layers_tray.dart` | 880 | `layers_tray.dart`, `widgets/layer_row.dart`, `widgets/layer_controls.dart`, `widgets/layer_blend_menu.dart` |
| `profile_screen.dart` | 842 | `profile_screen.dart`, `widgets/profile_header.dart`, `widgets/profile_stats.dart`, `widgets/profile_boards.dart` |
| `color_picker_sheet.dart` | 836 | `color_picker_sheet.dart`, `widgets/color_wheel.dart`, `widgets/color_sliders.dart`, `widgets/palette_editor.dart` |

These are lower priority than the canvas and should be handled as a parallel track after Phase 3.

---

## 6. Reuse plan

### 6.1 Shared render pipeline

**Problem:** the same element is painted by at least five code paths with slightly different logic.

**Target:**

```
features/canvas/rendering/
  canvas_element_renderer.dart   // paintCanvasElement(canvas, element, context)
  canvas_stroke_renderer.dart    // paintCanvasStroke + resampling
  canvas_background_renderer.dart
  canvas_render_context.dart     // decoded images, viewport, opacity overrides
```

`CanvasRenderContext` carries only rendering inputs:

```dart
class CanvasRenderContext {
  final Map<String, ui.Image> decodedImages;
  final Map<String, CanvasLayerPaintEffect> layerEffects;
  final double viewportScale;
  final bool showSelectionChrome;
  // no CanvasState, no BuildContext
}
```

Callers:

| Caller | Uses |
|---|---|
| Interactive painter | `paintCanvasElement` + overlay renderers |
| `BoardExportService` PNG | `paintCanvasElement` with a null/export context |
| History/revert preview | `paintCanvasElement` with a simplified context |
| Media editor | `paintImageElement` (already shared) |
| Sticky note editor | `paintStickyNoteElement` (already shared) |
| Brush tray preview | `paintCanvasStroke` (already shared) |

**Outcome:** adding a new element type adds one renderer case, and every surface gets it.

### 6.2 Shared geometry

The split in §5.6 makes each element family a small library. Reuse follows automatically:

- `elementBounds` and `elementsBounds` used by selection, export, minimap, history focus, and eraser.
- `canvasPaintOrder` used by painter, `_mapElements`, export, and layer tray.
- `elementContains` used by hit testing, selection, eraser, and undo-request picking.
- Connector geometry used by painter, export SVG, hit testing, and labels.

### 6.3 Panel kit

The selected element panels (shape 495 lines, connector 395, image 300, text 184, stroke 170) duplicate the same visual vocabulary. Extract:

```
panels/panel_controls.dart
  CanvasPanelShell          // header, close, scroll, padding
  CanvasPanelSection        // label + child
  CanvasPanelSlider         // label, value, min/max, onChanged, onChangeEnd
  CanvasPanelColorRow       // swatches, selected, onPick, add button
  CanvasPanelChipRow       // segmented chips
  CanvasPanelActionTile     // icon + label + onTap
  CanvasPanelDivider
```

Then each panel becomes a ~150–250 line widget composed from these controls. This is the biggest visual-code reuse win.

### 6.4 Controllers

Extract these from `_CanvasScreenState` in Phase 4:

| Controller | Owns | Consumers |
|---|---|---|
| `CanvasViewportController` | `scale`, `offset`, gesture start values, pinch intent, zoom, pan, fit, auto-frame, `toWorld`, `toScreen` | Ink layer, overlays, minimap, zoom controls |
| `CanvasTextEditingController` | Draft, focus node, controller, begin/commit/cancel, font size/rotation drafts | Text overlay, text panel, keyboard handling |
| `CanvasAiImageController` | `AiImageBloc` subscription, enabled flag, aspect ratio, completion/failure sequence, recent images | AI tray, action bar, image panel |
| `CanvasImagePipeline` | Pick/upload, dimension reading, decoded `ui.Image` cache, pending decodes | Canvas layer, image panel, preview |
| `CanvasPreviewController` | Preview save, blank board render, pixel ratio, in-flight save | Lifecycle, exit, app pause |
| `CanvasHistoryCoordinator` | History open/restore/scrub/undo-request flow (screen side) | History actions, banner, undo request sheet |
| `CanvasSelectionGestureController` | Marquee, lasso, group drag, shape drag/resize/rotate, edge auto-pan | Ink layer, selection overlays |

Use `ChangeNotifier` or `ValueNotifier` for viewport and text drafts. Wrap the ink layer and overlays in `ListenableBuilder` so pointer moves do not rebuild the entire 12k-line widget. This is a performance win as well as a size win.

### 6.5 Event and state barrels

- `bloc/canvas_event.dart` becomes a barrel; all 186 events remain importable from the old path.
- `bloc/canvas_bloc.dart` exports the event barrel and `canvas_state.dart`, preserving the current public surface.
- `geometry/canvas_element_geometry.dart` becomes a barrel; `domain/services/canvas/canvas_geometry.dart` continues to re-export it.
- `models/canvas_element.dart` remains the library root for the sealed model.

This keeps the blast radius of each split small and avoids a mass import rewrite.

### 6.6 New element type recipe

After the refactor, adding an element type should follow a documented checklist:

1. **Model:** add a subclass in `domain/models/canvas/elements/<type>_element.dart`, update `CanvasElement.fromMap` and the sealed switch.
2. **Geometry:** add `<type>_geometry.dart` with rect, path, hit test, and paint.
3. **Rendering:** add one case to `paintCanvasElement`.
4. **Events:** add `<type>_events.dart` and export it from the barrel.
5. **Bloc:** add `<type>_handlers.dart` mixin and register the events in `canvas_bloc.dart`.
6. **Panel:** add `selected_<type>_panel.dart` using `panel_controls.dart`.
7. **Export:** add SVG/PDF serialization if the format needs vector output; PNG comes free from the renderer.
8. **Tests:** model round-trip, geometry bounds/hit, renderer golden, bloc handler, panel widget.

Put this checklist in `docs/refactoring/adding-canvas-element.md` and link it from `lib/README.md`.

---

## 7. Phased roadmap

Each phase is independently shippable. A PR should be one cluster, move-only where possible, and green on guardrails + analyze + tests.

### Phase 0 — Baseline and guardrails (1 PR, S)

**Deliverables:**

1. Add `tool/file_size_guardrails.dart` and `tool/file_size_budget.yaml`.
   - Default max: 600 lines for new files.
   - Allowlist current offenders with their current line counts.
   - Fail if any file exceeds its budget; budgets may only decrease.
2. Extend `tool/architecture_guardrails.dart`:
   - Detect `part of '…'` and apply the owning file's layer rules.
   - Apply bloc rules to every file under `lib/features/**/bloc/`, not only `*_bloc.dart`.
   - Apply screen rules to parts of `*_screen.dart`.
3. Add the budget check to `.github/workflows/architecture-guardrails.yml`.
4. Record baseline metrics in `docs/refactoring/baseline.md` (file sizes, test count, performance test result).
5. Add `docs/refactoring/adding-canvas-element.md`.

**Exit criteria:** CI fails on a new 700-line file; existing offenders pass; `flutter test` green.

### Phase 1 — Pure modules (6 PRs, M)

Move-only splits with no behavior change.

| PR | Work | Target |
|---|---|---|
| 1.1 | Split `canvas_element.dart` into sealed base + `elements/*.dart` parts | Base ≤ 350; each subclass ≤ 400 |
| 1.2 | Split `canvas_element_geometry.dart` into 10 libraries + barrel | Barrel ≤ 80; each file ≤ 450 |
| 1.3 | Split `canvas_event.dart` into event libraries + barrel | Each file ≤ 400 |
| 1.4 | Make `canvas_painter.dart` a standalone library; split render model, element painters, background, overlays | Each file ≤ 500 |
| 1.5 | Split `board_export_service.dart` into orchestration, PNG, PDF, SVG, paths, bounds | Each file ≤ 500 |
| 1.6 | Split `board_template.dart` into builders + category template files | Each file ≤ 400 |

**Exit criteria:** all imports still work through barrels; `canvas_painter.dart` can be imported by a test; `flutter test test/features/canvas` green.

### Phase 2 — CanvasBloc handler mixins (4 PRs, M)

| PR | Work | Result |
|---|---|---|
| 2.1 | Create handler part files and move board, sync/CRDT, and helper methods | `canvas_bloc.dart` ~4,000 |
| 2.2 | Move stroke, tool, shape, text, image, sticky note handlers | `canvas_bloc.dart` ~2,500 |
| 2.3 | Move structure, selection, layer, undo, clipboard handlers | `canvas_bloc.dart` ~1,500 |
| 2.4 | Move history, undo request, communication handlers; split state parts | `canvas_bloc.dart` ≤ 600 |

**Rules:**

- Move methods verbatim; no renames, no logic edits.
- Keep all `on<…>` registrations in `canvas_bloc.dart`.
- Keep event/state public API unchanged.
- Run the focused bloc tests after each move:
  `flutter test test/features/canvas/bloc`.

**Exit criteria:** `canvas_bloc.dart` ≤ 600; no handler file > 900; all 457 canvas tests green.

### Phase 3 — CanvasScreen parts (4 PRs, M)

| PR | Work | Result |
|---|---|---|
| 3.1 | Move `build()` and layer composition into `screen/canvas_screen_build.dart`; move viewport, gestures, and selection methods | Screen ~7,000 |
| 3.2 | Move shape editing, AI image, image pipeline, and preview methods | Screen ~4,000 |
| 3.3 | Move dialogs and sheets to standalone libraries | Screen ~2,500 |
| 3.4 | Move panels, overlays, status banners, top bar, edge triggers, comments | Screen ≤ 800 |

**Rules:**

- Use extensions for methods that need private fields.
- Keep `build()` in the State class, delegating to `_buildCanvasScreen(context)`.
- Extract sheets/dialogs directly as standalone widgets when their inputs are already explicit.
- No widget tree changes in this phase; only moves.

**Exit criteria:** `canvas_screen.dart` ≤ 800; no screen part > 900; widget tests green.

### Phase 4 — Extract reusable widgets and controllers (6 PRs, L)

| PR | Work | Reuse |
|---|---|---|
| 4.1 | `CanvasViewportController` + `ListenableBuilder` in ink layer/overlays | Minimap, zoom controls, all overlays; performance |
| 4.2 | `CanvasTextEditingController` + `TextEditorOverlay` widget | Text panel, keyboard tests |
| 4.3 | `CanvasAiImageController` + AI action bar widget | AI tray, image panel |
| 4.4 | `CanvasImagePipeline` + decoded image cache | Painter, image panel, preview |
| 4.5 | `CanvasPreviewController` + `CanvasHistoryCoordinator` | Exit/pause, history banner, undo request sheet |
| 4.6 | `panel_controls.dart` + convert selected panels to composed widgets | Shape, connector, image, text, stroke panels |

**Exit criteria:** extracted widgets have explicit constructors (no `CanvasState`/`CanvasBloc` where avoidable); widget tests cover each panel; viewport changes do not rebuild the whole screen.

### Phase 5 — Other large files (parallel track, 6+ PRs, M/L)

Order by risk and reuse:

1. `board_export_service.dart` follow-up (if not done in 1.5).
2. `history_screen.dart` (shares history models with canvas).
3. `board_settings_screen.dart`.
4. `chat_bubble.dart`.
5. `notifications_screen.dart`.
6. `agora_chat_service.dart` (largest, most delicate).
7. Repositories: chat, board, canvas sync, workspace.
8. `workspace_bloc.dart`.
9. Trays: brush, layers, color picker, revert sheet.
10. Templates and remaining >800 files.

### Phase 6 — Optional semantic redesign (3 PRs, L)

Only after Phases 1–4 are stable.

1. **Render model:** replace `_CanvasElement`/`CanvasRenderElement` with domain elements + preview overrides; add golden tests.
2. **State composition:** split `CanvasState` into sub-states with backward-compatible getters.
3. **Domain relocation:** move pure canvas models, geometry, and rendering into `lib/domain/models/canvas/` and `lib/domain/services/canvas/`; leave feature barrels. Update domain services to import domain paths.

### Phase 7 — Ratchet the budget (1 PR, S)

Lower `tool/file_size_budget.yaml`:

- Phase 1–2: max 1,200 for canvas files.
- Phase 3: max 900.
- Phase 4: max 800; default 600 for new files.
- Phase 6: max 600 for canvas; default 500.

Remove allowlist entries as files fall below budget.

---

## 8. Guardrails and CI

### 8.1 Architecture guardrails for parts

Add to `tool/architecture_guardrails.dart`:

```dart
// Resolve the owning library for part files.
String _owningLibraryPath(String path, String source) {
  final match = RegExp(r"part of ['\"](.+?)['\"]").firstMatch(source);
  if (match == null) return path;
  final relative = match.group(1)!;
  return normalize(join(dirname(path), relative));
}
```

Then run the existing checks against both `path` and `_owningLibraryPath(path, source)`. This prevents a part file from bypassing bloc/screen/repository rules.

Also add:

- `_checkBlocParts`: any file under `lib/features/**/bloc/` must not import repositories or core database services.
- `_checkScreenParts`: any part of a `*_screen.dart` must not import services/repositories.
- `_checkViewWidgets`: extracted widgets under `view/` must not import repositories or core database services. Allow route files as the composition boundary.

### 8.2 File size budget

`tool/file_size_guardrails.dart`:

```dart
// Pseudo-code
final budgets = loadYaml('tool/file_size_budget.yaml');
for (final file in dartFilesUnder('lib')) {
  final lines = file.readAsLinesSync().length;
  final budget = budgets[relativePath] ?? budgets.defaultMax;
  if (lines > budget) {
    violations.add('$relativePath has $lines lines (budget $budget)');
  }
}
```

`tool/file_size_budget.yaml`:

```yaml
default_max: 600
budgets:
  lib/features/canvas/view/canvas_screen.dart: 12827
  lib/features/canvas/bloc/canvas_bloc.dart: 9800
  lib/domain/services/chat/agora_chat_service.dart: 3637
  # ...
```

CI:

```yaml
- name: Run file size guardrails
  run: dart run tool/file_size_guardrails.dart
```

### 8.3 Verification commands

Run for every refactor PR:

```bash
dart run tool/architecture_guardrails.dart
dart run tool/file_size_guardrails.dart
flutter analyze
flutter test
```

Focused runs:

```bash
flutter test test/features/canvas
flutter test test/features/canvas/bloc
flutter test test/features/canvas/geometry
flutter test test/performance/canvas_performance_test.dart
```

### 8.4 Manual smoke matrix

Run before merging any PR that changes widget composition or rendering:

| Area | Checks |
|---|---|
| Drawing | Finger/stylus draw, pressure, tilt, brush presets, quick shape, stabilizer |
| Erasing | Object eraser, pixel eraser, remote eraser cursor |
| Selection | Tap, double-tap, marquee, lasso, additive, group drag, align, arrange |
| Transform | Single shape move/resize/rotate, group scale/rotate, snapping, edge auto-pan |
| Text | Add, edit, style, commit/cancel, keyboard dismissal |
| Elements | Frame draw/enter/exit, table edit/style, connector draw/rewire, sticky note |
| Layers | Add/rename/delete/reorder, visibility, lock, opacity, blend mode |
| Undo/redo | Single, batch, conflict dialog, redo |
| History | Open, preview, scrub, compare, restore, evidence, user timeline |
| Undo request | Draft scope, area selection, preview, submit, owner review |
| Collaboration | Two clients draw, previews, members, comments, chat, voice |
| AI | Generate, edit, repaint, regenerate, recent images |
| Export | PNG, PDF, SVG, selection, frame, page presets, share |
| Offline | Airplane mode, reconnect, gap recovery, pending updates |
| Performance | 4k–6k elements, pan/zoom, draw, frame timing |

---

## 9. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Behavior drift during moves | Medium | High | Move-only PRs, no logic edits, focused tests, `git diff --color-moved` |
| Merge conflicts from large moves | High | Medium | One cluster per PR, announce in-flight files, merge quickly |
| Private-state access blocks extraction | High | Medium | Use parts/mixins first; extract controllers with explicit contracts later |
| Rebuild/performance regression | Medium | High | Viewport controller + `ListenableBuilder`; measure before/after with DevTools and performance test |
| CRDT/history subtlety | Medium | High | Keep logic untouched in Phase 2; add characterization tests before Phase 6 |
| Part files bypass guardrails | High | Medium | Extend guardrails in Phase 0 |
| Import cycles after split | Medium | Medium | Dependency rule; pure modules at the bottom; barrel exports |
| Line-number drift | High | Low | Use method names and inventories, not line numbers |
| Test churn from event/state splits | Medium | Medium | Keep barrels and exports; don't rename public classes |
| Over-extraction into tiny files | Medium | Low | Split by responsibility; 150–500 lines is the target, not 20-line files |
| `part` files hide imports | Medium | Low | Accept short-term; convert reusable code to libraries by Phase 4 |

**Do not do:**

- Do not split by arbitrary line count (`canvas_screen_part1.dart`).
- Do not create a `canvas_utils.dart` dumping ground.
- Do not change state management libraries or add code generation as part of this work.
- Do not rewrite the CRDT/history logic while moving it.
- Do not move models to domain in the same PR as a screen split.
- Do not use `part` for reusable widgets.

---

## 10. Definition of done

### Size targets

| File | Baseline | Target |
|---|---:|---:|
| `canvas_screen.dart` | 12,827 | ≤ 800 |
| `canvas_bloc.dart` | 9,800 | ≤ 600 |
| `canvas_event.dart` | 1,831 | ≤ 150 (barrel) + files ≤ 400 |
| `canvas_element.dart` | 1,851 | ≤ 350 + files ≤ 400 |
| `canvas_element_geometry.dart` | 2,303 | ≤ 80 (barrel) + files ≤ 450 |
| `canvas_painter.dart` | 1,692 | ≤ 400 + files ≤ 500 |
| `board_export_service.dart` | 1,972 | ≤ 400 + files ≤ 500 |
| Any new non-generated file | — | ≤ 600 |
| Any refactored canvas file | — | ≤ 900 until Phase 4, then ≤ 800 |

### Quality targets

- All existing tests pass; no reduction in canvas test count.
- New tests for extracted pure modules (geometry, renderer, mappers).
- Widget tests for extracted panels and overlays.
- Architecture guardrails cover part files and pass.
- File-size guardrails pass and are ratcheted down.
- No public event/state/model names removed without a deprecation path.
- The new-element recipe is documented and validated by adding a trivial element type in a spike branch.
- Performance: `canvas_performance_test.dart` stays green; viewport pan/zoom frame time is equal or better.

### Review targets

- Every refactor PR is move-only or has a clear semantic change described in the title.
- Each PR touches one cluster and is reviewable in under 30 minutes.
- `git diff --color-moved` shows mostly moves for Phase 1–3.
- No unrelated formatting changes.

---

## Appendix A: CanvasScreen method inventory

Grouped by destination. Use this as the checklist when moving code.

**Lifecycle and preferences**
`initState`, `didUpdateWidget`, `didChangeAppLifecycleState`, `_maybeApplyInitialTemplate`, `_loadCanvasPreferences`, `_dismissTemplateCoachmark`, `_loadColorPreferences`, `_setBrushColor`, `_applyPickedBrushColor`, `_persistRecentColors`, `_updatePalettes`, `_persistPalettes`, `_openColorPicker`, `_toggleEyedropper`, `_maybeShowTrayTipsOverlay`, `_openTray`, `_toggleTray`.

**History and undo requests**
`_openHistoryScreen`, `_restoreHistoryVersion`, `_onScrubSliderChanged`, `_restoreScrubState`, `_undoUserAfterScrub`, `_restoreScrubStateInRequest`, `_openUndoRequestSendSheet`, `_revertPreviewOps`, `_memberDisplayName`, `_openUndoRequestSheet`, `_scopeSheetElements`, `_completeAreaSelection`, `_maybeFocusHistoryPreview`.

**Pointer, viewport, selection primitives**
`_toWorld`, `_toScreen`, `_isArrowMode`, `_capturePointerPressure`, `_isBrushTool`, `_isStylusKind`, `_handleCanvasPointerDown`, `_handleCanvasPointerMove`, `_handleCanvasPointerEnd`, `_cancelRawStroke`, `_endRawStroke`, `_beginPointerTransform`, `_startStroke`, `_appendStroke`, `_endStroke`, `_getElementWorldCenter`, `_strokeCenter`, `_centerViewportOn`, `_selectShape`, `_moveSelectedShape`, `_resizeSelectedShape`, `_deferredSetSelectedShapeProperty`, `_shapeLabelController`, `_deferredResizeSelectedShape`, `_setSelectedShapeColor`, `_pickShapeFillColor`, `_rotateSelectedShape`, `_deferredRotateSelectedShape`, `_deferredSetSelectedShapeBorderRadius`, `_scheduleShapeEditCommit`, `_commitPendingShapeEdits`, `_setEraserScope`, `_setShapeEditing`, `_globalToCanvasLocal`, `_updateEdgeAutoPan`, `_stopEdgeAutoPan`, `_tickEdgeAutoPan`, `_selectShapeForDrawing`, `_areaSelectionRect`.

**AI and images**
`_addAiTextElement`, `_onGenerateImagePlaceholder`, `_canUseAi`, `_generateAiImage`, `_onAiImageState`, `_recordRecentAiImage`, `_collectRecentAiImages`, `_selectedAiImage`, `_editSelectedImageWithAi`, `_repaintSelectedImageArea`, `_regenerateSelectedImage`, `_buildAiImageOverlays`, `_buildAiImageActionBar`, `_uploadImageToCanvas`, `_readImageSize`, `_syncDecodedUiImages`, `_decodeUiImage`.

**Viewport**
`_isAtTransform`, `_applyViewportTransform`, `_centerOffsetForScale`, `_resetViewToDefaultScale`, `_toggleResetView`, `_maybeAutoFrameCanvas`, `_fitCanvasToContent`, `_computeContentBounds`, `_undo`, `_redo`, `_clearAll`, `_viewportWorldCenter`, `_snapElementCenterDrag`, `_snapGroupDragDelta`, `_frameDragHighlightedIds`, `_handleViewportPointerSignal`, `_zoomAt`, `_zoomFromCenter`, `_zoomButton`, `_buildMinimap`, `_buildUndoRedoControls`, `_buildZoomControls`.

**Dialogs and sheets**
`_confirmDeleteFrame`, `_editFrameTitleDialog`, `_addTableDialog`, `_editTableCellDialog`, `_showCanvasContextMenu`, `_addStickyNoteDialog`, `_editStickyNote`, `_addConnectorDialog`, `_showTemplateGallerySheet`, `_showCanvasSettingsSheet`, `_showSymmetrySheet`, `_showExportOptionsSheet`, `_runExport`, `_shareAnchorRect`, `_buildExportTile`, `_showRequestEditDialog`, `_promptNewCommentDialog`.

**Preview and navigation**
`_savePreview`, `_previewPixelRatio`, `_renderBlankBoardPreviewPng`, `_performSavePreview`, `_exitCanvas`, `_openSettings`.

**Build and mapping**
`build`, `_mapElements`, `_hitTestConnectableShapeId`, `_fillTopmostAt`, `_hitTestShape`, `_groupPreviewElement`, `_selectionWorldBounds`, `_buildGroupTransformOverlay`, `_buildGroupScaleHandles`, `_buildGroupRotateHandle`, `_startGroupScale`, `_updateGroupScale`, `_endGroupScale`, `_worldToGlobal`, `_startGroupRotate`, `_updateGroupRotate`, `_endGroupRotate`.

**Panels and overlays**
`_syncEditingBarSelection`, `_showsElementEditingBar`, `_buildElementEditingBar`, `_elementEditorLabel`, `_fillSwatch`, `_elementEditAction`, `_elementEditPanel`, `_elementEditControlBody`, `_elementEditSlider`, `_applyElementColor`, `_buildSelectedElementPanel`, `_buildSelectionOutline`, `_buildMultiSelectionOutline`, `_buildSelectedFramePanel`, `_buildStickyNoteEditBanner`, `_buildConnectorSelectionOverlay`, `_beginConnectorRewire`, `_updateConnectorRewire`, `_finishConnectorRewire`, `_cancelConnectorRewire`, `_hitTestConnectorTarget`, `_elementLinkBounds`, `_startFrameDraw`, `_buildCanvasToolbar`, `_buildShapesPickerPopup`, `_openBottomBarCustomizer`, `_executeToolbarActionLongPress`, `_executeToolbarAction`, `_polygonBounds`, `_buildLassoOverlay`, `_buildSelectionModeToggle`, `_buildMarqueeOverlay`, `_buildMultiSelectBar`, `_openSelectionStyleSheet`, `_onToolbarToolSelected`.

**Text, stroke, shape, connector, image panels**
`_beginTextEditing`, `_commitTextEditing`, `_buildTextEditorOverlay`, `_buildSelectedTextPanel`, `_buildTextEditBanner`, `_buildStrokeSelectionOverlay`, `_buildStrokeEditBanner`, `_buildSelectedStrokePanel`, `_buildSectionLabel`, `_buildSelectedShapePanel`, `_shapeFillColorRow`, `_shapePanelSlider`, `_dashIndexFor`, `_dashPatternFor`, `_dashChip`, `_labelAlignChip`, `_buildShapeEditBanner`, `_buildSelectedConnectorPanel`, `_openImageCrop`, `_buildSelectedImagePanel`, `_getShapeCenterGlobal`, `_buildShapeTransformOverlay`, `_buildHandle`.

**Status, top bar, edge UI, comments**
`_buildHistoryPlanListener`, `_buildUndoConflictListener`, `_buildAllTrays`, `_buildSyncIndicator`, `_buildArchivedBanner`, `_buildPausedBanner`, `_buildPendingUndoRequestsBanner`, `_buildReadOnlyStatusBanner`, `_buildStatusBadge`, `_buildTopPills`, `_menuRow`, `_buildMemberAvatarStack`, `_buildGlassEdgeTab`, `_buildEdgeTriggers`, `_isPickingUndoRequestScope`, `_buildUndoRequestPickHint`, `_buildUndoRequestPendingNotice`, `_buildAreaSelectionHint`, `_buildPinnedCommentPins`, `dispose`.

---

## Appendix B: CanvasBloc handler inventory

Registration groups (all currently in the constructor):

1. Board and sync: rename, title, unavailable, initialize CRDT, apply remote update/preview.
2. Stroke: start, append, end, cancel, finger drawing, quick shape, commit quick shape.
3. Element creation: shape, AI text, text, image, AI image, image source, image preview, image update/style/replace, sticky note, frame, table, connector, import.
4. Element update: text, sticky note, frame, table cell/style, connector, rewire, board settings, guides.
5. Undo/redo: undo, redo, clear all, delete element, delete elements, duplicate, copy, paste.
6. Tools: color, width, opacity, brush type, preset, stylus, stabilizer, eraser scope, tool mode.
7. Shape drawing: start, update, end, cancel.
8. Selection: select shape, select elements, rect, lasso, mode, translate, scale, rotate, align, arrange.
9. Element meta: visibility, lock, opacity, reorder, move to layer, reorder layer, blend mode, add/rename/delete/active layer.
10. Selected shape: preview move/resize/rotate, move, resize, rotate, fill, fill color, color, stroke color, flip, radius, stroke width/opacity/dash, label, arrowheads, commit pending, preview pending.
11. Selected stroke: move, fill, clear fill, selection style, move to layer, retry sync, color/width/opacity/brush, commit.
12. Members and board: members updated, search, remove, role, save preview, set paused, export, consume messages, request edit.
13. History: feed, load older, feed updated, live tail, preview, exit, evidence, restore, revert user, review request, user ops, user timeline exit, version scrub, user scrub, scrub moved, load older, compare, revert ops, plan loaded/failed/dismissed, apply revert, undo own, area selection toggles, area scrub.
14. Undo requests: updated, my updated, conflict dismissed, draft started/scope/element/area/cleared, preview, submit, revert ops after request.
15. Communication: comments updated, chat updated/received, voice participants/call/mute/speaker, chat drawer, comments tray, comment placement, active comment, add comment/reply/delete, send chat, join/leave call, toggle mute/speaker, speaking changed.

---

## Appendix C: first-PR checklist

Use this for every refactor PR.

**Before coding**

- [ ] Read the cluster's methods and tests.
- [ ] Confirm no one else is editing the same files (announce the move).
- [ ] Identify the barrel/compatibility path.
- [ ] Decide `part` vs. library (see §4.4).

**During the move**

- [ ] Move code verbatim; no renames or logic edits.
- [ ] Keep public class names and constructors unchanged.
- [ ] Keep `on<…>` registrations in `canvas_bloc.dart`.
- [ ] Keep `build()` in the State class.
- [ ] Update imports only where necessary.
- [ ] Run `dart format` on touched files.

**Verification**

- [ ] `dart run tool/architecture_guardrails.dart`
- [ ] `dart run tool/file_size_guardrails.dart`
- [ ] `flutter analyze`
- [ ] `flutter test test/features/canvas`
- [ ] `flutter test test/performance/canvas_performance_test.dart` (if rendering/viewport touched)
- [ ] `git diff --color-moved` confirms the move
- [ ] Line budget updated (lowered) if the file shrank

**PR description**

- [ ] State "move-only" or describe the semantic change.
- [ ] List the new files and the old line ranges.
- [ ] Note any public API changes (should be none).
- [ ] Include test commands and results.
- [ ] Include before/after line counts.
