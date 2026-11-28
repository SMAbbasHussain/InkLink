import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/models/board.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../core/web_stream_utils.dart';
import 'web_feedback_widgets.dart';

/// Strategy for opening a board from the web companion.
///
/// The production web entry point (`main_web.dart`) pushes the shared canvas
/// route; callers without a canvas host fall back to [appLinks].
class WebBoardOpener {
  final void Function(BuildContext context, Board board) open;

  /// Opens a board from its id alone (used by `/board/<id>` deep links).
  final void Function(BuildContext context, String boardId)? openId;

  const WebBoardOpener(this.open, {this.openId});

  /// Fallback dialog displaying the deep link to open the board on mobile.
  static final WebBoardOpener appLinks = WebBoardOpener(
    (context, board) => showOpenInAppDialog(context, board),
  );
}

/// Shows deep-link details to open [board] in the InkLink mobile app.
Future<void> showOpenInAppDialog(BuildContext context, Board board) {
  final link = boardAppLink(board.id);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final tokens = dialogContext.ink;
      return InkDialog(
        title: board.title,
        icon: LucideIcons.layoutGrid,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open this link on your phone to jump straight into the board.',
              style: InkType.body(tokens.inkSecondary),
            ),
            const SizedBox(height: InkSpacing.s12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: tokens.field,
                borderRadius: BorderRadius.circular(InkRadii.input),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      link,
                      style: InkType.body(tokens.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy link',
                    icon: Icon(LucideIcons.copy, size: 18, color: tokens.ink),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (dialogContext.mounted) {
                        showWebMessage(dialogContext, 'Link copied');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: InkSpacing.s12),
            Text(
              '${board.membersCount} '
              '${board.membersCount == 1 ? 'member' : 'members'} · '
              '${board.visibility == 'public' ? 'Public' : 'Private'}'
              '${board.isArchived ? ' · Archived' : ''}',
              style: InkType.caption(tokens.inkMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
