import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/models/board.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
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
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Text('Create Workspace', style: InkType.title(tokens.ink)),
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
                    Text('Workspace Details', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s16),
                    InkTextField(
                      controller: _nameController,
                      labelText: 'Workspace Name',
                      hintText: 'e.g., My Team, Project X',
                      enabled: !_isCreating,
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    InkTextField(
                      controller: _descriptionController,
                      labelText: 'Description (optional)',
                      hintText: 'What is this workspace for?',
                      maxLines: 3,
                      enabled: !_isCreating,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s16),
              PaperCard(
                padding: const EdgeInsets.all(InkSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Boards (Optional)', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s12),
                    Text(
                      'Select boards to include in this workspace',
                      style: InkType.caption(tokens.inkMuted),
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    InkTextField(
                      controller: _boardSearchController,
                      labelText: 'Search boards',
                      hintText: 'Filter by board name',
                      leadingIcon: LucideIcons.search,
                      enabled: !_isCreating,
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    _BuildBoardsList(
                      searchQuery: _boardSearchController.text,
                      selectedBoardIds: _selectedBoardIds,
                      isCreating: _isCreating,
                      ownedBoardsStream: widget.ownedBoardsStream,
                      joinedBoardsStream: widget.joinedBoardsStream,
                      onSelectionChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s24),
              InkButton.primary(
                label: _isCreating ? '' : 'Create Workspace',
                icon: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : null,
                onPressed: _isCreating ? null : _createWorkspace,
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
    final tokens = context.ink;

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
                    padding: const EdgeInsets.all(InkSpacing.s16),
                    decoration: BoxDecoration(
                      color: tokens.field,
                      borderRadius: BorderRadius.circular(InkRadii.input),
                    ),
                    child: Text(
                      widget.searchQuery.isEmpty
                          ? 'No boards available'
                          : 'No boards match your search',
                      style: InkType.body(tokens.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: tokens.paper,
                    borderRadius: BorderRadius.circular(InkRadii.input),
                    border: Border.all(color: tokens.glassStroke),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredBoards.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: tokens.glassStroke),
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
                        title: Text(board.title, style: InkType.body(tokens.ink)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: InkSpacing.s16,
                          vertical: InkSpacing.s8,
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
          const SizedBox(height: InkSpacing.s12),
          Text(
            '${widget.selectedBoardIds.length} board(s) selected',
            style: InkType.caption(tokens.accentText),
          ),
        ],
      ],
    );
  }
}
