import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_colors.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../data/web_mappers.dart';

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

/// A board as a little sheet of paper: a doodle cover in a colour unique to
/// the board, then title, facts and tags. Lifts on hover; keyboard focusable.
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

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final board = widget.board;
    final hash = _stableHash(board.id);
    final cover = _coverColors[hash % _coverColors.length];
    final isPublic = board.visibility == 'public';
    final lifted = _hover;

    return Semantics(
      button: true,
      label: '${board.title}, ${widget.roleLabel}, ${board.membersCount} '
          '${board.membersCount == 1 ? 'member' : 'members'}, '
          'updated ${timeAgo(board.updatedAt)}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          offset: lifted ? const Offset(0, -0.015) : Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: ink.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: lifted ? ink.accent.withValues(alpha: 0.55) : ink.glassStroke,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: lifted ? 0.22 : 0.10),
                  blurRadius: lifted ? 24 : 10,
                  offset: Offset(0, lifted ? 10 : 4),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap,
                onFocusChange: (f) => setState(() => _hover = f),
                child: Opacity(
                  opacity: board.isArchived ? 0.6 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cover
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: SizedBox(
                          height: 104,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: cover),
                              CustomPaint(painter: _DoodlePainter(seed: hash, color: cover)),
                              Positioned(
                                left: 12,
                                top: 12,
                                child: _CoverPill(
                                  icon: isPublic ? LucideIcons.globe : LucideIcons.lock,
                                  text: isPublic ? 'Public' : 'Private',
                                ),
                              ),
                              Positioned(
                                right: 12,
                                top: 12,
                                child: _CoverPill(
                                  icon: switch (widget.roleLabel) {
                                    'Owner' => LucideIcons.crown,
                                    'Member' => LucideIcons.userCheck,
                                    _ => LucideIcons.eye,
                                  },
                                  text: board.isArchived ? 'Archived' : widget.roleLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Body
                      Padding(
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
                                    style: InkType.cardTitle(ink.ink),
                                  ),
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: lifted ? 1 : 0,
                                  child: Icon(LucideIcons.arrowUpRight,
                                      size: 18, color: ink.accentText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _Fact(
                                  icon: LucideIcons.users,
                                  text: '${board.membersCount}',
                                ),
                                const SizedBox(width: 14),
                                Flexible(
                                  child: _Fact(
                                    icon: LucideIcons.clock,
                                    text: timeAgo(board.updatedAt),
                                  ),
                                ),
                              ],
                            ),
                            if (board.tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final tag in board.tags.take(3))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ink.accentSoft,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text('#$tag',
                                          style: InkType.caption(ink.accentText)),
                                    ),
                                ],
                              ),
                            ],
                          ],
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

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Fact({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ink.inkMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis, style: InkType.caption(ink.inkSecondary)),
        ),
      ],
    );
  }
}

/// White frosted label on the coloured cover (same in light and dark).
class _CoverPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CoverPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    const fg = InkColors.stickyInkDefault;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text, style: InkType.caption(fg).copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
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

/// Responsive grid of board cards.
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
        const gap = InkSpacing.s20;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final board in boards)
              SizedBox(
                width: width,
                child: WebBoardCard(
                  board: board,
                  roleLabel: boardRoleLabel(
                    ownerId: board.ownerId,
                    memberIds: board.members,
                    currentUid: currentUid,
                    knownMember: allJoined,
                  ),
                  onTap: () => onOpen(board),
                ),
              ),
          ],
        );
      },
    );
  }
}
