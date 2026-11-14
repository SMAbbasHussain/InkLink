// server/src/history/describe.js
// Turns a raw per-element CRDT diff into plain English so the owner's log reads
// as sentences ("Moved the blue rectangle 120 px right") instead of opaque ids.
//
// Pure module: no I/O, no imports. `describeOps` (which needs a replay) lives in
// revert.js so this file stays trivially testable.

const SHAPE_WORDS = {
  square: 'square',
  rectangle: 'rectangle',
  circle: 'circle',
  ellipse: 'ellipse',
  triangle: 'triangle',
  diamond: 'diamond',
  star: 'star',
  pentagon: 'pentagon',
  hexagon: 'hexagon',
  line: 'line',
  semicircle: 'semicircle',
  arrow: 'arrow',
};

const BRUSH_WORDS = {
  solid: 'solid',
  dashed: 'dashed',
  dotted: 'dotted',
  marker: 'marker',
  highlighter: 'highlighter',
  calligraphy: 'calligraphy',
  spray: 'spray',
  neon: 'neon',
  eraser: 'eraser',
};

function clamp01(n) {
  return Math.min(1, Math.max(0, n));
}

function rgbToHsl(r, g, b) {
  const rn = r / 255;
  const gn = g / 255;
  const bn = b / 255;
  const max = Math.max(rn, gn, bn);
  const min = Math.min(rn, gn, bn);
  const l = (max + min) / 2;
  const d = max - min;
  if (d === 0) return { h: 0, s: 0, l };
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h;
  if (max === rn) h = ((gn - bn) / d + (gn < bn ? 6 : 0)) * 60;
  else if (max === gn) h = ((bn - rn) / d + 2) * 60;
  else h = ((rn - gn) / d + 4) * 60;
  return { h, s, l };
}

/// Human name for a Flutter `Color.value` (ARGB packed int).
function colorName(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 'coloured';
  const packed = value >>> 0;
  const a = (packed >>> 24) & 0xff;
  if (a < 16) return 'transparent';
  const r = (packed >>> 16) & 0xff;
  const g = (packed >>> 8) & 0xff;
  const b = packed & 0xff;
  const { h, s, l } = rgbToHsl(r, g, b);

  if (s < 0.1) {
    if (l > 0.93) return 'white';
    if (l < 0.12) return 'black';
    if (l > 0.7) return 'light grey';
    if (l < 0.35) return 'dark grey';
    return 'grey';
  }
  if (h >= 15 && h < 45 && l < 0.42) return 'brown';
  if ((h < 15 || h >= 345) && l < 0.32) return 'dark red';
  if (h < 15 || h >= 345) return l > 0.75 ? 'light red' : 'red';
  if (h < 45) return l > 0.7 ? 'peach' : 'orange';
  if (h < 70) return l > 0.7 ? 'pale yellow' : 'yellow';
  if (h < 150) return l > 0.7 ? 'light green' : (l < 0.3 ? 'dark green' : 'green');
  if (h < 195) return l > 0.7 ? 'light teal' : 'teal';
  if (h < 250) return l > 0.7 ? 'light blue' : (l < 0.3 ? 'navy' : 'blue');
  if (h < 290) return l > 0.7 ? 'lavender' : 'purple';
  return l > 0.7 ? 'pink' : 'magenta';
}

function num(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.round(n);
}

function px(value) {
  const n = num(value);
  return n == null ? null : `${n} px`;
}

function capitalize(text) {
  if (!text) return text;
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function truncate(text, max = 40) {
  const s = String(text ?? '');
  const flat = s.replace(/\s+/g, ' ').trim();
  if (flat.length <= max) return flat;
  return `${flat.slice(0, max - 1)}…`;
}

function quoted(text) {
  const flat = truncate(text);
  return flat.length ? `“${flat}”` : 'empty text';
}

/// Short noun phrase identifying an element without exposing its id.
function elementNoun(el) {
  if (!el || typeof el !== 'object') return 'element';
  switch (el.type) {
    case 'stroke': {
      const brush = BRUSH_WORDS[el.brushType] || 'solid';
      return `${colorName(el.color)} ${brush} stroke`;
    }
    case 'shape':
      return `${colorName(el.color)} ${SHAPE_WORDS[el.shapeType] || 'shape'}`;
    case 'text':
      return el.text ? `text ${quoted(el.text)}` : 'text note';
    case 'image':
      return 'image';
    case 'sticky_note':
      return `${colorName(el.color)} sticky note`;
    case 'connector':
      return `${colorName(el.color)} connector`;
    default:
      return 'element';
  }
}

/// World-space centre used for movement descriptions.
function centerOf(el) {
  if (!el || typeof el !== 'object') return null;
  if (el.type === 'stroke') {
    const pts = Array.isArray(el.points) ? el.points : [];
    if (!pts.length) return null;
    let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
    for (const p of pts) {
      const x = Number(p?.x); const y = Number(p?.y);
      if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
      minX = Math.min(minX, x); minY = Math.min(minY, y);
      maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
    }
    if (!Number.isFinite(minX)) return null;
    return { x: (minX + maxX) / 2, y: (minY + maxY) / 2 };
  }
  if (el.type === 'connector') {
    const sx = Number(el.sx); const sy = Number(el.sy);
    const ex = Number(el.ex); const ey = Number(el.ey);
    if (![sx, sy, ex, ey].every(Number.isFinite)) return null;
    return { x: (sx + ex) / 2, y: (sy + ey) / 2 };
  }
  const x = Number(el.cx); const y = Number(el.cy);
  if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
  return { x, y };
}

function sizeOf(el) {
  if (!el || typeof el !== 'object') return null;
  if (el.type === 'shape') {
    const s = num(el.size);
    return s == null ? null : { w: s, h: s, scalar: true };
  }
  if (el.type === 'stroke') {
    const pts = Array.isArray(el.points) ? el.points : [];
    if (!pts.length) return null;
    let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
    for (const p of pts) {
      const x = Number(p?.x); const y = Number(p?.y);
      if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
      minX = Math.min(minX, x); minY = Math.min(minY, y);
      maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
    }
    if (!Number.isFinite(minX)) return null;
    return { w: Math.round(maxX - minX), h: Math.round(maxY - minY), scalar: false };
  }
  const w = num(el.width);
  const h = num(el.height);
  if (w == null && h == null) return null;
  return { w: w ?? 0, h: h ?? 0, scalar: false };
}

function movementPhrase(before, after) {
  const a = centerOf(before);
  const b = centerOf(after);
  if (!a || !b) return null;
  const dx = Math.round(b.x - a.x);
  const dy = Math.round(b.y - a.y);
  if (dx === 0 && dy === 0) return null;
  const parts = [];
  if (dx !== 0) parts.push(`${Math.abs(dx)} px ${dx > 0 ? 'right' : 'left'}`);
  if (dy !== 0) parts.push(`${Math.abs(dy)} px ${dy > 0 ? 'down' : 'up'}`);
  return `moved ${parts.join(' and ')}`;
}

function resizePhrase(before, after) {
  const a = sizeOf(before);
  const b = sizeOf(after);
  if (!a || !b) return null;
  if (a.scalar && b.scalar) {
    if (a.w === b.w) return null;
    return `resized from ${a.w} px to ${b.w} px`;
  }
  if (a.w === b.w && a.h === b.h) return null;
  return `resized from ${a.w}×${a.h} to ${b.w}×${b.h}`;
}

function rotationPhrase(before, after) {
  const a = Number(before?.rotation);
  const b = Number(after?.rotation);
  if (!Number.isFinite(a) || !Number.isFinite(b)) return null;
  let delta = b - a;
  while (delta > Math.PI) delta -= Math.PI * 2;
  while (delta < -Math.PI) delta += Math.PI * 2;
  const degrees = Math.round((delta * 180) / Math.PI);
  if (degrees === 0) return null;
  return `rotated ${Math.abs(degrees)}° ${degrees > 0 ? 'clockwise' : 'anticlockwise'}`;
}

function percent(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return `${Math.round(clamp01(n) * 100)}%`;
}

/// Field-level diff rows for the owner's before/after table.
function diffFields(before, after) {
  const fields = [];
  const push = (label, from, to) => {
    if (from === to) return;
    fields.push({ label, before: from ?? '—', after: to ?? '—' });
  };
  const has = (o, k) => o && typeof o === 'object' && k in o;

  const ca = centerOf(before);
  const cb = centerOf(after);
  if (ca && cb) {
    push('Position', `${Math.round(ca.x)}, ${Math.round(ca.y)}`, `${Math.round(cb.x)}, ${Math.round(cb.y)}`);
  }
  const sa = sizeOf(before);
  const sb = sizeOf(after);
  if (sa && sb) {
    const fa = sa.scalar ? `${sa.w} px` : `${sa.w} × ${sa.h}`;
    const fb = sb.scalar ? `${sb.w} px` : `${sb.w} × ${sb.h}`;
    push('Size', fa, fb);
  }
  if (has(before, 'color') || has(after, 'color')) {
    push('Colour', colorName(before?.color), colorName(after?.color));
  }
  if (has(before, 'strokeWidth') || has(after, 'strokeWidth')) {
    push('Stroke width', px(before?.strokeWidth), px(after?.strokeWidth));
  }
  if (has(before, 'opacity') || has(after, 'opacity')) {
    push('Opacity', percent(before?.opacity ?? 1), percent(after?.opacity ?? 1));
  }
  if (has(before, 'brushType') || has(after, 'brushType')) {
    push('Brush', BRUSH_WORDS[before?.brushType] || before?.brushType, BRUSH_WORDS[after?.brushType] || after?.brushType);
  }
  if (has(before, 'shapeType') || has(after, 'shapeType')) {
    push('Shape', SHAPE_WORDS[before?.shapeType] || before?.shapeType, SHAPE_WORDS[after?.shapeType] || after?.shapeType);
  }
  if (has(before, 'isFilled') || has(after, 'isFilled')) {
    push('Fill', before?.isFilled ? 'filled' : 'outline', after?.isFilled ? 'filled' : 'outline');
  }
  if (has(before, 'borderRadius') || has(after, 'borderRadius')) {
    push('Corner radius', px(before?.borderRadius ?? 0), px(after?.borderRadius ?? 0));
  }
  if (has(before, 'rotation') || has(after, 'rotation')) {
    const da = Math.round(((Number(before?.rotation) || 0) * 180) / Math.PI);
    const db = Math.round(((Number(after?.rotation) || 0) * 180) / Math.PI);
    push('Rotation', `${da}°`, `${db}°`);
  }
  if (has(before, 'text') || has(after, 'text')) {
    push('Text', quoted(before?.text), quoted(after?.text));
  }
  if (has(before, 'lineStyle') || has(after, 'lineStyle')) {
    push('Line style', before?.lineStyle, after?.lineStyle);
  }
  if (has(before, 'hasArrowhead') || has(after, 'hasArrowhead')) {
    push('Arrowhead', before?.hasArrowhead ? 'yes' : 'no', after?.hasArrowhead ? 'yes' : 'no');
  }
  if (has(before, 'startAnchor') || has(after, 'startAnchor')) {
    push('Start anchor', before?.startAnchor, after?.startAnchor);
  }
  if (has(before, 'endAnchor') || has(after, 'endAnchor')) {
    push('End anchor', before?.endAnchor, after?.endAnchor);
  }
  if ((before?.startElementId || null) !== (after?.startElementId || null)) {
    push('Start attached to', before?.startElementId ? 'an element' : 'nothing', after?.startElementId ? 'an element' : 'nothing');
  }
  if ((before?.endElementId || null) !== (after?.endElementId || null)) {
    push('End attached to', before?.endElementId ? 'an element' : 'nothing', after?.endElementId ? 'an element' : 'nothing');
  }
  if ((before?.imageBase64 || '') !== (after?.imageBase64 || '')) {
    push('Image', before?.imageBase64 ? 'previous image' : 'none', after?.imageBase64 ? 'new image' : 'none');
  }
  if (has(before, 'z') || has(after, 'z')) {
    push('Layer order', String(before?.z ?? 0), String(after?.z ?? 0));
  }
  return fields;
}

/// Describe one element transition. `before`/`after` are plain element maps
/// (either may be undefined for add/delete).
function describeChange(before, after) {
  const hasBefore = before != null;
  const hasAfter = after != null;

  if (!hasBefore && hasAfter) {
    return { kind: 'add', detail: `Added ${elementNoun(after)}`, fields: [] };
  }
  if (hasBefore && !hasAfter) {
    return { kind: 'delete', detail: `Removed ${elementNoun(before)}`, fields: [] };
  }
  if (!hasBefore && !hasAfter) {
    return { kind: 'update', detail: 'Changed an element', fields: [] };
  }

  const noun = elementNoun(after) !== 'element' ? elementNoun(after) : elementNoun(before);
  const phrases = [];

  const movement = movementPhrase(before, after);
  if (movement) phrases.push(movement);

  const resize = resizePhrase(before, after);
  if (resize) phrases.push(resize);

  if (before.color !== after.color && (has(before, 'color') || has(after, 'color'))) {
    phrases.push(`changed colour from ${colorName(before.color)} to ${colorName(after.color)}`);
  }
  if (before.strokeWidth !== after.strokeWidth && (has(before, 'strokeWidth') || has(after, 'strokeWidth'))) {
    phrases.push(`changed stroke width from ${px(before.strokeWidth) ?? '—'} to ${px(after.strokeWidth) ?? '—'}`);
  }
  if (before.opacity !== after.opacity && (has(before, 'opacity') || has(after, 'opacity'))) {
    phrases.push(`changed opacity from ${percent(before.opacity ?? 1)} to ${percent(after.opacity ?? 1)}`);
  }
  if (before.brushType !== after.brushType && (has(before, 'brushType') || has(after, 'brushType'))) {
    phrases.push(`changed brush from ${BRUSH_WORDS[before.brushType] || before.brushType || 'solid'} to ${BRUSH_WORDS[after.brushType] || after.brushType || 'solid'}`);
  }
  if (before.shapeType !== after.shapeType && (has(before, 'shapeType') || has(after, 'shapeType'))) {
    phrases.push(`changed shape from ${SHAPE_WORDS[before.shapeType] || 'shape'} to ${SHAPE_WORDS[after.shapeType] || 'shape'}`);
  }
  if (before.isFilled !== after.isFilled && (has(before, 'isFilled') || has(after, 'isFilled'))) {
    phrases.push(after.isFilled ? 'filled the shape' : 'removed the fill');
  }
  if (before.borderRadius !== after.borderRadius && (has(before, 'borderRadius') || has(after, 'borderRadius'))) {
    phrases.push(`changed corner radius from ${px(before.borderRadius ?? 0)} to ${px(after.borderRadius ?? 0)}`);
  }
  const rotation = rotationPhrase(before, after);
  if (rotation) phrases.push(rotation);
  if (before.text !== after.text && (has(before, 'text') || has(after, 'text'))) {
    phrases.push(`edited text from ${quoted(before.text)} to ${quoted(after.text)}`);
  }
  if (before.lineStyle !== after.lineStyle && (has(before, 'lineStyle') || has(after, 'lineStyle'))) {
    phrases.push(`changed line style from ${before.lineStyle || 'straight'} to ${after.lineStyle || 'straight'}`);
  }
  if (before.hasArrowhead !== after.hasArrowhead && (has(before, 'hasArrowhead') || has(after, 'hasArrowhead'))) {
    phrases.push(after.hasArrowhead ? 'added an arrowhead' : 'removed the arrowhead');
  }
  if ((before.startElementId || null) !== (after.startElementId || null)) {
    phrases.push(after.startElementId ? 'attached the connector start to an element' : 'detached the connector start');
  }
  if ((before.endElementId || null) !== (after.endElementId || null)) {
    phrases.push(after.endElementId ? 'attached the connector end to an element' : 'detached the connector end');
  }
  if ((before.imageBase64 || '') !== (after.imageBase64 || '')) {
    phrases.push('replaced the image');
  }

  const fields = diffFields(before, after);

  if (!phrases.length) {
    // Only the layer order (or another non-visual field) changed.
    if (fields.length === 1 && fields[0].label === 'Layer order') {
      return { kind: 'update', detail: `Reordered ${noun}`, fields };
    }
    return { kind: 'update', detail: `Updated ${noun}`, fields };
  }

  return {
    kind: 'update',
    detail: `${capitalize(noun)}: ${phrases.join('; ')}`,
    fields,
  };
}

function has(o, k) {
  return o != null && typeof o === 'object' && k in o;
}

/// One-line summary for a whole operation.
function summarizeOperation(op, changes) {
  const action = op?.action;
  const list = Array.isArray(changes) ? changes : [];

  if (action === 'clear') {
    return `Cleared the board${list.length ? ` (${list.length} element${list.length === 1 ? '' : 's'} removed)` : ''}`;
  }
  if (action === 'restore') {
    const from = op?.restoredFromVersion;
    return from != null
      ? `Restored the board to version ${from}`
      : 'Restored the board to an earlier version';
  }
  if (action === 'revert') {
    return list.length === 1 && list[0].detail
      ? `Undid an edit — ${list[0].detail}`
      : `Undid ${list.length} edit${list.length === 1 ? '' : 's'}`;
  }
  if (list.length === 1 && list[0].detail) return list[0].detail;
  if (!list.length) return 'Made an edit';

  let adds = 0;
  let deletes = 0;
  let updates = 0;
  for (const c of list) {
    if (c.kind === 'add') adds++;
    else if (c.kind === 'delete') deletes++;
    else updates++;
  }
  const parts = [];
  if (adds) parts.push(`added ${adds}`);
  if (updates) parts.push(`edited ${updates}`);
  if (deletes) parts.push(`removed ${deletes}`);
  const lead = list.find(c => c.detail)?.detail;
  const counts = capitalize(parts.join(', '));
  return lead ? `${counts} — ${lead}` : counts;
}

module.exports = {
  colorName,
  elementNoun,
  centerOf,
  sizeOf,
  describeChange,
  summarizeOperation,
  diffFields,
};