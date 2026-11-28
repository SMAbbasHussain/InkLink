import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/paper_card.dart';
import 'web_page_layout.dart';

/// Shows a floating feedback banner at the bottom of the page.
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

/// Formats any thrown error object into a readable user-facing message.
String webErrorText(Object error) {
  if (error is String) return error;
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Builds a live list with loading, error, and empty states.
class WebStreamList<T> extends StatelessWidget {
  final Stream<List<T>> stream;
  final Widget Function(BuildContext context, List<T> items) builder;
  final IconData emptyIcon;
  final String emptyText;
  final String? emptySubtitle;

  /// Less vertical spacing around the empty state when embedded in a section.
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

/// Centered Desk-styled loading spinner.
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

/// Paper-card error alert used across web pages.
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

/// Decline / Accept action pair used by invites and friend requests.
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
