import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/ink_button.dart';
import '../data/web_mappers.dart';

/// Shows a short message at the bottom of the page.
void showWebMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final ink = context.ink;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 420,
        backgroundColor: isError ? ink.danger : ink.ink,
        content: Text(message, style: InkType.body(ink.paper)),
      ),
    );
}

/// Turns any thrown value into a readable message.
String webErrorText(Object error) {
  if (error is String) return error;
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Page title row used at the top of every section.
class WebPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: InkType.headline(ink.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: InkSpacing.s4),
                  Text(subtitle!, style: InkType.body(ink.inkSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Keeps lists and forms at a readable width, aligned with the page title,
/// instead of stretching across very wide screens.
class WebReadableWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const WebReadableWidth({super.key, this.maxWidth = 760, required this.child});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Compact "nothing here" line, so empty sections don't push real content
/// out of view.
class WebEmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  const WebEmptyHint({
    super.key,
    required this.icon,
    required this.text,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s16,
        vertical: InkSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: ink.paper.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ink.glassStroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ink.inkMuted),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: InkType.body(ink.inkSecondary)),
                if (subtitle != null)
                  Text(subtitle!, style: InkType.caption(ink.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small section label inside a page.
class WebSectionLabel extends StatelessWidget {
  final String text;
  const WebSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: InkSpacing.s16, bottom: InkSpacing.s8),
    child: Text(text.toUpperCase(), style: InkType.label(context.ink.inkMuted)),
  );
}

/// Builds a live list with loading, error and empty states.
class WebStreamList<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, List<T> items) builder;
  final IconData emptyIcon;
  final String emptyText;
  final String? emptySubtitle;

  /// Sections inside a page use a one-line hint; a page that is entirely
  /// this list can use the large sticky-note empty state instead.
  final bool compactEmpty;

  const WebStreamList({
    super.key,
    required this.stream,
    required this.builder,
    required this.emptyIcon,
    required this.emptyText,
    this.emptySubtitle,
    this.compactEmpty = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return WebErrorBox(message: webErrorText(snapshot.error!));
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(InkSpacing.s32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          if (compactEmpty) {
            return WebEmptyHint(
              icon: emptyIcon,
              text: emptyText,
              subtitle: emptySubtitle,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.s24),
            child: EmptyState(
              icon: emptyIcon,
              text: emptyText,
              subtitle: emptySubtitle,
            ),
          );
        }
        return builder(context, items);
      },
    );
  }
}

class WebErrorBox extends StatelessWidget {
  final String message;
  const WebErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Padding(
      padding: const EdgeInsets.all(InkSpacing.s16),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, color: ink.danger, size: 18),
          const SizedBox(width: InkSpacing.s8),
          Expanded(child: Text(message, style: InkType.body(ink.danger))),
        ],
      ),
    );
  }
}

/// Details for a board, with links that open it in the phone app.
Future<void> showOpenInAppDialog(BuildContext context, Board board) {
  final ink = context.ink;
  final link = boardAppLink(board.id);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: ink.paper,
      title: Text(board.title, style: InkType.title(ink.ink)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drawing and editing happen in the InkLink mobile app. '
              'Open this link on your phone to jump straight into the board.',
              style: InkType.body(ink.inkSecondary),
            ),
            const SizedBox(height: InkSpacing.s16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ink.field,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ink.glassStroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(link, style: InkType.body(ink.ink)),
                  ),
                  IconButton(
                    tooltip: 'Copy link',
                    icon: Icon(
                      LucideIcons.copy,
                      size: 18,
                      color: ink.inkSecondary,
                    ),
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
              '${board.membersCount} ${board.membersCount == 1 ? 'member' : 'members'}'
              ' · ${board.visibility == 'public' ? 'Public' : 'Private'}'
              '${board.isArchived ? ' · Archived' : ''}',
              style: InkType.caption(ink.inkMuted),
            ),
          ],
        ),
      ),
      actions: [
        InkButton(
          label: 'Close',
          expand: false,
          compact: true,
          variant: InkButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// Accept / Decline pair used by invites and friend requests.
class WebAcceptDecline extends StatefulWidget {
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final String acceptedMessage;
  final String declinedMessage;

  const WebAcceptDecline({
    super.key,
    required this.onAccept,
    required this.onDecline,
    required this.acceptedMessage,
    required this.declinedMessage,
  });

  @override
  State<WebAcceptDecline> createState() => _WebAcceptDeclineState();
}

class _WebAcceptDeclineState extends State<WebAcceptDecline> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showWebMessage(context, doneMessage);
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkButton(
          label: 'Decline',
          expand: false,
          compact: true,
          variant: InkButtonVariant.secondary,
          onPressed: _busy
              ? null
              : () => _run(widget.onDecline, widget.declinedMessage),
        ),
        const SizedBox(width: InkSpacing.s8),
        InkButton(
          label: 'Accept',
          expand: false,
          compact: true,
          isLoading: _busy,
          onPressed: _busy
              ? null
              : () => _run(widget.onAccept, widget.acceptedMessage),
        ),
      ],
    );
  }
}
