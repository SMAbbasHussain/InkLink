import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/board.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../friends/bloc/friends_event.dart';
import '../../friends/bloc/friends_state.dart';
import '../bloc/dashboard_bloc.dart';

class CreateBoardScreen extends StatefulWidget {
  const CreateBoardScreen({super.key});

  @override
  State<CreateBoardScreen> createState() => _CreateBoardScreenState();
}

class _CreateBoardScreenState extends State<CreateBoardScreen> {
  final _titleController = TextEditingController();
  final _inviteesController = TextEditingController();
  final _tagController = TextEditingController();
  final Set<String> _selectedFriendIds = <String>{};
  final List<String> _tags = <String>[];

  int _inviteExpiryHours = 72;
  String _visibility = Board.visibilityPrivate;
  String _privateJoinPolicy = Board.policyOwnerOnlyInvite;

  bool get _canSubmit => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    context.read<FriendsBloc>().add(LoadFriendsInfo());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _inviteesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTagFromInput() {
    final raw = _tagController.text.trim();
    if (raw.isEmpty) return;

    final normalized = raw.startsWith('#')
        ? raw.substring(1).trim().toLowerCase()
        : raw.toLowerCase();

    if (normalized.isEmpty) {
      _tagController.clear();
      return;
    }

    if (normalized.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each tag can be at most 20 characters.')),
      );
      return;
    }

    if (_tags.contains(normalized)) {
      _tagController.clear();
      return;
    }

    if (_tags.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 5 tags.')),
      );
      return;
    }

    setState(() {
      _tags.add(normalized);
      _tagController.clear();
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a board name.')),
      );
      return;
    }

    final invitees = _inviteesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    invitees.addAll(_selectedFriendIds);

    context.read<DashboardBloc>().add(
      DashboardCreateBoardRequested(
        title: title,
        visibility: _visibility,
        privateJoinPolicy: _privateJoinPolicy,
        tags: _tags,
        invitedUserIds: invitees,
        inviteExpiryHours: _inviteExpiryHours,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Board')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Board name',
                  hintText: 'Enter board name',
                ),
                onChanged: (_) => setState(() {}),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Board visibility',
                style: TextStyle(fontWeight: FontWeight.w600),
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
              if (_visibility == Board.visibilityPrivate) ...[
                const SizedBox(height: 12),
                const Text(
                  'Private board join policy',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
              ],
              const SizedBox(height: 16),
              const Text(
                'Tags (optional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: const InputDecoration(hintText: 'e.g. #art'),
                      onSubmitted: (_) => _addTagFromInput(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addTagFromInput,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map(
                      (tag) => Chip(
                        label: Text('#$tag'),
                        onDeleted: () {
                          setState(() {
                            _tags.remove(tag);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inviteesController,
                decoration: const InputDecoration(
                  labelText: 'Invite users (optional)',
                  hintText: 'Comma-separated emails or user IDs',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select from friends (optional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.read<FriendsBloc>().add(LoadFriendsInfo());
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: BlocBuilder<FriendsBloc, FriendsState>(
                  builder: (context, friendsState) {
                    if (friendsState is FriendsLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (friendsState is! FriendsLoaded ||
                        friendsState.friends.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No friends loaded yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: friendsState.friends.map((friend) {
                          final uid = friend['uid']?.toString() ?? '';
                          if (uid.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final name =
                              friend['displayName']?.toString() ?? 'Friend';
                          final selected = _selectedFriendIds.contains(uid);
                          return FilterChip(
                            selected: selected,
                            label: Text(name),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedFriendIds.add(uid);
                                } else {
                                  _selectedFriendIds.remove(uid);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Invite expiration'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _inviteExpiryHours,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 24, child: Text('24 hours')),
                  DropdownMenuItem(value: 72, child: Text('3 days')),
                  DropdownMenuItem(value: 168, child: Text('7 days')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _inviteExpiryHours = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('Create Board'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
