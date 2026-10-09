import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/models/board.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_chip.dart';
import '../../../ui/widgets/ink_segmented.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../friends/bloc/friends_bloc.dart';
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
  String _whoCanInvite = Board.inviteOwnerOnly;
  String _defaultLinkJoinRole = Board.roleViewer;
  String _inviteTargetRole = Board.roleViewer;

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
        whoCanInvite: _whoCanInvite,
        defaultLinkJoinRole: _defaultLinkJoinRole,
        inviteTargetRole: _inviteTargetRole,
        tags: _tags,
        invitedUserIds: invitees,
        inviteExpiryHours: _inviteExpiryHours,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _openInviteSettings() async {
    final tokens = context.ink;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String whoCanInvite = _whoCanInvite;
        String defaultLinkJoinRole = _defaultLinkJoinRole;
        String inviteTargetRole = _inviteTargetRole;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _GlassSheet(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite Settings', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s16),
                    _buildDropdown<String>(
                      label: 'Who can send invites',
                      value: whoCanInvite,
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
                        setSheetState(() => whoCanInvite = value);
                      },
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    _buildDropdown<String>(
                      label: 'Default role for link/code joins',
                      value: defaultLinkJoinRole,
                      items: const [
                        DropdownMenuItem(
                          value: Board.roleViewer,
                          child: Text('Viewer (default)'),
                        ),
                        DropdownMenuItem(
                          value: Board.roleEditor,
                          child: Text('Editor'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => defaultLinkJoinRole = value);
                      },
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    _buildDropdown<String>(
                      label: 'Role for invited users',
                      value: inviteTargetRole,
                      items: const [
                        DropdownMenuItem(value: Board.roleViewer, child: Text('Viewer')),
                        DropdownMenuItem(value: Board.roleEditor, child: Text('Editor')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => inviteTargetRole = value);
                      },
                    ),
                    const SizedBox(height: InkSpacing.s20),
                    InkButton.primary(
                      label: 'Save Settings',
                      onPressed: () {
                        Navigator.pop(context, {
                          'whoCanInvite': whoCanInvite,
                          'defaultLinkJoinRole': defaultLinkJoinRole,
                          'inviteTargetRole': inviteTargetRole,
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _whoCanInvite = result['whoCanInvite'] ?? Board.inviteOwnerOnly;
      _defaultLinkJoinRole = result['defaultLinkJoinRole'] ?? Board.roleViewer;
      _inviteTargetRole = result['inviteTargetRole'] ?? Board.roleViewer;
    });
  }

  static Widget _buildDropdown<T>({
    String? label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      icon: const Icon(LucideIcons.chevronDown, size: 18),
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Text('Create Board', style: InkType.title(tokens.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(InkSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaperCard(
                padding: const EdgeInsets.all(InkSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Board name', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s12),
                    InkTextField(
                      controller: _titleController,
                      hintText: 'Enter board name',
                      onChanged: (_) => setState(() {}),
                      autofocus: true,
                    ),
                    const SizedBox(height: InkSpacing.s20),
                    Text('Board visibility', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s12),
                    InkSegmented(
                      labels: const ['Private', 'Public'],
                      selectedIndex: _visibility == Board.visibilityPrivate ? 0 : 1,
                      onChanged: (i) {
                        setState(() {
                          _visibility = i == 0
                              ? Board.visibilityPrivate
                              : Board.visibilityPublic;
                        });
                      },
                    ),
                    if (_visibility == Board.visibilityPrivate) ...[
                      const SizedBox(height: InkSpacing.s16),
                      Text('Private board join policy', style: InkType.title(tokens.ink)),
                      const SizedBox(height: InkSpacing.s12),
                      _buildDropdown<String>(
                        value: _privateJoinPolicy,
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
                          setState(() => _privateJoinPolicy = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s16),
              PaperCard(
                padding: const EdgeInsets.all(InkSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Tags (optional)', style: InkType.title(tokens.ink)),
                        const Spacer(),
                        Text('${_tags.length} of 5', style: InkType.caption(tokens.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    Row(
                      children: [
                        Expanded(
                          child: InkTextField(
                            controller: _tagController,
                            hintText: 'e.g. #art',
                            onSubmitted: (_) => _addTagFromInput(),
                          ),
                        ),
                        const SizedBox(width: InkSpacing.s8),
                        InkButton.secondary(
                          label: 'Add',
                          expand: false,
                          onPressed: _addTagFromInput,
                        ),
                      ],
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: InkSpacing.s12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags
                            .map(
                              (tag) => InkChip(
                                label: '#$tag',
                                selected: true,
                                onDeleted: () => setState(() => _tags.remove(tag)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s16),
              PaperCard(
                padding: const EdgeInsets.all(InkSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkButton.secondary(
                      label: 'Configure Invite Settings',
                      icon: const Icon(LucideIcons.slidersHorizontal),
                      onPressed: _openInviteSettings,
                    ),
                    const SizedBox(height: InkSpacing.s8),
                    Text(
                      'Who can invite: ${_whoCanInvite.replaceAll('_', ' ')} | '
                      'Link role: $_defaultLinkJoinRole | Invite role: $_inviteTargetRole',
                      style: InkType.caption(tokens.inkMuted),
                    ),
                    const SizedBox(height: InkSpacing.s20),
                    Text('Invite users (optional)', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s12),
                    InkTextField(
                      controller: _inviteesController,
                      hintText: 'Comma-separated emails or user IDs',
                      maxLines: 2,
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select from friends (optional)',
                            style: InkType.title(tokens.ink),
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
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(color: tokens.accent),
                              ),
                            );
                          }

                          if (friendsState is! FriendsLoaded ||
                              friendsState.friends.isEmpty) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No friends loaded yet.',
                                style: InkType.body(tokens.inkMuted),
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: friendsState.friends.map((friend) {
                                final uid = friend['uid']?.toString() ?? '';
                                if (uid.isEmpty) return const SizedBox.shrink();
                                final name =
                                    friend['displayName']?.toString() ?? 'Friend';
                                final selected = _selectedFriendIds.contains(uid);
                                return InkChip(
                                  label: name,
                                  selected: selected,
                                  onTap: () {
                                    setState(() {
                                      if (selected) {
                                        _selectedFriendIds.remove(uid);
                                      } else {
                                        _selectedFriendIds.add(uid);
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
                    const SizedBox(height: InkSpacing.s16),
                    Text('Invite expiration', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s12),
                    _buildDropdown<int>(
                      value: _inviteExpiryHours,
                      items: const [
                        DropdownMenuItem(value: 24, child: Text('24 hours')),
                        DropdownMenuItem(value: 72, child: Text('3 days')),
                        DropdownMenuItem(value: 168, child: Text('7 days')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _inviteExpiryHours = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s24),
              InkButton.primary(
                label: 'Create Board',
                onPressed: _canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;

  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.s16,
        InkSpacing.s8,
        InkSpacing.s16,
        InkSpacing.s24,
      ),
      child: GlassPanel(
        radius: InkRadii.bottomSheet,
        padding: const EdgeInsets.all(InkSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: InkSpacing.s16),
              decoration: BoxDecoration(
                color: tokens.inkMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
