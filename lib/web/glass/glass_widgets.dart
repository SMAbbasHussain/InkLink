import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GlassPanel
// ─────────────────────────────────────────────────────────────────────────────

/// A glass surface. Set [blur] only for persistent surfaces (top bar,
/// sidebar, menus, dialogs, profile card): backdrop blur is expensive. Without
/// [blur] it is "fake glass": translucent fill, hairline border, top
/// highlight and a soft sheen.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool blur;
  final bool strong;
  final Color? borderColor;
  final List<BoxShadow>? shadow;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = Glass.r20,
    this.blur = false,
    this.strong = false,
    this.borderColor,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        // With blur the fill can be lighter: the blurred aurora gives depth.
        color: blur
            ? const Color(0x99101017)
            : (strong ? Glass.bgStrong : Glass.bg),
        gradient: blur ? null : Glass.sheen,
        borderRadius: shape,
        border: Border.all(color: borderColor ?? Glass.border),
        boxShadow: shadow,
      ),
      child: DecoratedBox(
        // Inset top highlight (like `inset 0 1px 0 rgba(255,255,255,.06)`).
        decoration: BoxDecoration(
          borderRadius: shape,
          border: const Border(top: BorderSide(color: Glass.highlight)),
        ),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
    if (!blur) return decorated;
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(filter: Glass.blur, child: decorated),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GlassButton
// ─────────────────────────────────────────────────────────────────────────────

enum GlassButtonKind { primary, ghost, icon }

/// Primary (accent gradient, glows on hover), ghost (glass) or icon button.
/// Every variant shows a visible focus ring for keyboard users.
class GlassButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GlassButtonKind kind;
  final bool loading;
  final String? tooltip;
  final bool spinIcon;

  const GlassButton.primary({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  })  : kind = GlassButtonKind.primary,
        tooltip = null,
        spinIcon = false;

  const GlassButton.ghost({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  })  : kind = GlassButtonKind.ghost,
        tooltip = null,
        spinIcon = false;

  /// Square icon button; [spinIcon] spins the icon (e.g. while refreshing).
  const GlassButton.icon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.spinIcon = false,
  })  : kind = GlassButtonKind.icon,
        label = null,
        loading = false;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(GlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.spinIcon && !Glass.reduceMotion(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final primary = widget.kind == GlassButtonKind.primary;
    final isIcon = widget.kind == GlassButtonKind.icon;
    final radius = BorderRadius.circular(isIcon ? Glass.r10 : 12);
    final fg = primary ? Colors.white : Glass.text;

    Widget content;
    if (widget.loading) {
      content = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: fg),
      );
    } else if (isIcon) {
      content = RotationTransition(
        turns: _spin,
        child: Icon(widget.icon, size: 18, color: Glass.textSecondary),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 16, color: fg),
            const SizedBox(width: 8),
          ],
          Text(widget.label!, style: Glass.strong(color: fg)),
        ],
      );
    }

    final button = AnimatedContainer(
      duration: Glass.fast,
      height: isIcon ? 38 : 40,
      width: isIcon ? 38 : null,
      padding: isIcon ? null : const EdgeInsets.symmetric(horizontal: 16),
      // `alignment` would make the button fill all available width; center
      // with widthFactor 1 so it hugs its label instead.
      alignment: isIcon ? Alignment.center : null,
      decoration: BoxDecoration(
        gradient: primary ? Glass.accentGradient : null,
        color: primary ? null : (_hover ? Glass.bgHover : Glass.bgStrong),
        borderRadius: radius,
        border: Border.all(
          color: _focus
              ? Glass.accentA
              : primary
                  ? const Color(0x33FFFFFF)
                  : (_hover ? Glass.borderBright : Glass.border),
          width: _focus ? 1.6 : 1,
        ),
        boxShadow: primary && (_hover || _focus) && enabled ? Glass.glow() : null,
      ),
      child: isIcon ? content : Center(widthFactor: 1, child: content),
    );

    Widget result = Opacity(
      opacity: enabled || widget.loading ? 1 : 0.5,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? widget.onPressed : null,
          onHover: (h) => setState(() => _hover = h),
          onFocusChange: (f) => setState(() => _focus = f),
          child: button,
        ),
      ),
    );
    if (isIcon && widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return Semantics(button: true, label: widget.label ?? widget.tooltip, child: result);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pills and badges
// ─────────────────────────────────────────────────────────────────────────────

/// Small rounded label. [accent] gives the violet tint (tags, highlights).
class GlassPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool accent;

  /// Frosted white pill for use on colourful covers.
  final bool frosted;

  const GlassPill({
    super.key,
    required this.text,
    this.icon,
    this.accent = false,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = frosted
        ? const Color(0xFF1C1B22)
        : accent
            ? Glass.accentText
            : Glass.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: frosted
            ? const Color(0xCCFFFFFF)
            : accent
                ? const Color(0x268B5CF6)
                : Glass.bgStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: frosted
              ? const Color(0x66FFFFFF)
              : accent
                  ? const Color(0x408B5CF6)
                  : Glass.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
          ],
          Text(text, style: Glass.small(color: fg, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Gradient count badge that pulses gently while it has something to show.
class GlassBadge extends StatefulWidget {
  final int count;
  const GlassBadge({super.key, required this.count});

  @override
  State<GlassBadge> createState() => _GlassBadgeState();
}

class _GlassBadgeState extends State<GlassBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Glass.reduceMotion(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();
    final text = widget.count > 9 ? '9+' : '${widget.count}';
    return Semantics(
      label: '${widget.count} new',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: Glass.accentGradient,
            borderRadius: BorderRadius.circular(999),
            // Dark outline keeps the badge visible on the gradient active pill.
            border: Border.all(color: const Color(0xFF0B0B12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Glass.accentA.withValues(alpha: 0.25 + 0.35 * _pulse.value),
                blurRadius: 6 + 6 * _pulse.value,
              ),
            ],
          ),
          child: child,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: Glass.font,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented control
// ─────────────────────────────────────────────────────────────────────────────

/// Glass segmented control with a gradient background that slides to the
/// selected segment.
class GlassSegmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final double segmentWidth;

  const GlassSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.segmentWidth = 92,
  });

  @override
  Widget build(BuildContext context) {
    final index = math.max(0, values.indexOf(selected));
    return GlassPanel(
      radius: 12,
      strong: true,
      padding: const EdgeInsets.all(3),
      child: SizedBox(
        width: segmentWidth * values.length,
        height: 34,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Glass.reduceMotion(context) ? Duration.zero : Glass.ui,
              curve: Curves.easeOutCubic,
              left: index * segmentWidth,
              top: 0,
              bottom: 0,
              width: segmentWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: Glass.accentGradient,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: Glass.glow(0.6),
                ),
              ),
            ),
            Row(
              children: [
                for (final v in values)
                  SizedBox(
                    width: segmentWidth,
                    child: Semantics(
                      selected: v == selected,
                      button: true,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => onChanged(v),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Glass.fast,
                              style: Glass.small(
                                color: v == selected ? Colors.white : Glass.textSecondary,
                                weight: FontWeight.w600,
                              ),
                              child: Text(labelOf(v), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state & section header
// ─────────────────────────────────────────────────────────────────────────────

/// Centered glass panel with an icon in a gradient-ringed circle.
class GlassEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const GlassEmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Glass.accentGradient,
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF12121A),
                  ),
                  child: Icon(icon, size: 20, color: Glass.accentText),
                ),
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: Glass.strong()),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, textAlign: TextAlign.center, style: Glass.small()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase label with letter-spacing and a thin gradient divider.
class GlassSectionHeader extends StatelessWidget {
  final String text;
  const GlassSectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Text(text.toUpperCase(), style: Glass.label()),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x598B5CF6), Color(0x146366F1), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Motion helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Fades and rises its child in, [index] × 40 ms after it appears (staggered
/// lists). Shown immediately with reduced motion.
class GlassEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  const GlassEntrance({super.key, this.index = 0, required this.child});

  @override
  State<GlassEntrance> createState() => _GlassEntranceState();
}

class _GlassEntranceState extends State<GlassEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Glass.reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    Future<void>.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 12)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// A light sweep that crosses its child once (e.g. a highlighted stat).
/// Skipped with reduced motion.
class GlassShimmerOnce extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  const GlassShimmerOnce({super.key, required this.child, required this.borderRadius});

  @override
  State<GlassShimmerOnce> createState() => _GlassShimmerOnceState();
}

class _GlassShimmerOnceState extends State<GlassShimmerOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!Glass.reduceMotion(context)) {
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  if (_c.value == 0 || _c.isCompleted) return const SizedBox.shrink();
                  return FractionalTranslation(
                    translation: Offset(-1 + 2.2 * _c.value, 0),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x00FFFFFF), Color(0x2EFFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search field & selectable pills
// ─────────────────────────────────────────────────────────────────────────────

/// Glass search field: accent focus ring with a soft glow and an optional
/// keyboard hint on the right (visual only).
class GlassSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final String? shortcutHint;

  const GlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.shortcutHint,
  });

  @override
  State<GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<GlassSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: Glass.fast,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: focused ? Glass.bgStrong : Glass.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focused ? Glass.accentA : Glass.border, width: focused ? 1.4 : 1),
        boxShadow: focused ? Glass.glow(0.7) : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Glass.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              cursorColor: Glass.accentText,
              style: Glass.body(color: Glass.text),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: Glass.body(color: Glass.textMuted),
              ),
            ),
          ),
          if (widget.shortcutHint != null)
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Glass.borderBright),
                ),
                child: Text(widget.shortcutHint!, style: Glass.small(weight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A pill that can be selected (gradient when selected), for open-ended
/// filter lists such as tags.
class GlassChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const GlassChoicePill({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: Glass.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected ? Glass.accentGradient : null,
              color: selected ? null : Glass.bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? const Color(0x33FFFFFF) : Glass.border),
              boxShadow: selected ? Glass.glow(0.6) : null,
            ),
            child: Text(
              label,
              style: Glass.small(
                color: selected ? Colors.white : Glass.textSecondary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
