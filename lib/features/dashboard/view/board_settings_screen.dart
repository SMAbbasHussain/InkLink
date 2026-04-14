import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/board.dart';
import '../bloc/dashboard_bloc.dart';

class BoardSettingsScreen extends StatefulWidget {
  final Board board;

  const BoardSettingsScreen({super.key, required this.board});

  @override
  State<BoardSettingsScreen> createState() => _BoardSettingsScreenState();
}

class _BoardSettingsScreenState extends State<BoardSettingsScreen> {
  late String _visibility;
  late String _privateJoinPolicy;
  late String _whoCanInvite;
  late String _defaultLinkJoinRole;

  @override
  void initState() {
    super.initState();
    _visibility = widget.board.visibility;
    _privateJoinPolicy = widget.board.privateJoinPolicy;
    _whoCanInvite = widget.board.whoCanInvite;
    _defaultLinkJoinRole = widget.board.defaultLinkJoinRole;
  }

  void _save() {
    context.read<DashboardBloc>().add(
      DashboardUpdateBoardSettingsRequested(
        boardId: widget.board.id,
        visibility: _visibility,
        privateJoinPolicy: _privateJoinPolicy,
        whoCanInvite: _whoCanInvite,
        defaultLinkJoinRole: _defaultLinkJoinRole,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Board Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visibility',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: Board.visibilityPrivate,
                  label: Text('Private'),
                ),
                ButtonSegment<String>(
                  value: Board.visibilityPublic,
                  label: Text('Public'),
                ),
              ],
              selected: <String>{_visibility},
              onSelectionChanged: (selection) {
                setState(() {
                  _visibility = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_visibility == Board.visibilityPrivate) ...[
              const Text(
                'Private board join policy',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _privateJoinPolicy,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: Board.policyOwnerOnlyInvite,
                    child: Text('Only owner can invite'),
                  ),
                  DropdownMenuItem(
                    value: Board.policyLinkCanJoin,
                    child: Text('Anyone with join code can join'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _privateJoinPolicy = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Invitation settings',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _whoCanInvite,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Who can send invites',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: Board.inviteOwnerOnly,
                  child: Text('Owner only'),
                ),
                DropdownMenuItem(
                  value: Board.inviteOwnerEditor,
                  child: Text('Owner + Editors'),
                ),
                DropdownMenuItem(
                  value: Board.inviteAllMembers,
                  child: Text('All members'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _whoCanInvite = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _defaultLinkJoinRole,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Default role for link/code join',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: Board.roleViewer,
                  child: Text('Viewer'),
                ),
                DropdownMenuItem(
                  value: Board.roleEditor,
                  child: Text('Editor'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _defaultLinkJoinRole = value;
                });
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
