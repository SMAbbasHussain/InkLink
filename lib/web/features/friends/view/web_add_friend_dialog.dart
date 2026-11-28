import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/friends/friend.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../../core/web_formatters.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_friends_cubit.dart';

/// Looks up a user by exact email and sends a friend request.
Future<void> showAddFriendDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _AddFriendDialog(),
);

class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _email = TextEditingController();
  List<Friend>? _results;
  final _sent = <String>{};
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _email.text.trim();
    if (query.isEmpty || !query.contains('@')) {
      setState(() => _error = 'Enter the email address they signed up with.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await context.read<WebFriendsCubit>().searchUsersByEmail(
        query,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = webErrorText(e);
          _searching = false;
        });
      }
    }
  }

  Future<void> _send(Friend user) async {
    try {
      await context.read<WebFriendsCubit>().sendFriendRequest(user.uid);
      if (!mounted) return;
      setState(() => _sent.add(user.uid));
      showWebMessage(context, 'Request sent to ${user.displayName}.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final results = _results;
    return InkDialog(
      title: 'Add a friend',
      icon: LucideIcons.userPlus,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkTextField(
              controller: _email,
              labelText: 'Their email',
              hintText: 'name@example.com',
              errorText: _error,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              enabled: !_searching,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: InkSpacing.s12),
            Align(
              alignment: Alignment.centerRight,
              child: InkButton.primary(
                label: 'Search',
                compact: true,
                expand: false,
                isLoading: _searching,
                onPressed: _searching ? null : _search,
              ),
            ),
            if (results != null && results.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: InkSpacing.s12),
                child: Text(
                  'No InkLink account uses that email.',
                  style: InkType.body(tokens.inkSecondary),
                ),
              ),
            for (final user in results ?? const <Friend>[])
              Padding(
                padding: const EdgeInsets.only(top: InkSpacing.s12),
                child: Row(
                  children: [
                    InkAvatar(
                      imageUrl: user.photoURL,
                      initials: initialsOf(user.displayName),
                      id: user.uid,
                      size: 40,
                    ),
                    const SizedBox(width: InkSpacing.s12),
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: InkType.bodyStrong(tokens.ink),
                      ),
                    ),
                    _sent.contains(user.uid)
                        ? Text(
                            'Requested',
                            style: InkType.caption(tokens.inkMuted),
                          )
                        : InkButton.secondary(
                            label: 'Send request',
                            compact: true,
                            expand: false,
                            onPressed: () => _send(user),
                          ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Close',
          compact: true,
          expand: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
