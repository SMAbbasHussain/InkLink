import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/workspace.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_workspaces_cubit.dart';

/// Creates a workspace through [WebWorkspacesCubit].
Future<void> showCreateWorkspaceDialog(BuildContext context) => showDialog(
  context: context,
  builder: (_) => const _CreateWorkspaceDialog(),
);

class _CreateWorkspaceDialog extends StatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  State<_CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<_CreateWorkspaceDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a workspace name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WebWorkspacesCubit>().createWorkspace(
        name: _name.text,
        description: _description.text,
      );
      if (!mounted) return;
      showWebMessage(context, 'Workspace created.');
      Navigator.of(context).pop();
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
      title: 'New workspace',
      icon: LucideIcons.briefcase,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkTextField(
              controller: _name,
              labelText: 'Name',
              hintText: 'e.g. Design team',
              errorText: _error,
              autofocus: true,
              enabled: !_saving,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: InkSpacing.s12),
            InkTextField(
              controller: _description,
              labelText: 'Description (optional)',
              enabled: !_saving,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          compact: true,
          expand: false,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        InkButton.primary(
          label: 'Create',
          compact: true,
          expand: false,
          isLoading: _saving,
          onPressed: _saving ? null : _create,
        ),
      ],
    );
  }
}

/// Owner-only workspace details editor. Returns saved values or null on cancel.
Future<({String name, String description})?> showWorkspaceSettingsDialog(
  BuildContext context, {
  required Workspace workspace,
}) => showDialog<({String name, String description})>(
  context: context,
  builder: (_) => _WorkspaceSettingsDialog(workspace: workspace),
);

class _WorkspaceSettingsDialog extends StatefulWidget {
  final Workspace workspace;

  const _WorkspaceSettingsDialog({required this.workspace});

  @override
  State<_WorkspaceSettingsDialog> createState() =>
      _WorkspaceSettingsDialogState();
}

class _WorkspaceSettingsDialogState extends State<_WorkspaceSettingsDialog> {
  late final _name = TextEditingController(text: widget.workspace.name);
  late final _description = TextEditingController(
    text: widget.workspace.description,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a workspace name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WebWorkspacesCubit>().updateWorkspace(
        workspaceId: widget.workspace.id,
        name: name,
        description: _description.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop((name: name, description: _description.text.trim()));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = webErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title: 'Workspace settings',
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkTextField(
              controller: _name,
              labelText: 'Workspace name',
              errorText: _error,
              enabled: !_saving,
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: InkSpacing.s12),
            InkTextField(
              controller: _description,
              labelText: 'Description',
              maxLines: 3,
              enabled: !_saving,
            ),
          ],
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          compact: true,
          expand: false,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        InkButton.primary(
          label: 'Save changes',
          compact: true,
          expand: false,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// Owner-only invite-by-email dialog. Returns true when an invite was sent.
Future<bool> showWorkspaceInviteDialog(
  BuildContext context, {
  required Workspace workspace,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _InviteWorkspaceDialog(workspace: workspace),
  );
  return sent == true;
}

class _InviteWorkspaceDialog extends StatefulWidget {
  final Workspace workspace;

  const _InviteWorkspaceDialog({required this.workspace});

  @override
  State<_InviteWorkspaceDialog> createState() => _InviteWorkspaceDialogState();
}

class _InviteWorkspaceDialogState extends State<_InviteWorkspaceDialog> {
  final _email = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter an email address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<WebWorkspacesCubit>().inviteToWorkspaceByEmail(
        workspaceId: widget.workspace.id,
        email: email,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = webErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title:
          'Invite to ${widget.workspace.name.isEmpty ? 'workspace' : widget.workspace.name}',
      content: SizedBox(
        width: 420,
        child: InkTextField(
          controller: _email,
          labelText: 'Email address',
          hintText: 'teammate@example.com',
          errorText: _error,
          keyboardType: TextInputType.emailAddress,
          enabled: !_sending,
          autofocus: true,
          onSubmitted: (_) => _send(),
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          compact: true,
          expand: false,
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
        ),
        InkButton.primary(
          label: 'Send invite',
          compact: true,
          expand: false,
          isLoading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
