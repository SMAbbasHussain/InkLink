import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../domain/services/board/board_rules.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_boards_cubit.dart';
import 'web_board_settings_dialogs.dart';

/// Creates a board from the browser with mobile's default privacy settings.
Future<void> showCreateBoardDialog(BuildContext context) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => const _CreateBoardDialog(),
  );
  if (created == true && context.mounted) {
    showWebMessage(context, 'Board created.');
  }
}

class _CreateBoardDialog extends StatefulWidget {
  const _CreateBoardDialog();

  @override
  State<_CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends State<_CreateBoardDialog> {
  final _name = TextEditingController();
  String _visibility = Board.visibilityPrivate;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final error = validateBoardName(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WebBoardsCubit>().createBoard(
        name: _name.text,
        visibility: _visibility,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = webErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkDialog(
      title: 'New board',
      icon: LucideIcons.plus,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkTextField(
              controller: _name,
              labelText: 'Board name',
              hintText: 'e.g. Q4 planning',
              errorText: _error,
              autofocus: true,
              enabled: !_saving,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: InkSpacing.s12),
            Text('Who can see it', style: InkType.caption(tokens.inkMuted)),
            const SizedBox(height: InkSpacing.s8),
            WebDialogChoiceRow(
              options: const {
                Board.visibilityPrivate: 'Private',
                Board.visibilityPublic: 'Public',
              },
              selected: _visibility,
              onChanged: (value) => setState(() => _visibility = value),
            ),
          ],
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          expand: false,
          compact: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        InkButton.primary(
          label: 'Create',
          expand: false,
          compact: true,
          isLoading: _saving,
          onPressed: _saving ? null : _create,
        ),
      ],
    );
  }
}

/// Renames an existing board.
Future<void> showRenameBoardDialog(BuildContext context, Board board) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _RenameBoardDialog(board: board),
  );
  if (changed == true && context.mounted) {
    showWebMessage(context, 'Board renamed.');
  }
}

class _RenameBoardDialog extends StatefulWidget {
  final Board board;
  const _RenameBoardDialog({required this.board});

  @override
  State<_RenameBoardDialog> createState() => _RenameBoardDialogState();
}

class _RenameBoardDialogState extends State<_RenameBoardDialog> {
  late final _name = TextEditingController(text: widget.board.title);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = validateBoardName(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WebBoardsCubit>().renameBoard(
        widget.board.id,
        _name.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = webErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title: 'Rename board',
      icon: LucideIcons.pencil,
      content: SizedBox(
        width: 360,
        child: InkTextField(
          controller: _name,
          labelText: 'Board name',
          errorText: _error,
          autofocus: true,
          enabled: !_saving,
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          expand: false,
          compact: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        InkButton.primary(
          label: 'Rename',
          expand: false,
          compact: true,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// Joins a board by its join code / board id.
Future<void> showJoinBoardDialog(BuildContext context) async {
  final joined = await showDialog<bool>(
    context: context,
    builder: (_) => const _JoinBoardDialog(),
  );
  if (joined == true && context.mounted) {
    showWebMessage(context, 'You joined the board.');
  }
}

class _JoinBoardDialog extends StatefulWidget {
  const _JoinBoardDialog();

  @override
  State<_JoinBoardDialog> createState() => _JoinBoardDialogState();
}

class _JoinBoardDialogState extends State<_JoinBoardDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final value = _code.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Please enter a join code.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WebBoardsCubit>().joinBoard(value);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = webErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title: 'Join a board',
      icon: LucideIcons.doorOpen,
      content: SizedBox(
        width: 380,
        child: InkTextField(
          controller: _code,
          labelText: 'Join code',
          hintText: 'Paste the code the owner shared',
          errorText: _error,
          autofocus: true,
          enabled: !_saving,
          onSubmitted: (_) => _join(),
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          expand: false,
          compact: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        InkButton.primary(
          label: 'Join',
          expand: false,
          compact: true,
          isLoading: _saving,
          onPressed: _saving ? null : _join,
        ),
      ],
    );
  }
}
