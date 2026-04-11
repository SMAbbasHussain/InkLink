import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/profile/view/profile_route.dart';
import '../bloc/friends_bloc.dart';
import '../bloc/friends_event.dart';
import '../bloc/friends_state.dart';
import './widgets/request_card.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pending Requests'),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Incoming'),
              Tab(text: 'Outgoing'),
            ],
          ),
        ),
        body: BlocBuilder<FriendsBloc, FriendsState>(
          builder: (context, state) {
            if (state is! FriendsLoaded) {
              return const SizedBox.shrink();
            }

            return TabBarView(
              children: [
                _buildIncomingTab(context, state),
                _buildOutgoingTab(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIncomingTab(BuildContext context, FriendsLoaded state) {
    final incoming = state.incomingRequests;
    if (incoming.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'All caught up!',
        subtitle: 'No incoming requests.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.isOffline) _buildOfflineBanner(),
        ...incoming.map((req) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              buildProfileRoute(context, userId: req['fromUid']),
            ),
            child: RequestCard(
              request: req,
              onAccept: () => context.read<FriendsBloc>().add(
                AcceptFriendRequestRequested(req['id'], req['fromUid']),
              ),
              onDecline: () => context.read<FriendsBloc>().add(
                DeclineFriendRequestRequested(req['id']),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOutgoingTab(BuildContext context, FriendsLoaded state) {
    final outgoing = state.outgoingRequests;
    if (outgoing.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule,
        title: 'Nothing pending',
        subtitle: 'No outgoing requests.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.isOffline) _buildOfflineBanner(),
        ...outgoing.map((req) {
          final toUid = req['toUid']?.toString() ?? '';
          final sentName =
              req['recipientName']?.toString() ??
              (toUid.isNotEmpty ? toUid : 'Unknown user');

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: toUid.isEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      buildProfileRoute(context, userId: toUid),
                    ),
              leading: const Icon(Icons.schedule),
              title: Text(sentName),
              subtitle: const Text('Request pending'),
              trailing: const Text(
                'Pending',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.45)),
      ),
      child: const Text(
        'Offline mode: pending requests are from local cache.',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
