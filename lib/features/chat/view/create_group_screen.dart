import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/app_error_formatter.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../theme/chat_theme.dart';
import 'widgets/group_avatar_picker.dart';

Route<ChatConversationModel> buildCreateGroupRoute(BuildContext context) {
  return MaterialPageRoute(
    builder: (_) => const CreateGroupScreen(),
  );
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _memberSearchController =
      TextEditingController();
  final Set<String> _selectedMemberIds = {};

  String? _avatarUrl;
  String _memberQuery = '';
  bool _isUploadingAvatar = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) return;
    setState(() => _isUploadingAvatar = true);
    final url = await pickAndUploadGroupAvatar(context);
    if (!mounted) return;
    setState(() {
      _isUploadingAvatar = false;
      if (url != null) _avatarUrl = url;
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.showMessage(context, 'Please enter a group name');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final group = await context.read<ChatService>().createGroup(
            name: name,
            description: _descController.text.trim(),
            memberIds: _selectedMemberIds.toList(),
            iconUrl: _avatarUrl,
          );
      if (mounted) Navigator.pop(context, group);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showMessage(
          context,
          'Failed to create group: ${AppErrorFormatter.cleanMessage(e, fallback: 'Please check your connection.')}',
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  List<Map<String, dynamic>> _friendsFor(FriendsState friendsState) {
    if (friendsState is! FriendsLoaded) return const [];
    final authState = context.read<AuthBloc>().state;
    final myUid = authState is Authenticated ? authState.uid : null;
    final myEmail = authState is Authenticated ? authState.email : null;
    final normalizedEmail = myEmail?.trim().toLowerCase();
    final query = _memberQuery.trim().toLowerCase();

    return friendsState.friends.where((friend) {
      final uid = (friend['uid'] ?? '').toString().trim();
      final email = (friend['email'] ?? '').toString().trim().toLowerCase();
      if (myUid != null && uid.isNotEmpty && uid == myUid.trim()) return false;
      if (normalizedEmail != null &&
          email.isNotEmpty &&
          email == normalizedEmail) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = (friend['displayName'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    final friendsState = context.watch<FriendsBloc>().state;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'New Group',
          style: TextStyle(color: colors.textPrimary, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : Text(
                    'Create',
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ChatTheme.space16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: colors.surfaceElevated,
                    backgroundImage: _avatarUrl != null &&
                            _avatarUrl!.isNotEmpty
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? Icon(
                            Icons.groups_rounded,
                            size: 40,
                            color: colors.textSecondary,
                          )
                        : null,
                  ),
                  if (_isUploadingAvatar)
                    const CircularProgressIndicator()
                  else
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_camera,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Add a group photo',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: ChatTheme.space24),
          _field(
            controller: _nameController,
            colors: colors,
            label: 'Group Name',
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: ChatTheme.space12),
          _field(
            controller: _descController,
            colors: colors,
            label: 'Description (Optional)',
            maxLines: 3,
          ),
          const SizedBox(height: ChatTheme.space24),
          Row(
            children: [
              Text(
                'Members',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedMemberIds.length} selected',
                style: TextStyle(color: colors.accent, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: ChatTheme.space8),
          TextField(
            controller: _memberSearchController,
            onChanged: (value) => setState(() => _memberQuery = value),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search friends...',
              hintStyle: TextStyle(color: colors.textSecondary),
              prefixIcon: Icon(Icons.search, color: colors.textSecondary),
              filled: true,
              fillColor: colors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: ChatTheme.space8),
          if (friendsState is FriendsLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._buildFriendRows(colors, _friendsFor(friendsState)),
        ],
      ),
    );
  }

  List<Widget> _buildFriendRows(
    ChatColors colors,
    List<Map<String, dynamic>> friends,
  ) {
    if (friends.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _selectedMemberIds.isEmpty && _memberQuery.isEmpty
                ? 'No friends to add yet. You can still create the group and add people later.'
                : 'No matching friends.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ),
      ];
    }

    return friends.map((friend) {
      final uid = (friend['uid'] ?? '').toString();
      final name = (friend['displayName'] ?? 'User').toString();
      final photo = (friend['photoURL'] ?? '').toString();
      final isSelected = _selectedMemberIds.contains(uid);

      return CheckboxListTile(
        value: isSelected,
        activeColor: colors.accent,
        checkColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        title: Text(
          name,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
        ),
        secondary: CircleAvatar(
          radius: 18,
          backgroundColor: colors.surfaceElevated,
          backgroundImage:
              photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: colors.textPrimary, fontSize: 12),
                )
              : null,
        ),
        onChanged: (value) {
          if (uid.isEmpty) return;
          setState(() {
            if (value == true) {
              _selectedMemberIds.add(uid);
            } else {
              _selectedMemberIds.remove(uid);
            }
          });
        },
      );
    }).toList();
  }

  Widget _field({
    required TextEditingController controller,
    required ChatColors colors,
    required String label,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: colors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
