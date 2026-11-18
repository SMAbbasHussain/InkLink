import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_type.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';

/// Shows a short message at the bottom of the page (works in the glass
/// shell and on the sign-in screen).
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
        backgroundColor: isError ? ink.danger : null,
        content: Text(
          message,
          style: isError ? InkType.body(Colors.white) : Glass.body(color: Glass.text),
        ),
      ),
    );
}

/// Turns any thrown value into a readable message.
String webErrorText(Object error) {
  if (error is String) return error;
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Page title (40px, tight tracking) with an optional subtitle and action.
class WebPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const WebPageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: Glass.title())),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: Glass.body(color: Glass.textMuted)),
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

/// "Nothing here" state: a centered glass panel with an icon in a
/// gradient-ringed circle.
class WebEmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  const WebEmptyHint({super.key, required this.icon, required this.text, this.subtitle});

  @override
  Widget build(BuildContext context) =>
      GlassEmptyState(icon: icon, title: text, subtitle: subtitle);
}

/// Section label: uppercase with letter-spacing and a gradient divider.
class WebSectionLabel extends StatelessWidget {
  final String text;
  const WebSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => GlassSectionHeader(text);
}

/// Builds a live list with loading, error and empty states.
class WebStreamList<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, List<T> items) builder;
  final IconData emptyIcon;
  final String emptyText;
  final String? emptySubtitle;

  /// Kept for compatibility: both sizes now use the glass empty state, with
  /// more breathing room when the whole page is this list.
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
            padding: EdgeInsets.all(32),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Glass.accentText),
              ),
            ),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: compactEmpty ? 4 : 32),
            child: GlassEmptyState(icon: emptyIcon, title: emptyText, subtitle: emptySubtitle),
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
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderColor: Glass.danger.withValues(alpha: 0.35),
      child: Row(
        children: [
          const Icon(LucideIcons.triangleAlert, color: Glass.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: Glass.body(color: Glass.danger))),
        ],
      ),
    );
  }
}

/// Details for a board, with links that open it in the phone app.
Future<void> showOpenInAppDialog(BuildContext context, Board board) {
  final link = boardAppLink(board.id);
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassPanel(
          blur: true,
          radius: Glass.r20,
          shadow: Glass.shadowLifted,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(board.title, style: Glass.heading(size: 22)),
              const SizedBox(height: 8),
              Text(
                'Drawing and editing happen in the InkLink mobile app. '
                'Open this link on your phone to jump straight into the board.',
                style: Glass.body(),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                strong: true,
                radius: 12,
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(child: SelectableText(link, style: Glass.body(color: Glass.text))),
                    GlassButton.icon(
                      icon: LucideIcons.copy,
                      tooltip: 'Copy link',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (dialogContext.mounted) showWebMessage(dialogContext, 'Link copied');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GlassPill(
                    icon: LucideIcons.users,
                    text: '${board.membersCount} ${board.membersCount == 1 ? 'member' : 'members'}',
                  ),
                  GlassPill(
                    icon: board.visibility == 'public' ? LucideIcons.globe : LucideIcons.lock,
                    text: board.visibility == 'public' ? 'Public' : 'Private',
                  ),
                  if (board.isArchived) const GlassPill(icon: LucideIcons.archive, text: 'Archived'),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: GlassButton.ghost(
                  label: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Accept (gradient, glows on hover) / Decline (ghost glass) pair used by
/// invites and friend requests.
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
        GlassButton.ghost(
          label: 'Decline',
          onPressed: _busy ? null : () => _run(widget.onDecline, widget.declinedMessage),
        ),
        const SizedBox(width: 8),
        GlassButton.primary(
          label: 'Accept',
          loading: _busy,
          onPressed: _busy ? null : () => _run(widget.onAccept, widget.acceptedMessage),
        ),
      ],
    );
  }
}

/// How the companion opens a board. The web app opens the mobile canvas;
/// preview mode and tests (no Firebase) show the "open in the app" details.
class WebBoardOpener {
  final void Function(BuildContext context, Board board) open;

  const WebBoardOpener(this.open);

  /// The details dialog with links to the phone app.
  static final WebBoardOpener appLinks = WebBoardOpener(
    (context, board) => showOpenInAppDialog(context, board),
  );
}
