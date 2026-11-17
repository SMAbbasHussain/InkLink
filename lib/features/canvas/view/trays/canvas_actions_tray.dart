import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/canvas/canvas_toolbar_action.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/canvas_toolbar_action_meta.dart';
import '../../models/canvas_tool_mode.dart';
import '../widgets/sliding_tray.dart';

/// Bottom-right sliding tray containing all customizable canvas/art actions.
///
/// Actions not currently pinned to the bottom bar appear first under
/// "More Tools", followed by pinned bar actions under "On Bottom Bar".
class CanvasActionsTray extends StatelessWidget {
  final bool isOpen;
  final bool canEdit;
  final CanvasToolMode activeTool;
  final bool isArrowPreset;
  final bool isLayersOpen;
  final bool isShapesPopupOpen;
  final List<CanvasToolbarAction> bottomBarActions;
  final ValueChanged<CanvasToolbarAction> onActionSelected;
  final VoidCallback? onCustomizeBottomBar;
  final VoidCallback? onClose;

  const CanvasActionsTray({
    super.key,
    required this.isOpen,
    required this.onActionSelected,
    this.canEdit = true,
    this.activeTool = CanvasToolMode.select,
    this.isArrowPreset = false,
    this.isLayersOpen = false,
    this.isShapesPopupOpen = false,
    this.bottomBarActions = CanvasToolbarAction.defaultBottomBarActions,
    this.onCustomizeBottomBar,
    this.onClose,
  });

  bool _isSelected(CanvasToolbarAction action) => switch (action) {
    CanvasToolbarAction.select => activeTool == CanvasToolMode.select,
    CanvasToolbarAction.hand => activeTool == CanvasToolMode.hand,
    CanvasToolbarAction.pen => activeTool == CanvasToolMode.doodle,
    CanvasToolbarAction.highlight => activeTool == CanvasToolMode.highlight,
    CanvasToolbarAction.eraser => activeTool == CanvasToolMode.eraser,
    CanvasToolbarAction.fill => activeTool == CanvasToolMode.fill,
    CanvasToolbarAction.shape =>
      isShapesPopupOpen || (activeTool == CanvasToolMode.shape && !isArrowPreset),
    CanvasToolbarAction.arrow =>
      isArrowPreset || activeTool == CanvasToolMode.arrow,
    CanvasToolbarAction.text => activeTool == CanvasToolMode.text,
    CanvasToolbarAction.image => activeTool == CanvasToolMode.image,
    CanvasToolbarAction.layers => isLayersOpen,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final offBarActions = CanvasToolbarAction.actionsNotOnBar(bottomBarActions);
    final onBarActions = [for (final action in bottomBarActions) action];

    final media = MediaQuery.of(context);
    final maxHeight = math.max(
      200.0,
      media.size.height - media.padding.top - media.padding.bottom - 124,
    );
    final trayHeight = math.min(430.0, maxHeight);

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'Canvas Tools',
      headerActions: onCustomizeBottomBar == null
          ? null
          : Tooltip(
              message: 'Customize bottom bar',
              child: InkWell(
                borderRadius: BorderRadius.circular(InkRadii.chip),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCustomizeBottomBar!();
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    LucideIcons.pencilRuler,
                    size: 16,
                    color: tokens.inkMuted,
                  ),
                ),
              ),
            ),
      height: trayHeight,
      width: 268,
      bottomOffset: 60,
      onClose: onClose,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offBarActions.isNotEmpty) ...[
              _SectionLabel('MORE TOOLS'),
              const SizedBox(height: 6),
              _ActionsGrid(
                actions: offBarActions,
                canEdit: canEdit,
                isSelected: _isSelected,
                onTap: onActionSelected,
              ),
              if (onBarActions.isNotEmpty) const SizedBox(height: 12),
            ],
            if (onBarActions.isNotEmpty) ...[
              _SectionLabel('ON BOTTOM BAR'),
              const SizedBox(height: 6),
              _ActionsGrid(
                actions: onBarActions,
                canEdit: canEdit,
                isSelected: _isSelected,
                onTap: onActionSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: InkType.caption(context.ink.inkMuted).copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  final List<CanvasToolbarAction> actions;
  final bool canEdit;
  final bool Function(CanvasToolbarAction) isSelected;
  final ValueChanged<CanvasToolbarAction> onTap;

  const _ActionsGrid({
    required this.actions,
    required this.canEdit,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.08,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final selected = isSelected(action);
        final available = canEdit || !action.requiresEdit;
        final foreground = !available
            ? tokens.inkMuted.withValues(alpha: 0.45)
            : selected
            ? tokens.accent
            : tokens.ink;

        return InkWell(
          onTap: available
              ? () {
                  HapticFeedback.selectionClick();
                  onTap(action);
                }
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? tokens.accentSoft : tokens.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconForCanvasToolbarAction(action),
                  size: 19,
                  color: foreground,
                ),
                const SizedBox(height: 4),
                Text(
                  action.shortLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: InkType.caption(
                    selected ? tokens.accentText : foreground,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
