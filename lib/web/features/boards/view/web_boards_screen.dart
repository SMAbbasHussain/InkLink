import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../ui/theme/ink_colors.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_segmented.dart';
import '../../../core/web_formatters.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../../../ui/widgets/web_page_layout.dart';
import '../../auth/bloc/web_auth_cubit.dart';
import '../../invites/bloc/web_invites_cubit.dart';
import '../../navigation/view/web_shell_section.dart';
import '../bloc/web_boards_cubit.dart';
import 'web_board_card_grid.dart';
import 'web_board_crud_dialogs.dart';

enum _BoardTab { mine, joined, archived }

/// Signed-in user's boards screen: search, invite banner, tab filter
/// (My Boards / Joined / Archived), and responsive board card grid.
class WebBoardsPage extends StatefulWidget {
  const WebBoardsPage({super.key});

  @override
  State<WebBoardsPage> createState() => _WebBoardsPageState();
}

class _WebBoardsPageState extends State<WebBoardsPage> {
  final _search = TextEditingController();
  _BoardTab _tab = _BoardTab.mine;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Board> _apply(List<Board> boards, String? uid) {
    final query = _search.text.trim().toLowerCase();
    return boards.where((b) {
      final inTab = switch (_tab) {
        _BoardTab.mine => !b.isArchived && b.ownerId == uid,
        _BoardTab.joined => !b.isArchived && b.ownerId != uid,
        _BoardTab.archived => b.isArchived,
      };
      if (!inTab) return false;
      if (query.isEmpty) return true;
      return b.title.toLowerCase().contains(query) ||
          b.tags.any((t) => t.toLowerCase().contains(query)) ||
          b.id.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<WebAuthCubit>().state.user?.uid;
    final boardsState = context.watch<WebBoardsCubit>().state;
    final inviteCount = context
        .watch<WebInvitesCubit>()
        .state
        .boardInvites
        .length;
    final nav = WebShellNav.maybeOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        WebPageHeader(
          title: 'Ready to bring your ideas to life?',
          subtitle: 'Your boards and the boards you joined.',
          trailing: Wrap(
            spacing: InkSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: WebSearchField(
                  controller: _search,
                  hintText: 'Search boards...',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              InkButton.secondary(
                label: 'Join',
                compact: true,
                expand: false,
                icon: Icon(
                  LucideIcons.doorOpen,
                  size: 16,
                  color: context.ink.ink,
                ),
                onPressed: () => showJoinBoardDialog(context),
              ),
              InkButton.primary(
                label: 'New board',
                compact: true,
                expand: false,
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => showCreateBoardDialog(context),
              ),
            ],
          ),
        ),
        if (inviteCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: InkSpacing.s20),
            child: _InviteNotice(
              count: inviteCount,
              onReview: nav == null ? null : () => nav.goTo(WebSection.invites),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: InkSegmented(
              labels: const ['My Boards', 'Joined', 'Archived'],
              selectedIndex: _tab.index,
              onChanged: (i) => setState(() => _tab = _BoardTab.values[i]),
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.s20),
        if (boardsState.myBoardsError != null)
          WebErrorBox(message: webErrorText(boardsState.myBoardsError!))
        else if (boardsState.myBoardsLoading)
          const WebLoading()
        else if (boardsState.myBoards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: InkSpacing.s24),
            child: WebEmptyHint(
              icon: LucideIcons.layoutGrid,
              text: 'No boards created yet.',
              subtitle: 'Create your first board to get started.',
            ),
          )
        else
          Builder(
            builder: (context) {
              final visible = _apply(boardsState.myBoards, uid);
              if (visible.isEmpty) {
                final query = _search.text.trim();
                if (query.isNotEmpty) {
                  return WebEmptyHint(
                    icon: LucideIcons.searchX,
                    text: 'No boards match "$query"',
                  );
                }
                return WebEmptyHint(
                  icon: _tab == _BoardTab.archived
                      ? LucideIcons.archive
                      : LucideIcons.layoutGrid,
                  text: switch (_tab) {
                    _BoardTab.mine => 'No boards created yet.',
                    _BoardTab.joined => 'No boards joined yet.',
                    _BoardTab.archived => 'No archived boards.',
                  },
                  subtitle: _tab == _BoardTab.mine
                      ? 'Use New board above to start one.'
                      : null,
                );
              }
              return WebBoardCardGrid(
                boards: visible,
                captionFor: (b) => b.tags.isNotEmpty
                    ? '${b.tags.map((t) => '#$t').join(' ')} • '
                          'Edited ${timeAgo(b.updatedAt)}'
                    : 'Edited ${timeAgo(b.updatedAt)}',
              );
            },
          ),
      ],
    );
  }
}

class _InviteNotice extends StatelessWidget {
  final int count;
  final VoidCallback? onReview;

  const _InviteNotice({required this.count, this.onReview});

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.stickyInkFor(InkColors.stickyButter);
    return Material(
      color: InkColors.stickyButter,
      borderRadius: BorderRadius.circular(InkRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(InkRadii.card),
        onTap: onReview,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.s16,
            vertical: InkSpacing.s12,
          ),
          child: Row(
            children: [
              Icon(LucideIcons.mailOpen, size: 18, color: ink),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: Text(
                  count == 1
                      ? "You've been invited to a board!"
                      : 'You have $count board invites waiting!',
                  style: InkType.bodyStrong(ink),
                ),
              ),
              Text('Review', style: InkType.bodyStrong(ink)),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 16, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}
