import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/friends_bloc.dart';
import '../bloc/friends_event.dart';
import '../bloc/friends_state.dart';
import './widgets/request_card.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Requests"),
        elevation: 0,
      ),
      body: BlocBuilder<FriendsBloc, FriendsState>(
        builder: (context, state) {
          if (state is FriendsLoaded && state.incomingRequests.isNotEmpty) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.incomingRequests.length,
              itemBuilder: (context, index) {
                final req = state.incomingRequests[index];
                return RequestCard(
                  request: req,
                  onAccept: () => context.read<FriendsBloc>().add(
                    AcceptFriendRequestRequested(req['id'], req['fromUid'])
                  ),
                  onDecline: () => context.read<FriendsBloc>().add(
                    DeclineFriendRequestRequested(req['id'])
                  ),
                );
              },
            );
          }

          // Empty state matching InkLink style
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text(
                  "All caught up!", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)
                ),
                const Text("No pending requests.", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}