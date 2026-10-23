import 'package:flutter/material.dart';

import '../theme/ink_colors.dart';
import '../theme/ink_theme.dart';
import '../theme/ink_type.dart';

/// A circular avatar with an optional accent ring, image/initials fallback
/// and an optional presence dot.
class InkAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final String id;
  final double size;
  final bool ring;
  final bool? online;

  const InkAvatar({
    super.key,
    this.imageUrl,
    required this.initials,
    required this.id,
    this.size = 40,
    this.ring = false,
    this.online,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final fallbackColor = tokens.stickyForId(id);

    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: tokens.accentSoft,
      foregroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? NetworkImage(imageUrl!)
          : null,
      child: Text(
        initials,
        style: InkType.bodyStrong(tokens.accentText).copyWith(
          fontSize: size * 0.38,
        ),
      ),
    );

    // Deterministic sticky-pastel fallback for avatars with no accent ring
    // request (e.g. collaborator lists), matching the Phase 1 fallback rule.
    if (!ring) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: fallbackColor,
        foregroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? NetworkImage(imageUrl!)
            : null,
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: InkType.geistFamily,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.38,
            color: InkColors.stickyInkDefault,
          ),
        ),
      );
    }

    Widget framed = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.surfaceDesk,
        border: ring ? Border.all(color: tokens.accent, width: 1.5) : null,
      ),
      child: avatar,
    );

    if (online == null) return framed;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        framed,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online! ? tokens.success : tokens.inkMuted,
              border: Border.all(color: tokens.surfaceDesk, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
