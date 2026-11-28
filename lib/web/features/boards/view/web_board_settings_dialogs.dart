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
import '../../../ui/widgets/web_page_layout.dart';
import '../bloc/web_boards_cubit.dart';

/// Edits a board's tags (comma separated; trimmed, lower-cased, up to five).
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
      await context.read<WebBoardsCubit>().updateBoardTags(
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

/// Edits visibility, join policy, invite rights, and copy permissions.
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
      await context.read<WebBoardsCubit>().updateBoardSettings(
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
                webDialogFieldLabel(context, 'Visibility'),
                WebDialogChoiceRow(
                  options: const {
                    Board.visibilityPrivate: 'Private',
                    Board.visibilityPublic: 'Public',
                  },
                  selected: _visibility,
                  onChanged: (v) => setState(() => _visibility = v),
                ),
                if (_visibility == Board.visibilityPrivate) ...[
                  const SizedBox(height: InkSpacing.s16),
                  webDialogFieldLabel(context, 'Who can join a private board'),
                  WebDialogChoiceRow(
                    options: const {
                      Board.policyOwnerOnlyInvite: 'Invite only',
                      Board.policyLinkCanJoin: 'Anyone with the link',
                    },
                    selected: _joinPolicy,
                    onChanged: (v) => setState(() => _joinPolicy = v),
                  ),
                ],
                const SizedBox(height: InkSpacing.s16),
                webDialogFieldLabel(context, 'Who can invite'),
                WebDialogChoiceRow(
                  options: const {
                    Board.inviteOwnerOnly: 'Owner',
                    Board.inviteOwnerEditor: 'Owner & editors',
                    Board.inviteAllMembers: 'All members',
                  },
                  selected: _whoCanInvite,
                  onChanged: (v) => setState(() => _whoCanInvite = v),
                ),
                const SizedBox(height: InkSpacing.s16),
                webDialogFieldLabel(context, 'Link join role'),
                WebDialogChoiceRow(
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

Widget webDialogFieldLabel(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(bottom: InkSpacing.s8),
  child: Text(text, style: InkType.caption(context.ink.inkMuted)),
);

/// Single-choice chip row shared by web board dialogs.
class WebDialogChoiceRow extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const WebDialogChoiceRow({
    super.key,
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
