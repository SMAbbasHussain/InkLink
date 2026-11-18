import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/empty_state.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_dialog.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_mappers.dart';

// Shared pieces of the web companion, built from the mobile app's Ink design
// system (lib/ui) so the web looks like the phone.

/// Shows a short message at the bottom of the page, like the phone's
/// snackbars.
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
        content: Text(
          message,
          style: InkType.body(isError ? Colors.white : ink.paper),
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

/// Page title with an optional subtitle and action (the phone's screen
/// title style).
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
    final tokens = context.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: InkType.headline(tokens.ink)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: InkSpacing.s4),
                  Text(subtitle!, style: InkType.body(tokens.inkSecondary)),
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

/// Keeps lists and forms at a readable width instead of stretching across
/// very wide screens.
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

/// "Nothing here": the phone's sticky-note empty state.
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: InkSpacing.s16),
    child: EmptyState(icon: icon, text: text, subtitle: subtitle),
  );
}

/// Small section label above a group of items.
class WebSectionLabel extends StatelessWidget {
  final String text;
  const WebSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: InkSpacing.s8, bottom: InkSpacing.s12),
    child: Text(text, style: InkType.subhead(context.ink.inkSecondary)),
  );
}

/// Builds a live list with loading, error and empty states.
class WebStreamList<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, List<T> items) builder;
  final IconData emptyIcon;
  final String emptyText;
  final String? emptySubtitle;

  /// Less room around the empty state when the list is one of several.
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
        if (!snapshot.hasData) return const WebLoading();
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: compactEmpty ? 0 : InkSpacing.s24,
            ),
            child: WebEmptyHint(
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

/// The phone's loading spinner, centred.
class WebLoading extends StatelessWidget {
  const WebLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(InkSpacing.s32),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: context.ink.accent,
        ),
      ),
    ),
  );
}

class WebErrorBox extends StatelessWidget {
  final String message;
  const WebErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return PaperCard(
      padding: const EdgeInsets.all(InkSpacing.s16),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, color: tokens.danger, size: 18),
          const SizedBox(width: InkSpacing.s12),
          Expanded(child: Text(message, style: InkType.body(tokens.danger))),
        ],
      ),
    );
  }
}

/// Details for a board, with links that open it in the phone app (preview
/// mode and tests; the real web app opens the canvas instead).
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

/// Decline / Accept pair used by invites and friend requests (the phone's
/// secondary and primary buttons).
class WebAcceptDecline extends StatefulWidget {
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;
  final String acceptedMessage;
  final String declinedMessage;

  /// Fill the available width (sticky-note invites), or stay compact.
  final bool expand;

  const WebAcceptDecline({
    super.key,
    required this.onAccept,
    required this.onDecline,
    required this.acceptedMessage,
    required this.declinedMessage,
    this.expand = false,
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
    final decline = InkButton.secondary(
      label: 'Decline',
      expand: widget.expand,
      compact: !widget.expand,
      onPressed: _busy
          ? null
          : () => _run(widget.onDecline, widget.declinedMessage),
    );
    final accept = InkButton.primary(
      label: 'Accept',
      expand: widget.expand,
      compact: !widget.expand,
      isLoading: _busy,
      onPressed: _busy
          ? null
          : () => _run(widget.onAccept, widget.acceptedMessage),
    );
    return Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: widget.expand
          ? [
              Expanded(child: decline),
              const SizedBox(width: InkSpacing.s12),
              Expanded(child: accept),
            ]
          : [decline, const SizedBox(width: InkSpacing.s8), accept],
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

/// Search box in the mobile app's style (white or paper field, soft border),
/// for page headers.
class WebSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const WebSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InkRadii.input),
      borderSide: BorderSide(color: tokens.glassStroke),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: InkType.body(tokens.ink),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: InkType.body(tokens.inkMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 18,
          color: tokens.inkSecondary,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    LucideIcons.x,
                    size: 16,
                    color: tokens.inkSecondary,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: tokens.isDark ? tokens.paper : Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
      ),
    );
  }
}
