import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_colors.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/sticky_note.dart';
import '../friend_requests_screen.dart';

class FriendRequestBanner extends StatelessWidget {
  final int count;
  const FriendRequestBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.stickyInkFor(InkColors.stickyRose);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16, vertical: InkSpacing.s8),
      child: StickyNote(
        color: InkColors.stickyRose,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.users, color: ink, size: 22),
            const SizedBox(width: InkSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Friend Requests', style: InkType.bodyStrong(ink)),
                  Text(
                    'You have $count pending invitations',
                    style: InkType.caption(ink),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: ink, size: 18),
          ],
        ),
      ),
    );
  }
}
