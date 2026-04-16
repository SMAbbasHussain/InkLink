import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/board.dart';
import '../bloc/workspace_bloc.dart';

class CreateWorkspaceScreen extends StatefulWidget {
  final Stream<List<Board>> ownedBoardsStream;
  final Stream<List<Board>> joinedBoardsStream;

  const CreateWorkspaceScreen({
    required this.ownedBoardsStream,
    required this.joinedBoardsStream,
    super.key,
  });

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _boardSearchController = TextEditingController();
  final Set<String> _selectedBoardIds = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _boardSearchController.dispose();
    super.dispose();
  }

  Future<void> _createWorkspace() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace name is required')),
      );
      return;
    }

    setState(() => _isCreating = true);

    if (!mounted) return;
    context.read<WorkspaceBloc>().add(
      CreateWorkspaceRequested(
        name: name,
        description: description,
        boardIds: _selectedBoardIds.toList(),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Workspace')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Workspace Details Section
              Text(
                'Workspace Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Workspace Name',
                  hintText: 'e.g., My Team, Project X',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                enabled: !_isCreating,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this workspace for?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
                enabled: !_isCreating,
              ),
              const SizedBox(height: 32),

              // Boards Selection Section
              Text(
                'Add Boards (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Select boards to include in this workspace',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _boardSearchController,
                decoration: InputDecoration(
                  labelText: 'Search boards',
                  hintText: 'Filter by board name',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                enabled: !_isCreating,
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Boards List
              _BuildBoardsList(
                searchQuery: _boardSearchController.text,
                selectedBoardIds: _selectedBoardIds,
                isCreating: _isCreating,
                ownedBoardsStream: widget.ownedBoardsStream,
                joinedBoardsStream: widget.joinedBoardsStream,
                onSelectionChanged: () => setState(() {}),
              ),
              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createWorkspace,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Workspace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildBoardsList extends StatefulWidget {
  final String searchQuery;
  final Set<String> selectedBoardIds;
  final bool isCreating;
  final Stream<List<Board>> ownedBoardsStream;
  final Stream<List<Board>> joinedBoardsStream;
  final VoidCallback onSelectionChanged;

  const _BuildBoardsList({
    required this.searchQuery,
    required this.selectedBoardIds,
    required this.isCreating,
    required this.ownedBoardsStream,
    required this.joinedBoardsStream,
    required this.onSelectionChanged,
  });

  @override
  State<_BuildBoardsList> createState() => _BuildBoardsListState();
}

class _BuildBoardsListState extends State<_BuildBoardsList> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<List<Board>>(
          stream: widget.ownedBoardsStream,
          builder: (context, ownedSnapshot) {
            return StreamBuilder<List<Board>>(
              stream: widget.joinedBoardsStream,
              builder: (context, joinedSnapshot) {
                final ownedBoards = ownedSnapshot.data ?? [];
                final joinedBoards = joinedSnapshot.data ?? [];
                final allBoards = [...ownedBoards, ...joinedBoards];

                // Filter boards by search query
                final filteredBoards = allBoards
                    .where(
                      (board) => board.title.toLowerCase().contains(
                        widget.searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filteredBoards.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.searchQuery.isEmpty
                          ? 'No boards available'
                          : 'No boards match your search',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredBoards.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey[300]),
                    itemBuilder: (context, index) {
                      final board = filteredBoards[index];
                      final isSelected = widget.selectedBoardIds.contains(
                        board.id,
                      );

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: widget.isCreating
                            ? null
                            : (value) {
                                if (value == true) {
                                  widget.selectedBoardIds.add(board.id);
                                } else {
                                  widget.selectedBoardIds.remove(board.id);
                                }
                                widget.onSelectionChanged();
                              },
                        title: Text(board.title),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        if (widget.selectedBoardIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${widget.selectedBoardIds.length} board(s) selected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
