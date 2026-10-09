import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_initials.dart';
import '../../../../ui/widgets/paper_card.dart';

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool isAccepting;
  final bool isDeclining;

  const RequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
    this.isAccepting = false,
    this.isDeclining = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final senderName = request['senderName'] ?? "Collaborator";

    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s16),
      child: PaperCard(
        padding: const EdgeInsets.all(InkSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkAvatar(
                  imageUrl: request['senderPic'],
                  initials: inkInitialsFor(senderName),
                  id: request['fromUid']?.toString() ?? '',
                  size: 52,
                  online: true,
                ),
                const SizedBox(width: InkSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(senderName, style: InkType.title(tokens.ink)),
                      Text(
                        "Sent you a friend request",
                        style: InkType.caption(tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: InkSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: InkButton.primary(
                    label: isAccepting ? "Accepting..." : "Accept",
                    compact: true,
                    icon: isAccepting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.check),
                    onPressed: isAccepting || isDeclining ? null : onAccept,
                  ),
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: InkButton.secondary(
                    label: isDeclining ? "Declining..." : "Decline",
                    compact: true,
                    icon: isDeclining
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: tokens.ink,
                            ),
                          )
                        : const Icon(LucideIcons.x),
                    onPressed: isAccepting || isDeclining ? null : onDecline,
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
