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
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Requests"), elevation: 0),
      body: BlocBuilder<FriendsBloc, FriendsState>(
        builder: (context, state) {
          if (state is FriendsLoaded) {
            final hasIncoming = state.incomingRequests.isNotEmpty;
            final hasOutgoing = state.outgoingRequests.isNotEmpty;

            if (hasIncoming || hasOutgoing) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.isOffline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.45),
                        ),
                      ),
                      child: const Text(
                        'Offline mode: pending requests are from local cache.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (hasIncoming)
                    ...state.incomingRequests.map((req) {
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          buildProfileRoute(context, userId: req['fromUid']),
                        ),
                        child: RequestCard(
                          request: req,
                          onAccept: () => context.read<FriendsBloc>().add(
                            AcceptFriendRequestRequested(
                              req['id'],
                              req['fromUid'],
                            ),
                          ),
                          onDecline: () => context.read<FriendsBloc>().add(
                            DeclineFriendRequestRequested(req['id']),
                          ),
                        ),
                      );
                    }),
                  if (hasOutgoing) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Sent Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...state.outgoingRequests.map((req) {
                      final toUid = req['toUid']?.toString() ?? 'Unknown user';
                      final sentName =
                          req['recipientName']?.toString() ?? toUid;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
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
                ],
              );
            }
          }

          // Empty state matching InkLink style
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  "All caught up!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Text(
                  "No pending requests.",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
