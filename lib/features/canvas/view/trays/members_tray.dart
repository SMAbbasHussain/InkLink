import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/sliding_tray.dart';

class MembersTray extends StatelessWidget {
  final bool isOpen;
  final String boardId;

  const MembersTray({super.key, required this.isOpen, required this.boardId});

  @override
  Widget build(BuildContext context) {
    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.left,
      title: 'Members & Calls',
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.grid_3x3)),
            title: const Text('Board ID'),
            subtitle: Text(
              boardId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: boardId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Board ID copied.')),
                );
              },
            ),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('You'),
            subtitle: Text('Owner / Member'),
            trailing: Icon(Icons.check_circle, color: Colors.green, size: 18),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: boardId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Join Code copied to clipboard! Share it with friends.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Copy Invite Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
