import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_dialog.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../data/web_board_ops.dart';
import '../domain/web_companion_service.dart';
import '../widgets/web_widgets.dart';

// Every dialog here owns its text controllers and notifiers in a State, so
// they live exactly as long as the dialog's widgets (including the closing
// animation) and are disposed afterwards.

/// Creates a board from the browser, with the title field and defaults the
/// phone's create screen starts from (private, invite-only).
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
      await context.read<WebCompanionService>().createBoard(
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
            _ChoiceRow(
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

/// Renames a board (the repository call the phone's settings screen uses).
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
      await context.read<WebCompanionService>().renameBoard(
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

/// Edits a board's tags (comma separated; trimmed, lower-cased, at most five).
Future<void> showBoardTagsDialog(BuildContext context, Board board) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _BoardTagsDialog(board: board),
  );
  if (changed == true && context.mounted) {
    showWebMessage(context, 'Tags updated.');
  }
}

class _BoardTagsDialog extends StatefulWidget {
  final Board board;
  const _BoardTagsDialog({required this.board});

  @override
  State<_BoardTagsDialog> createState() => _BoardTagsDialogState();
}

class _BoardTagsDialogState extends State<_BoardTagsDialog> {
  late final _tags = TextEditingController(text: widget.board.tags.join(', '));
  bool _saving = false;

  @override
  void dispose() {
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<WebCompanionService>().updateBoardTags(
        widget.board.id,
        _tags.text.split(','),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title: 'Board tags',
      icon: LucideIcons.tag,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkTextField(
              controller: _tags,
              labelText: 'Tags',
              hintText: 'design, planning',
              autofocus: true,
              enabled: !_saving,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: InkSpacing.s8),
            Text(
              'Separate tags with commas. Up to $maxBoardTags.',
              style: InkType.caption(context.ink.inkMuted),
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
          label: 'Save',
          expand: false,
          compact: true,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// Visibility, join policy, invite rights and copy permission — the settings
/// fields the phone's board settings screen writes.
Future<void> showBoardSettingsDialog(BuildContext context, Board board) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _BoardSettingsDialog(board: board),
  );
  if (changed == true && context.mounted) {
    showWebMessage(context, 'Board settings saved.');
  }
}

class _BoardSettingsDialog extends StatefulWidget {
  final Board board;
  const _BoardSettingsDialog({required this.board});

  @override
  State<_BoardSettingsDialog> createState() => _BoardSettingsDialogState();
}

class _BoardSettingsDialogState extends State<_BoardSettingsDialog> {
  late String _visibility = widget.board.visibility;
  late String _joinPolicy = widget.board.privateJoinPolicy;
  late String _whoCanInvite = widget.board.whoCanInvite;
  late String _linkRole = widget.board.defaultLinkJoinRole;
  late bool _allowCopy = widget.board.allowMembersToCopy;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<WebCompanionService>().updateBoardSettings(
        boardId: widget.board.id,
        visibility: _visibility,
        privateJoinPolicy: _joinPolicy,
        whoCanInvite: _whoCanInvite,
        defaultLinkJoinRole: _linkRole,
        allowMembersToCopy: _allowCopy,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkDialog(
      title: 'Board settings',
      icon: LucideIcons.settings,
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(context, 'Visibility'),
                _ChoiceRow(
                  options: const {
                    Board.visibilityPrivate: 'Private',
                    Board.visibilityPublic: 'Public',
                  },
                  selected: _visibility,
                  onChanged: (v) => setState(() => _visibility = v),
                ),
                if (_visibility == Board.visibilityPrivate) ...[
                  const SizedBox(height: InkSpacing.s16),
                  _fieldLabel(context, 'Who can join a private board'),
                  _ChoiceRow(
                    options: const {
                      Board.policyOwnerOnlyInvite: 'Invite only',
                      Board.policyLinkCanJoin: 'Anyone with the link',
                    },
                    selected: _joinPolicy,
                    onChanged: (v) => setState(() => _joinPolicy = v),
                  ),
                ],
                const SizedBox(height: InkSpacing.s16),
                _fieldLabel(context, 'Who can invite'),
                _ChoiceRow(
                  options: const {
                    Board.inviteOwnerOnly: 'Owner',
                    Board.inviteOwnerEditor: 'Owner & editors',
                    Board.inviteAllMembers: 'All members',
                  },
                  selected: _whoCanInvite,
                  onChanged: (v) => setState(() => _whoCanInvite = v),
                ),
                const SizedBox(height: InkSpacing.s16),
                _fieldLabel(context, 'Link join role'),
                _ChoiceRow(
                  options: const {
                    Board.roleViewer: 'Viewer',
                    Board.roleEditor: 'Editor',
                  },
                  selected: _linkRole,
                  onChanged: (v) => setState(() => _linkRole = v),
                ),
                const SizedBox(height: InkSpacing.s8),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _allowCopy,
                    onChanged: (v) => setState(() => _allowCopy = v),
                    title: Text(
                      'Members can copy this board',
                      style: InkType.body(tokens.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          label: 'Save',
          expand: false,
          compact: true,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// Joins a board by its join code (or board id, which is the code).
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
      await context.read<WebCompanionService>().joinBoard(value);
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

Widget _fieldLabel(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: InkSpacing.s8),
  child: Text(text, style: InkType.caption(context.ink.inkMuted)),
);

/// A small single-choice row used by the dialogs above.
class _ChoiceRow extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: InkSpacing.s8,
      runSpacing: InkSpacing.s8,
      children: [
        for (final entry in options.entries)
          WebChoiceChip(
            label: entry.value,
            selected: selected == entry.key,
            onSelected: () => onChanged(entry.key),
          ),
      ],
    );
  }
}
