import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/friends_bloc.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FriendsBloc>().add(LoadBlockedUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users'), elevation: 0),
      body: BlocBuilder<FriendsBloc, FriendsState>(
        builder: (context, state) {
          final blockedUsers = state is FriendsLoaded
              ? state.blockedUsers
              : const <Map<String, dynamic>>[];

          if (state is FriendsInitial || state is FriendsLoading) {
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
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                        : () {
                            context
                                .read<FriendsBloc>()
                                .add(UnblockUserRequested(blockedUid));
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
