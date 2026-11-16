import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/canvas/canvas_shape_type.dart';
import '../../../../domain/models/history/revert_plan.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../bloc/canvas_bloc.dart';

/// Opens the owner's per-element revert review (D4/D12).
///
/// The [bloc] is passed explicitly because a modal bottom sheet is pushed on
/// the root navigator and therefore is not under the page's BlocProvider.
Future<void> showRevertReviewSheet(
  BuildContext context, {
  required CanvasBloc bloc,
  required RevertPlan plan,
  String? requestId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => _RevertReviewSheet(
      bloc: bloc,
      plan: plan,
      requestId: requestId ?? plan.requestId,
    ),
  );
}

class _RevertReviewSheet extends StatefulWidget {
  final CanvasBloc bloc;
  final RevertPlan plan;
  final String? requestId;

  const _RevertReviewSheet({
    required this.bloc,
    required this.plan,
    this.requestId,
  });

  @override
  State<_RevertReviewSheet> createState() => _RevertReviewSheetState();
}

class _RevertReviewSheetState extends State<_RevertReviewSheet> {
  late final Map<String, String> _decisions;

  @override
  void initState() {
    super.initState();
    // Clean items default to applying the earlier version. Conflicted items
    // default to the safe choice: leave the current board untouched.
    _decisions = {
      for (final item in widget.plan.items)
        item.elementId: item.conflict ? 'keep' : 'revert',
    };
  }

  int get _restoreCount =>
      _decisions.values.where((decision) => decision == 'revert').length;

  bool get _isRestore => widget.plan.mode == 'restore';

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final items = widget.plan.items;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.all(InkSpacing.s20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(tokens),
                const SizedBox(height: InkSpacing.s12),
                if (widget.plan.conflictCount > 0) ...[
                  _ConflictBanner(count: widget.plan.conflictCount),
                  const SizedBox(height: InkSpacing.s12),
                ],
                Text(
                  'Choose what stays on the board. Nothing changes until you '
                  'confirm. "Keep current" leaves an item untouched; '
                  '"Restore previous" replaces it with the earlier version.',
                  style: InkType.caption(tokens.inkSecondary),
                ),
                const SizedBox(height: InkSpacing.s12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: InkSpacing.s8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ReviewCard(
                        item: item,
                        decision: _decisions[item.elementId] ?? 'keep',
                        onChanged: (value) {
                          setState(() => _decisions[item.elementId] = value);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: InkSpacing.s12),
                Text(
                  _restoreCount == 0
                      ? 'All items will stay exactly as they are now.'
                      : '$_restoreCount of ${items.length} item(s) will be '
                            'replaced with the earlier version.',
                  style: InkType.caption(tokens.inkMuted),
                ),
                if (widget.requestId != null) ...[
                  const SizedBox(height: InkSpacing.s8),
                  InkButton.secondary(
                    label: 'Preview the full request on the board',
                    icon: const Icon(LucideIcons.eye),
                    onPressed: () {
                      final id = widget.requestId!;
                      widget.bloc.add(const CanvasHistoryPlanDismissed());
                      Navigator.pop(context);
                      widget.bloc.add(
                        CanvasHistoryRequestEvidenceRequested(id),
                      );
                    },
                  ),
                ],
                const SizedBox(height: InkSpacing.s12),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(InkTokens tokens) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tokens.accentSoft,
            borderRadius: BorderRadius.circular(InkRadii.chip + 3),
          ),
          child: Icon(
            _isRestore ? LucideIcons.history : LucideIcons.gitCompare,
            size: 19,
            color: tokens.accentText,
          ),
        ),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRestore ? 'Review restore' : 'Review changes',
                style: InkType.title(tokens.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.plan.items.length} item(s) need a decision',
                style: InkType.caption(tokens.inkMuted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
          onPressed: _cancel,
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: InkButton.secondary(label: 'Cancel', onPressed: _cancel),
        ),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          flex: 2,
          child: InkButton.primary(
            label: _restoreCount == 0
                ? 'Keep current board'
                : (_isRestore
                      ? 'Restore $_restoreCount item(s)'
                      : 'Apply $_restoreCount restore(s)'),
            onPressed: () {
              if (_restoreCount == 0) {
                _cancel();
                return;
              }
              widget.bloc.add(
                CanvasHistoryApplyRevert(
                  planId: widget.plan.planId,
                  decisions: Map<String, String>.from(_decisions),
                  requestId: widget.requestId,
                ),
              );
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  void _cancel() {
    widget.bloc.add(const CanvasHistoryPlanDismissed());
    Navigator.pop(context);
  }
}

class _ConflictBanner extends StatelessWidget {
  final int count;

  const _ConflictBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(InkSpacing.s12),
      decoration: BoxDecoration(
        color: tokens.pending.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(InkRadii.chip),
        border: Border.all(color: tokens.pending.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, size: 17, color: tokens.pending),
          const SizedBox(width: InkSpacing.s8),
          Expanded(
            child: Text(
              count == 1
                  ? 'One item was edited after the change you are reviewing. '
                        'It defaults to Keep current so nothing unexpected is '
                        'overwritten.'
                  : '$count items were edited after the change you are '
                        'reviewing. They default to Keep current so nothing '
                        'unexpected is overwritten.',
              style: InkType.caption(tokens.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final RevertPlanItem item;
  final String decision;
  final ValueChanged<String> onChanged;

  const _ReviewCard({
    required this.item,
    required this.decision,
    required this.onChanged,
  });

  bool get _showPrevious => decision == 'revert';

  CanvasElement? get _previewElement {
    final map = _showPrevious ? item.after : item.before;
    if (map == null) return null;
    try {
      return CanvasElement.fromMap(item.elementId, map);
    } catch (_) {
      return null;
    }
  }

  bool get _isAbsent => (_showPrevious ? item.after : item.before) == null;

  String get _title {
    final label = item.label?.trim();
    if (label != null && label.isNotEmpty) {
      return label[0].toUpperCase() + label.substring(1);
    }
    final type = (item.after ?? item.before)?['type'] as String?;
    switch (type) {
      case 'stroke':
        return 'Freehand stroke';
      case 'shape':
        return 'Shape';
      case 'text':
        return 'Text';
      case 'image':
        return 'Image';
      case 'sticky_note':
        return 'Sticky note';
      case 'connector':
        return 'Connector';
      default:
        return 'Drawing element';
    }
  }

  String get _summary {
    final summary = item.summary?.trim();
    if (summary != null && summary.isNotEmpty) return summary;
    if (item.conflict) {
      return 'Someone edited this item after the change you are reviewing.';
    }
    return 'The current and earlier versions of this item differ.';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final showingPrevious = _showPrevious;
    final previewLabel = showingPrevious ? 'Previous version' : 'Current board';

    return Container(
      padding: const EdgeInsets.all(InkSpacing.s12),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.input),
        border: item.conflict
            ? Border.all(color: tokens.pending.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_title, style: InkType.bodyStrong(tokens.ink)),
              ),
              if (item.conflict) ...[
                const SizedBox(width: InkSpacing.s8),
                _Badge(
                  icon: LucideIcons.alertTriangle,
                  label: 'Changed later',
                  color: tokens.pending,
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _summary,
            style: InkType.caption(tokens.inkSecondary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: InkSpacing.s8),
          _ElementPreview(
            element: _previewElement,
            isAbsent: _isAbsent,
            label: previewLabel,
          ),
          const SizedBox(height: InkSpacing.s8),
          Row(
            children: [
              Icon(
                showingPrevious ? LucideIcons.history : LucideIcons.check,
                size: 14,
                color: showingPrevious ? tokens.pending : tokens.success,
              ),
              const SizedBox(width: InkSpacing.s4),
              Expanded(
                child: Text(
                  showingPrevious
                      ? 'Showing the earlier version — applying will replace '
                            'the current item with this.'
                      : 'Showing what is on the board now — applying keeps '
                            'this unchanged.',
                  style: InkType.caption(tokens.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s8),
          _DecisionChoice(decision: decision, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: InkType.caption(color)),
        ],
      ),
    );
  }
}

class _DecisionChoice extends StatelessWidget {
  final String decision;
  final ValueChanged<String> onChanged;

  const _DecisionChoice({required this.decision, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _DecisionTile(
              selected: decision == 'keep',
              icon: LucideIcons.check,
              title: 'Keep current',
              subtitle: 'Leave it as it is now',
              selectedColor: tokens.success,
              onTap: () => onChanged('keep'),
            ),
          ),
          const SizedBox(width: InkSpacing.s8),
          Expanded(
            child: _DecisionTile(
              selected: decision == 'revert',
              icon: LucideIcons.history,
              title: 'Restore previous',
              subtitle: 'Bring back the earlier version',
              selectedColor: tokens.pending,
              onTap: () => onChanged('revert'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color selectedColor;
  final VoidCallback onTap;

  const _DecisionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(InkSpacing.s8),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.12)
              : tokens.paper,
          borderRadius: BorderRadius.circular(InkRadii.chip),
          border: Border.all(
            color: selected ? selectedColor : tokens.glassStroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? selectedColor : tokens.inkMuted,
            ),
            const SizedBox(width: InkSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: InkType.caption(
                      selected ? selectedColor : tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: InkType.caption(tokens.inkMuted),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElementPreview extends StatelessWidget {
  final CanvasElement? element;
  final bool isAbsent;
  final String label;

  const _ElementPreview({
    required this.element,
    required this.isAbsent,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PREVIEW',
              style: InkType.caption(tokens.inkMuted).copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(label, style: InkType.caption(tokens.inkMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 148,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tokens.paper,
            borderRadius: BorderRadius.circular(InkRadii.chip),
            border: Border.all(color: tokens.glassStroke),
          ),
          child: isAbsent
              ? _PreviewPlaceholder(
                  icon: LucideIcons.eyeOff,
                  text: 'Not on the board in this version',
                )
              : element == null
              ? const _PreviewPlaceholder(
                  icon: LucideIcons.imageOff,
                  text: 'Preview unavailable',
                )
              : CustomPaint(
                  painter: _ElementPreviewPainter(element!),
                  size: Size.infinite,
                ),
        ),
      ],
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PreviewPlaceholder({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: tokens.inkMuted),
          const SizedBox(height: InkSpacing.s4),
          Text(text, style: InkType.caption(tokens.inkMuted)),
        ],
      ),
    );
  }
}

class _ElementPreviewPainter extends CustomPainter {
  final CanvasElement element;

  const _ElementPreviewPainter(this.element);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _boundsFor(element);
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) return;

    const padding = 18.0;
    final availableWidth = math.max(1.0, size.width - padding * 2);
    final availableHeight = math.max(1.0, size.height - padding * 2);
    final scale = math
        .min(availableWidth / bounds.width, availableHeight / bounds.height)
        .clamp(0.05, 8.0);

    final dx = size.width / 2 - bounds.center.dx * scale;
    final dy = size.height / 2 - bounds.center.dy * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    _paintElement(canvas, element);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ElementPreviewPainter oldDelegate) =>
      oldDelegate.element != element;
}

Rect? _boundsFor(CanvasElement element) {
  switch (element) {
    case StrokeElement stroke:
      if (stroke.points.isEmpty) return null;
      var minX = stroke.points.first.dx;
      var minY = stroke.points.first.dy;
      var maxX = minX;
      var maxY = minY;
      for (final point in stroke.points) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
      final pad = math.max(2.0, stroke.strokeWidth);
      return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(pad);
    case ShapeElement shape:
      final width = shape.shapeType == CanvasShapeType.rectangle
          ? shape.size * 1.35
          : (shape.shapeType == CanvasShapeType.ellipse
                ? shape.size * 1.3
                : shape.size);
      final height = shape.shapeType == CanvasShapeType.rectangle
          ? shape.size * 0.8
          : (shape.shapeType == CanvasShapeType.ellipse
                ? shape.size * 0.85
                : shape.size);
      return Rect.fromCenter(
        center: shape.center,
        width: width,
        height: height,
      ).inflate(shape.strokeWidth + 4);
    case TextElement text:
      return Rect.fromCenter(
        center: text.center,
        width: text.width > 0 ? text.width : 180,
        height: text.height > 0 ? text.height : 48,
      );
    case ImageElement image:
      return Rect.fromCenter(
        center: image.center,
        width: image.width,
        height: image.height,
      );
    case StickyNoteElement note:
      return Rect.fromCenter(
        center: note.center,
        width: note.width,
        height: note.height,
      );
    case ConnectorElement connector:
      return Rect.fromPoints(
        connector.startPoint,
        connector.endPoint,
      ).inflate(12);
  }
}

void _paintElement(Canvas canvas, CanvasElement element) {
  switch (element) {
    case StrokeElement stroke:
      _paintStroke(canvas, stroke);
    case ShapeElement shape:
      _paintShape(canvas, shape);
    case TextElement text:
      _paintText(canvas, text.text, text.center, text.color, 16, text.width);
    case ImageElement image:
      final rect = Rect.fromCenter(
        center: image.center,
        width: image.width,
        height: image.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = const Color(0xFFE8ECF2),
      );
      _paintText(canvas, 'Image', image.center, const Color(0xFF667085), 14, 0);
    case StickyNoteElement note:
      final rect = Rect.fromCenter(
        center: note.center,
        width: note.width,
        height: note.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = note.color,
      );
      _paintText(
        canvas,
        note.text,
        note.center,
        const Color(0xFF2F2A16),
        13,
        note.width - 16,
      );
    case ConnectorElement connector:
      _paintConnector(canvas, connector);
  }
}

void _paintStroke(Canvas canvas, StrokeElement stroke) {
  if (stroke.points.isEmpty) return;
  final paint = Paint()
    ..color = stroke.color.withValues(alpha: stroke.opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.8, stroke.strokeWidth)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  if (stroke.points.length == 1) {
    canvas.drawCircle(
      stroke.points.first,
      math.max(0.8, stroke.strokeWidth) / 2,
      paint..style = PaintingStyle.fill,
    );
    return;
  }

  final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
  for (var i = 1; i < stroke.points.length; i++) {
    path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
  }
  canvas.drawPath(path, paint);
}

void _paintShape(Canvas canvas, ShapeElement shape) {
  final width = shape.shapeType == CanvasShapeType.rectangle
      ? shape.size * 1.35
      : (shape.shapeType == CanvasShapeType.ellipse
            ? shape.size * 1.3
            : shape.size);
  final height = shape.shapeType == CanvasShapeType.rectangle
      ? shape.size * 0.8
      : (shape.shapeType == CanvasShapeType.ellipse
            ? shape.size * 0.85
            : shape.size);
  final rect = Rect.fromCenter(
    center: shape.center,
    width: width,
    height: height,
  );

  final paint = Paint()
    ..color = shape.color
    ..style = shape.isFilled ? PaintingStyle.fill : PaintingStyle.stroke
    ..strokeWidth = math.max(0.8, shape.strokeWidth)
    ..strokeJoin = StrokeJoin.round;

  canvas.save();
  if (shape.rotation != 0) {
    canvas.translate(shape.center.dx, shape.center.dy);
    canvas.rotate(shape.rotation);
    canvas.translate(-shape.center.dx, -shape.center.dy);
  }

  switch (shape.shapeType) {
    case CanvasShapeType.rectangle:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(shape.borderRadius.clamp(0, shape.size / 2)),
        ),
        paint,
      );
    case CanvasShapeType.square:
      canvas.drawRect(rect, paint);
    case CanvasShapeType.circle:
    case CanvasShapeType.ellipse:
      canvas.drawOval(rect, paint);
    case CanvasShapeType.triangle:
      canvas.drawPath(
        _polygonPath(shape.center, shape.size / 2, 3, -math.pi / 2),
        paint,
      );
    case CanvasShapeType.diamond:
      canvas.drawPath(
        _polygonPath(shape.center, shape.size / 2, 4, math.pi / 4),
        paint,
      );
    case CanvasShapeType.star:
      canvas.drawPath(_starPath(shape.center, shape.size / 2), paint);
    case CanvasShapeType.pentagon:
      canvas.drawPath(
        _polygonPath(shape.center, shape.size / 2, 5, -math.pi / 2),
        paint,
      );
    case CanvasShapeType.hexagon:
      canvas.drawPath(
        _polygonPath(shape.center, shape.size / 2, 6, -math.pi / 2),
        paint,
      );
    case CanvasShapeType.line:
      canvas.drawLine(
        Offset(shape.center.dx - shape.size / 2, shape.center.dy),
        Offset(shape.center.dx + shape.size / 2, shape.center.dy),
        paint,
      );
    case CanvasShapeType.semicircle:
      canvas.drawArc(
        Rect.fromCenter(
          center: shape.center,
          width: shape.size,
          height: shape.size,
        ),
        math.pi,
        math.pi,
        shape.isFilled,
        paint,
      );
    case CanvasShapeType.arrow:
      final start = Offset(shape.center.dx - shape.size / 2, shape.center.dy);
      final end = Offset(shape.center.dx + shape.size / 2, shape.center.dy);
      canvas.drawLine(start, end, paint);
      final head = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - shape.size * 0.2, end.dy - shape.size * 0.12)
        ..lineTo(end.dx - shape.size * 0.2, end.dy + shape.size * 0.12)
        ..close();
      canvas.drawPath(head, paint..style = PaintingStyle.fill);
  }
  canvas.restore();
}

Path _polygonPath(Offset center, double radius, int sides, double startAngle) {
  final path = Path();
  for (var i = 0; i < sides; i++) {
    final angle = startAngle + i * 2 * math.pi / sides;
    final point = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

Path _starPath(Offset center, double radius) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radius : radius * 0.44;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final point = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

void _paintText(
  Canvas canvas,
  String text,
  Offset center,
  Color color,
  double fontSize,
  double maxWidth,
) {
  if (text.trim().isEmpty) return;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 4,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth > 0 ? maxWidth : 180);
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

void _paintConnector(Canvas canvas, ConnectorElement connector) {
  final paint = Paint()
    ..color = connector.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.8, connector.strokeWidth)
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(connector.startPoint, connector.endPoint, paint);
  if (connector.hasArrowhead) {
    final direction = connector.endPoint - connector.startPoint;
    final length = direction.distance;
    if (length > 0) {
      final unit = direction / length;
      final normal = Offset(-unit.dy, unit.dx);
      final tip = connector.endPoint;
      final base = tip - unit * 10;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + normal.dx * 5, base.dy + normal.dy * 5)
        ..lineTo(base.dx - normal.dx * 5, base.dy - normal.dy * 5)
        ..close();
      canvas.drawPath(path, paint..style = PaintingStyle.fill);
    }
  }
}
