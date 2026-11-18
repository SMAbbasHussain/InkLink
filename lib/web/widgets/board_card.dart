import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';

/// One accent hue per board (picked from its id), used only as a tint on a
/// dark cover so every card stays calm and on-theme.
const _hues = <Color>[
  Color(0xFF8B5CF6), // violet
  Color(0xFF6366F1), // indigo
  Color(0xFF38BDF8), // sky
  Color(0xFF2DD4BF), // teal
  Color(0xFFF472B6), // rose
  Color(0xFFF59E0B), // amber
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

/// First letter of a board title for the cover monogram.
String _monogram(String title) {
  final t = title.trim();
  return t.isEmpty ? '#' : t.characters.first.toUpperCase();
}

/// A board card: a dark cover tinted with the board's hue (soft glowing orb,
/// one ink stroke, the title's first letter) over a dark fake-glass body.
/// No backdrop blur (cards are many; blur is expensive). Every card has the
/// same height, with or without tags.
///
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
    final hue = _hues[hash % _hues.length];
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
                      ? hue.withValues(alpha: 0.45)
                      : Glass.border,
              width: _focus ? 1.6 : 1,
            ),
            boxShadow: active
                ? [
                    ...Glass.shadowLifted,
                    BoxShadow(color: hue.withValues(alpha: 0.18), blurRadius: 30),
                  ]
                : Glass.shadow,
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
                            hue: hue,
                            seed: hash,
                            monogram: _monogram(board.title),
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
                                    colors: const [Color(0x14FFFFFF), Color(0x00FFFFFF)],
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
  final Color hue;
  final int seed;
  final String monogram;
  final bool zoomed;
  final bool isPublic;
  final String roleLabel;

  const _Cover({
    required this.hue,
    required this.seed,
    required this.monogram,
    required this.zoomed,
    required this.isPublic,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: AnimatedScale(
              duration: Glass.ui,
              curve: Curves.easeOutCubic,
              scale: zoomed ? 1.03 : 1,
              child: CustomPaint(painter: _CoverPainter(hue: hue, seed: seed)),
            ),
          ),
          // Monogram: the title's first letter, large and quiet.
          Positioned(
            left: 16,
            bottom: 6,
            child: ExcludeSemantics(
              child: Text(
                monogram,
                style: TextStyle(
                  fontFamily: Glass.font,
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.5,
                  color: Colors.white.withValues(alpha: 0.88),
                  shadows: [Shadow(color: hue.withValues(alpha: 0.6), blurRadius: 18)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CoverTag(
                  icon: isPublic ? LucideIcons.globe : LucideIcons.lock,
                  text: isPublic ? 'Public' : 'Private',
                ),
                const SizedBox(width: 6),
                _CoverTag(
                  icon: switch (roleLabel) {
                    'Owner' => LucideIcons.crown,
                    'Member' => LucideIcons.userCheck,
                    'Archived' => LucideIcons.archive,
                    _ => LucideIcons.eye,
                  },
                  text: roleLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark translucent label that sits on the cover in both light and dark.
class _CoverTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CoverTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xD9FFFFFF)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: Glass.font,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xE6FFFFFF),
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
          const SizedBox(height: 12),
          // Fixed-height tag row so every card in a row has the same height.
          SizedBox(
            height: 26,
            child: board.tags.isEmpty
                ? null
                : ClipRect(
                    child: Wrap(
                      spacing: 6,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (final tag in board.tags.take(3)) GlassPill(text: '#$tag', accent: true),
                      ],
                    ),
                  ),
          ),
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

/// Dark cover tinted with the board's hue: a soft glowing orb, a faint dot
/// grid and one smooth ink stroke with a glow. Generated from the board id,
/// so each board keeps its own look.
class _CoverPainter extends CustomPainter {
  final Color hue;
  final int seed;
  _CoverPainter({required this.hue, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Base: deep dark with a gentle hue tint.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF101018), hue, 0.22)!,
            const Color(0xFF0D0D14),
          ],
        ).createShader(rect),
    );

    // Glowing orb.
    final orb = Offset(w * (0.62 + rnd.nextDouble() * 0.25), h * (0.15 + rnd.nextDouble() * 0.3));
    final orbR = h * (0.9 + rnd.nextDouble() * 0.4);
    canvas.drawCircle(
      orb,
      orbR,
      Paint()
        ..shader = RadialGradient(
          colors: [hue.withValues(alpha: 0.42), hue.withValues(alpha: 0.10), hue.withValues(alpha: 0)],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: orb, radius: orbR)),
    );

    // Faint dot grid.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (double x = 10; x < w; x += 16) {
      for (double y = 8; y < h; y += 16) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }

    // One smooth ink stroke with a soft glow.
    final y0 = h * (0.55 + rnd.nextDouble() * 0.25);
    final path = Path()
      ..moveTo(w * 0.30, y0)
      ..cubicTo(
        w * (0.45 + rnd.nextDouble() * 0.1), h * (0.15 + rnd.nextDouble() * 0.5),
        w * (0.65 + rnd.nextDouble() * 0.1), h * (0.5 + rnd.nextDouble() * 0.4),
        w * 1.02, h * (0.25 + rnd.nextDouble() * 0.4),
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = hue.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(hue, Colors.white, 0.35)!.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Bottom fade into the card body.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x59000000)],
          stops: [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.seed != seed || old.hue != hue;
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
        final columns = (constraints.maxWidth / 270).floor().clamp(1, 4);
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
