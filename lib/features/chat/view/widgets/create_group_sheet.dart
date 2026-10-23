import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../../friends/bloc/friends_bloc.dart';
import '../../theme/chat_theme.dart';

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final chatService = context.read<ChatService>();
      final newGroup = await chatService.createGroup(
        name: name,
        description: _descController.text.trim(),
        memberIds: _selectedMemberIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context, newGroup);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(ChatTheme.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: ChatTheme.space16),

          // Header
          Row(
            children: [
              Text(
                'Create Group Chat',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: colors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: ChatTheme.space12),

          // Group Name
          TextField(
            controller: _nameController,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Group Name',
              labelStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: ChatTheme.space12),

          // Description
          TextField(
            controller: _descController,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Topic / Description (Optional)',
              labelStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: ChatTheme.space16),

          // Select Members Label
          Row(
            children: [
              Text(
                'Add Friends to Group',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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

          // Friends List
          Expanded(
            child: BlocBuilder<FriendsBloc, FriendsState>(
              builder: (context, friendsState) {
                if (friendsState is FriendsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Map<String, dynamic>> friends = [];
                if (friendsState is FriendsLoaded) {
                  final myUid = FirebaseAuth.instance.currentUser?.uid;
                  friends = myUid == null
                      ? friendsState.friends
                      : friendsState.friends.where((f) => f['uid'] != myUid).toList();
                }

                if (friends.isEmpty) {
                  return Center(
                    child: Text(
                      'No friends found. Add friends first to invite them to groups.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: friends.length,
                  separatorBuilder: (_, _) => const SizedBox(height: ChatTheme.space4),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final uid = friend['uid']?.toString() ?? '';
                    final name = friend['displayName']?.toString() ?? 'User';
                    final photo = friend['photoURL']?.toString();
                    final isSelected = _selectedMemberIds.contains(uid);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: colors.accent,
                      checkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: isSelected ? colors.surfaceElevated : Colors.transparent,
                      title: Text(name, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                      secondary: CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.surfaceElevated,
                        backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                        child: photo == null || photo.isEmpty
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(color: colors.textPrimary, fontSize: 12))
                            : null,
                      ),
                      onChanged: (bool? val) {
                        setState(() {
                          if (val == true) {
                            _selectedMemberIds.add(uid);
                          } else {
                            _selectedMemberIds.remove(uid);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: ChatTheme.space12),

          // Create Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _handleCreateGroup,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Create Group',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
