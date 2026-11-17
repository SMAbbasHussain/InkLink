import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_colors.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';

/// Pastel "paper" colours for board covers (the sticky-note palette).
const _coverColors = <Color>[
  InkColors.stickyButter,
  InkColors.stickyMint,
  InkColors.stickySky,
  InkColors.stickyLilac,
  InkColors.stickyRose,
  InkColors.stickyPeach,
];

/// Stable hash of a board id, so a board always gets the same cover while
/// similar ids ("b1", "b2", …) still get different colours. Kept to small
/// numbers so it gives identical results on the web (JS numbers) and the VM.
int _stableHash(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) % 1000003;
  }
  return h;
}

/// A board card: pastel doodle cover (with a soft vignette) over a dark
/// fake-glass body. No backdrop blur (cards are many; blur is expensive).
/// Hover: lifts 4px, border brightens, a spotlight follows the cursor and the
/// cover zooms slightly. Keyboard focusable with a visible focus ring.
class WebBoardCard extends StatefulWidget {
  final Board board;

  /// "Owner", "Member" or "Public" (see [boardRoleLabel]).
  final String roleLabel;
  final VoidCallback onTap;

  const WebBoardCard({
    super.key,
    required this.board,
    required this.roleLabel,
    required this.onTap,
  });

  @override
  State<WebBoardCard> createState() => _WebBoardCardState();
}

class _WebBoardCardState extends State<WebBoardCard> {
  bool _hover = false;
  bool _focus = false;
  Offset? _pointer;

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final hash = _stableHash(board.id);
    final cover = _coverColors[hash % _coverColors.length];
    final isPublic = board.visibility == 'public';
    final reduce = Glass.reduceMotion(context);
    final active = _hover || _focus;
    const radius = BorderRadius.all(Radius.circular(Glass.r20));

    return Semantics(
      button: true,
      label: '${board.title}, ${widget.roleLabel}, '
          '${isPublic ? 'public' : 'private'}, ${board.membersCount} '
          '${board.membersCount == 1 ? 'member' : 'members'}, '
          'updated ${timeAgo(board.updatedAt)}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _pointer = null;
        }),
        onHover: reduce ? null : (e) => setState(() => _pointer = e.localPosition),
        child: AnimatedContainer(
          duration: Glass.fast,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E15),
            gradient: Glass.sheen,
            borderRadius: radius,
            border: Border.all(
              color: _focus
                  ? Glass.accentA
                  : active
                      ? Glass.borderBright
                      : Glass.border,
              width: _focus ? 1.6 : 1,
            ),
            boxShadow: active ? Glass.shadowLifted : Glass.shadow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                onFocusChange: (f) => setState(() => _focus = f),
                child: Opacity(
                  opacity: board.isArchived ? 0.6 : 1,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Cover(
                            color: cover,
                            seed: hash,
                            zoomed: active && !reduce,
                            isPublic: isPublic,
                            roleLabel: board.isArchived ? 'Archived' : widget.roleLabel,
                          ),
                          _Body(board: board, active: active),
                        ],
                      ),
                      // Spotlight that follows the cursor.
                      if (_pointer != null && _hover)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: LayoutBuilder(
                              builder: (context, c) => DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(
                                      (_pointer!.dx / c.maxWidth) * 2 - 1,
                                      (_pointer!.dy / c.maxHeight) * 2 - 1,
                                    ),
                                    radius: 0.9,
                                    colors: const [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final Color color;
  final int seed;
  final bool zoomed;
  final bool isPublic;
  final String roleLabel;

  const _Cover({
    required this.color,
    required this.seed,
    required this.zoomed,
    required this.isPublic,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: AnimatedScale(
              duration: Glass.ui,
              curve: Curves.easeOutCubic,
              scale: zoomed ? 1.03 : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: color),
                  CustomPaint(painter: _DoodlePainter(seed: seed, color: color)),
                  // Soft inner vignette so the cover sits into the dark card.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.1,
                        colors: [Color(0x00000000), Color(0x40000000)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x33000000)],
                        stops: [0.6, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: GlassPill(
              frosted: true,
              icon: isPublic ? LucideIcons.globe : LucideIcons.lock,
              text: isPublic ? 'Public' : 'Private',
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: GlassPill(
              frosted: true,
              icon: switch (roleLabel) {
                'Owner' => LucideIcons.crown,
                'Member' => LucideIcons.userCheck,
                'Archived' => LucideIcons.archive,
                _ => LucideIcons.eye,
              },
              text: roleLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Board board;
  final bool active;
  const _Body({required this.board, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  board.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Glass.heading(size: 16),
                ),
              ),
              AnimatedOpacity(
                duration: Glass.fast,
                opacity: active ? 1 : 0,
                child: const Icon(LucideIcons.arrowUpRight, size: 18, color: Glass.accentText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Fact(icon: LucideIcons.users, text: '${board.membersCount}'),
              const SizedBox(width: 14),
              Flexible(child: _Fact(icon: LucideIcons.clock, text: timeAgo(board.updatedAt))),
            ],
          ),
          if (board.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in board.tags.take(3)) GlassPill(text: '#$tag', accent: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Glass.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text, overflow: TextOverflow.ellipsis, style: Glass.small(color: Glass.textSecondary)),
        ),
      ],
    );
  }
}

/// A few hand-drawn-looking strokes and a shape, generated from the board id
/// so every board has its own recognisable cover.
class _DoodlePainter extends CustomPainter {
  final int seed;
  final Color color;
  _DoodlePainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final ink = Color.lerp(color, Colors.black, 0.45)!;
    final soft = Color.lerp(color, Colors.white, 0.35)!;
    final w = size.width, h = size.height;

    // Dot grid, like the desk.
    final dot = Paint()..color = ink.withValues(alpha: 0.10);
    for (double x = 10; x < w; x += 16) {
      for (double y = 8; y < h; y += 16) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }

    // Two flowing strokes.
    for (var i = 0; i < 2; i++) {
      final y0 = h * (0.45 + rnd.nextDouble() * 0.35);
      final path = Path()..moveTo(w * 0.06, y0);
      path.cubicTo(
        w * (0.25 + rnd.nextDouble() * 0.15), h * (0.15 + rnd.nextDouble() * 0.7),
        w * (0.55 + rnd.nextDouble() * 0.15), h * (0.15 + rnd.nextDouble() * 0.7),
        w * (0.62 + rnd.nextDouble() * 0.3), h * (0.35 + rnd.nextDouble() * 0.5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = (i == 0 ? ink : ink.withValues(alpha: 0.45))
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 3 : 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // One shape: circle, rounded square or triangle.
    final cx = w * (0.62 + rnd.nextDouble() * 0.25);
    final cy = h * (0.35 + rnd.nextDouble() * 0.35);
    final r = 12 + rnd.nextDouble() * 10;
    final fill = Paint()..color = soft.withValues(alpha: 0.9);
    final stroke = Paint()
      ..color = ink.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    switch (rnd.nextInt(3)) {
      case 0:
        canvas.drawCircle(Offset(cx, cy), r, fill);
        canvas.drawCircle(Offset(cx, cy), r, stroke);
      case 1:
        final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
            const Radius.circular(5));
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, stroke);
      default:
        final tri = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy + r * 0.8)
          ..lineTo(cx - r, cy + r * 0.8)
          ..close();
        canvas.drawPath(tri, fill);
        canvas.drawPath(tri, stroke);
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.seed != seed || old.color != color;
}

/// Responsive grid of board cards with a staggered entrance (40 ms apart).
class WebBoardGrid extends StatelessWidget {
  final List<Board> boards;
  final String? currentUid;
  final ValueChanged<Board> onOpen;

  /// True for the user's own board list, where every board is owned or
  /// joined. False for public boards, which the user may not belong to.
  final bool allJoined;

  const WebBoardGrid({
    super.key,
    required this.boards,
    required this.currentUid,
    required this.onOpen,
    this.allJoined = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 280).floor().clamp(1, 4);
        const gap = 20.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < boards.length; i++)
              SizedBox(
                key: ValueKey(boards[i].id),
                width: width,
                child: GlassEntrance(
                  index: i,
                  child: WebBoardCard(
                    board: boards[i],
                    roleLabel: boardRoleLabel(
                      ownerId: boards[i].ownerId,
                      memberIds: boards[i].members,
                      currentUid: currentUid,
                      knownMember: allJoined,
                    ),
                    onTap: () => onOpen(boards[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
