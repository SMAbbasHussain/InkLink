import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/friends_bloc.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users'), elevation: 0),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<FriendsBloc>().watchBlockedUsers(),
        builder: (context, snapshot) {
          final blockedUsers = snapshot.data ?? const <Map<String, dynamic>>[];

          if (snapshot.connectionState == ConnectionState.waiting &&
              blockedUsers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (blockedUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block_outlined,
                    size: 72,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No blocked users',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'People you block will appear here.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: blockedUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = blockedUsers[index];
              final blockedUid = user['blockedUid']?.toString() ?? '';
              final displayName =
                  user['displayName']?.toString().trim().isNotEmpty == true
                  ? user['displayName'].toString()
                  : 'User';
              final photoUrl = user['photoURL']?.toString();

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(displayName),
                  subtitle: Text(blockedUid),
                  trailing: TextButton(
                    onPressed: blockedUid.isEmpty
                        ? null
                        : () async {
                            try {
                              await context.read<FriendsBloc>().unblockUser(
                                blockedUid,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User unblocked'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: const Text('Unblock'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
