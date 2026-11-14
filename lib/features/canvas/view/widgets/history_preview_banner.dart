import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/history/board_operation.dart';
import '../../../../domain/models/history/history_scrub.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';

/// Top bar shown while the owner is previewing a past version, scrubbing
/// op-by-op through a version block or a user's replay, comparing a logged
/// change against the live board, or inspecting an undo request's evidence.
/// It owns the top of the screen in preview mode (the live top pills are
/// hidden), with the exit cross at the top-left.
class HistoryPreviewBanner extends StatelessWidget {
  final int? version;
  final String? title;
  final String? requestId;
  final bool showsDesired;
  final VoidCallback? onRestore;
  final VoidCallback onExit;
  final ValueChanged<bool>? onToggleDesired;
  final VoidCallback? onReview;

  /// The active scrub session (a version block or a user's replay), or null
  /// when not scrubbing.
  final HistoryScrub? scrub;
  final int scrubIndex;
  final ValueChanged<int>? onScrubChanged;

  /// Display name of the scrubbed user, for the "Undo {name} after this
  /// point" action.
  final String? targetName;

  /// Scrub action: restore the board to the currently selected stop.
  final VoidCallback? onRestoreToState;

  /// User-scrub action: undo that user's ops after the selected stop.
  final VoidCallback? onUndoUserAfter;

  /// Member request scrub: open the reason/send sheet for the selected stop.
  final VoidCallback? onSendRequest;

  /// One-line guidance under the slider (e.g. what the member should pick).
  final String? hint;

  /// Compare/scrub action: revert the specific logged op(s) behind this view.
  final VoidCallback? onRevertThisChange;

  /// User-scrub pagination: prepend the user's older ops to the session.
  final VoidCallback? onLoadOlder;

  /// Per-log compare mode: show a Past/Current toggle instead of the legacy
  /// restore action.
  final bool compareEnabled;

  const HistoryPreviewBanner({
    super.key,
    this.version,
    this.title,
    this.requestId,
    this.showsDesired = false,
    this.onRestore,
    required this.onExit,
    this.onToggleDesired,
    this.onReview,
    this.scrub,
    this.scrubIndex = 0,
    this.onScrubChanged,
    this.targetName,
    this.onRestoreToState,
    this.onUndoUserAfter,
    this.onSendRequest,
    this.hint,
    this.onRevertThisChange,
    this.onLoadOlder,
    this.compareEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final isEvidence = requestId != null;
    final isScrub = scrub != null;
    final isCompare = compareEnabled && !isEvidence && !isScrub;
    final heading = title ??
        (isEvidence
            ? 'Undo request evidence'
            : 'Viewing version ${version ?? '—'}');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpacing.s12,
          InkSpacing.s8,
          InkSpacing.s12,
          0,
        ),
        child: GlassPanel(
          radius: InkRadii.chip,
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.s8,
            vertical: InkSpacing.s8,
          ),
          accentGlow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ExitButton(onTap: onExit),
                  const SizedBox(width: InkSpacing.s8),
                  Icon(
                    isScrub
                        ? LucideIcons.rewind
                        : isCompare
                            ? LucideIcons.gitCompare
                            : isEvidence
                                ? LucideIcons.eye
                                : LucideIcons.history,
                    size: 16,
                    color: tokens.accentText,
                  ),
                  const SizedBox(width: InkSpacing.s8),
                  Expanded(
                    child: Text(
                      heading,
                      style: InkType.bodyStrong(tokens.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // "Review" (the legacy whole-request plan) only belongs on
                  // the desired-state evidence view; a scrub-style evidence
                  // preview reviews itself — restore from the slider.
                  if (isEvidence && !isScrub && onReview != null) ...[
                    const SizedBox(width: InkSpacing.s4),
                    _BannerAction(
                      icon: LucideIcons.undo2,
                      label: 'Review',
                      color: tokens.accentText,
                      onTap: onReview!,
                    ),
                  ] else if (!isEvidence &&
                      !isScrub &&
                      !isCompare &&
                      version != null &&
                      onRestore != null)
                    _BannerAction(
                      icon: LucideIcons.undo2,
                      label: 'Restore',
                      color: tokens.accentText,
                      onTap: onRestore!,
                    ),
                ],
              ),
              if (isScrub)
                _ScrubSection(
                  scrub: scrub!,
                  scrubIndex: scrubIndex,
                  targetName: targetName,
                  onChanged: onScrubChanged,
                  onRestoreToState: onRestoreToState,
                  onUndoUserAfter: onUndoUserAfter,
                  onSendRequest: onSendRequest,
                  hint: hint,
                  onLoadOlder: onLoadOlder,
                )
              else if (isCompare || isEvidence) ...[
                const SizedBox(height: InkSpacing.s4),
                Row(
                  children: [
                    const Spacer(),
                    _DesiredToggle(
                      showsDesired: showsDesired,
                      onChanged: onToggleDesired,
                      // Evidence compares live vs. requested; log compare
                      // compares past vs. current.
                      activeLabel: isCompare ? 'Past' : 'Requested',
                    ),
                  ],
                ),
                if (isCompare && onRevertThisChange != null) ...[
                  const SizedBox(height: InkSpacing.s8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkButton.danger(
                      label: 'Revert this change',
                      onPressed: onRevertThisChange,
                      compact: true,
                      expand: false,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slider + step readout + actions for an active scrub session. Every action
/// button renders only when its callback is provided, so different scrub
/// flavours show different affordances (owner restore vs. member request).
class _ScrubSection extends StatelessWidget {
  final HistoryScrub scrub;
  final int scrubIndex;
  final String? targetName;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onRestoreToState;
  final VoidCallback? onUndoUserAfter;
  final VoidCallback? onSendRequest;
  final String? hint;
  final VoidCallback? onLoadOlder;

  const _ScrubSection({
    required this.scrub,
    required this.scrubIndex,
    this.targetName,
    this.onChanged,
    this.onRestoreToState,
    this.onUndoUserAfter,
    this.onSendRequest,
    this.hint,
    this.onLoadOlder,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final lastIndex = scrub.lastIndex;
    final index = scrubIndex.clamp(0, lastIndex);
    final stop = scrub.stopAt(index);
    final isUserScrub = scrub.targetUid != null;
    final canStepBack = lastIndex > 0;
    final canUndoAfter = isUserScrub && index < lastIndex;
    final canLoadOlder = index == 0 && scrub.hasMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: InkSpacing.s4),
        Row(
          children: [
            Text(
              'Step ${index + 1} of ${scrub.stops.length}'
              '  ·  v${stop.version}',
              style: InkType.caption(tokens.inkSecondary),
            ),
            const Spacer(),
            if (canLoadOlder && onLoadOlder != null)
              _BannerAction(
                icon: LucideIcons.chevronLeft,
                label: 'Load older',
                color: tokens.accentText,
                onTap: onLoadOlder!,
              ),
          ],
        ),
        if (canStepBack) ...[
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: tokens.accent,
              inactiveTrackColor: tokens.field,
              thumbColor: tokens.accentText,
              overlayColor: tokens.accentSoft,
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: index.toDouble(),
              min: 0,
              max: lastIndex.toDouble(),
              divisions: lastIndex,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value.round()),
            ),
          ),
          Text(
            stop.headline ?? 'Change v${stop.version}',
            style: InkType.caption(tokens.ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (hint != null) ...[
          const SizedBox(height: InkSpacing.s4),
          Text(
            hint!,
            style: InkType.caption(tokens.inkMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: InkSpacing.s8),
        Wrap(
          spacing: InkSpacing.s8,
          runSpacing: InkSpacing.s8,
          children: [
            if (canUndoAfter && onUndoUserAfter != null)
              InkButton.danger(
                label: targetName != null
                    ? "Undo $targetName's changes after this point"
                    : 'Undo later changes after this point',
                onPressed: onUndoUserAfter,
                compact: true,
                expand: false,
              ),
            if (onRestoreToState != null)
              InkButton.secondary(
                label: 'Restore to this state',
                onPressed: onRestoreToState,
                compact: true,
                expand: false,
              ),
            if (onSendRequest != null)
              InkButton.primary(
                label: 'Send request',
                onPressed: onSendRequest,
                compact: true,
                expand: false,
              ),
          ],
        ),
      ],
    );
  }
}

class _ExitButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: Container(
        padding: const EdgeInsets.all(InkSpacing.s4),
        decoration: BoxDecoration(
          color: tokens.field,
          borderRadius: BorderRadius.circular(InkRadii.chip),
        ),
        child: Icon(LucideIcons.x, size: 16, color: tokens.ink),
      ),
    );
  }
}

class _DesiredToggle extends StatelessWidget {
  final bool showsDesired;
  final ValueChanged<bool>? onChanged;
  final String activeLabel;

  const _DesiredToggle({
    required this.showsDesired,
    this.onChanged,
    this.activeLabel = 'Requested',
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'Current', !showsDesired, false),
          _segment(context, activeLabel, showsDesired, true),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    bool active,
    bool desired,
  ) {
    final tokens = context.ink;
    return InkWell(
      onTap: () => onChanged?.call(desired),
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s8,
          vertical: InkSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: active ? tokens.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(InkRadii.chip),
        ),
        child: Text(
          label,
          style: InkType.caption(
            active ? tokens.accentText : tokens.inkSecondary,
          ),
        ),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BannerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s8,
          vertical: InkSpacing.s4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: InkType.caption(color)),
          ],
        ),
      ),
    );
  }
}
