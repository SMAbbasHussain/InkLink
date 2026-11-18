part of 'canvas_screen.dart';

/// Desktop-browser layout of the board (web only, wide windows; see
/// [SlidingTray.useWebLayout]). Phones never build these widgets.
///
/// Floating light bars in the corners, like desktop whiteboards:
/// - top left: back, board menu, save status and title, export, search;
/// - top right: comments, chat, history, AI, members, Share, edit requests;
/// - left: a vertical tool rail;
/// - bottom left: minimap toggle; bottom right: selection mode, zoom,
///   undo/redo and history.
///
/// Every control calls the same handlers as the phone layout.
extension _CanvasWebLayout on _CanvasScreenState {
  static const double _edge = 16;
  static const double _barHeight = 48;

  /// Rail tools, in order (the phone's customizable bar decides its own).
  static const List<CanvasToolbarAction> _railTools = [
    CanvasToolbarAction.select,
    CanvasToolbarAction.hand,
    CanvasToolbarAction.pen,
    CanvasToolbarAction.highlight,
    CanvasToolbarAction.eraser,
    CanvasToolbarAction.shape,
    CanvasToolbarAction.arrow,
    CanvasToolbarAction.stickyNote,
    CanvasToolbarAction.text,
    CanvasToolbarAction.image,
    CanvasToolbarAction.frame,
    CanvasToolbarAction.table,
  ];

  // ── Building blocks ───────────────────────────────────────────────────

  /// A floating bar: paper colour, hairline border, soft shadow.
  Widget _webBar({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6),
    Axis direction = Axis.horizontal,
  }) {
    final tokens = _tokens;
    return Container(
      height: direction == Axis.horizontal ? _barHeight : null,
      width: direction == Axis.vertical ? _barHeight + 4 : null,
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.glassStroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A101828),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _webDivider({Axis direction = Axis.horizontal}) {
    final color = _tokens.glassStroke;
    return direction == Axis.horizontal
        ? Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: color,
          )
        : Container(
            height: 1,
            width: 24,
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: color,
          );
  }

  Widget _webIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool active = false,
    int badge = 0,
  }) {
    final tokens = _tokens;
    final color = onPressed == null
        ? tokens.inkMuted.withValues(alpha: 0.5)
        : active
        ? tokens.accent
        : tokens.ink;
    Widget iconWidget = Icon(icon, size: 19, color: color);
    if (badge > 0) {
      iconWidget = Badge(
        label: Text('$badge'),
        backgroundColor: tokens.accent,
        textColor: Colors.white,
        child: iconWidget,
      );
    }
    return Tooltip(
      message: tooltip,
      // The tooltip already names the button for screen readers.
      child: Semantics(
        button: true,
        selected: active,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? tokens.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: iconWidget,
          ),
        ),
      ),
    );
  }

  // ── Top left: back, menu, status + title, export, search ──────────────

  Widget _buildWebTopLeftBar(
    CanvasState state,
    String title,
    int pendingRequestsCount,
  ) {
    final tokens = _tokens;
    return Positioned(
      top: _edge,
      left: _edge,
      child: _webBar(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _webIconButton(
              icon: LucideIcons.chevronLeft,
              tooltip: 'Exit canvas',
              onPressed: _exitCanvas,
            ),
            _webDivider(),
            _buildBoardMenuButton(
              state,
              pendingRequestsCount,
              icon: LucideIcons.menu,
            ),
            _buildSyncIndicator(state),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openSettings(state.boardTitle ?? 'Board'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: InkType.bodyStrong(tokens.ink),
                        ),
                      ),
                      if (state.isArchived) ...[
                        const SizedBox(width: 6),
                        Text(
                          'Archived',
                          style: InkType.caption(tokens.pending),
                        ),
                      ],
                      const SizedBox(width: 2),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 15,
                        color: tokens.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _webDivider(),
            _webIconButton(
              icon: LucideIcons.download,
              tooltip: 'Export board',
              onPressed: () => _showExportOptionsSheet(context),
            ),
            _webIconButton(
              icon: LucideIcons.search,
              tooltip: 'Find on board',
              onPressed: () => _showBoardSearchSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top right: collaboration ──────────────────────────────────────────

  Widget _buildWebTopRightBar(CanvasState state, int pendingRequestsCount) {
    final tokens = _tokens;
    final isOwner = state.currentUserRole == Board.roleOwner;
    return Positioned(
      top: _edge,
      right: _edge,
      child: _webBar(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _webIconButton(
              icon: LucideIcons.messageCircle,
              tooltip: 'Comments',
              active: state.isCommentsTrayOpen,
              onPressed: () =>
                  _canvasBloc.add(const CanvasToggleCommentsTray()),
            ),
            _webIconButton(
              icon: LucideIcons.messagesSquare,
              tooltip: 'Board chat',
              active: state.isChatDrawerOpen,
              onPressed: () => _canvasBloc.add(const CanvasToggleChatDrawer()),
            ),
            _webIconButton(
              icon: LucideIcons.sparkles,
              tooltip: 'AI & media',
              active: state.activeTray == 'ai',
              onPressed: () => _toggleTray('ai'),
            ),
            _webIconButton(
              icon: LucideIcons.layers,
              tooltip: 'Layers',
              active: state.activeTray == 'layers',
              onPressed: () => _toggleTray('layers'),
            ),
            _webDivider(),
            if (state.boardMembers.isNotEmpty)
              Tooltip(
                message: 'Members',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _toggleTray('members'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildMemberAvatarStack(state.boardMembers),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Share board',
              offset: const Offset(0, 46),
              onSelected: (value) {
                if (value == 'code') {
                  Clipboard.setData(ClipboardData(text: widget.boardId));
                  AppSnackBar.showSuccess(
                    context,
                    'Join Code copied to clipboard!',
                  );
                } else if (value == 'image') {
                  _canvasBloc.add(
                    CanvasExportBoardRequested(
                      format: BoardExportFormat.png,
                      shareAfterExport: true,
                      sharePositionOrigin: _shareAnchorRect(),
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'code',
                  child: _menuRow(
                    LucideIcons.copy,
                    'Copy join code',
                    tokens.ink,
                  ),
                ),
                PopupMenuItem(
                  value: 'image',
                  child: _menuRow(
                    LucideIcons.image,
                    'Share as image',
                    tokens.ink,
                  ),
                ),
              ],
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.userPlus,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text('Share', style: InkType.bodyStrong(Colors.white)),
                  ],
                ),
              ),
            ),
            if (isOwner) ...[
              const SizedBox(width: 4),
              _webIconButton(
                icon: LucideIcons.bell,
                tooltip: pendingRequestsCount > 0
                    ? 'Edit requests ($pendingRequestsCount)'
                    : 'No edit requests',
                badge: pendingRequestsCount,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BoardEditRequestsScreen(
                      boardId: widget.boardId,
                      boardTitle: state.boardTitle ?? 'Board',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Left: tool rail ───────────────────────────────────────────────────

  bool _isRailToolActive(CanvasState state, CanvasToolbarAction action) {
    final tool = state.currentToolMode;
    return switch (action) {
      CanvasToolbarAction.select => tool == CanvasToolMode.select,
      CanvasToolbarAction.hand => tool == CanvasToolMode.hand,
      CanvasToolbarAction.pen => tool == CanvasToolMode.doodle,
      CanvasToolbarAction.highlight => tool == CanvasToolMode.highlight,
      CanvasToolbarAction.eraser => tool == CanvasToolMode.eraser,
      CanvasToolbarAction.fill => tool == CanvasToolMode.fill,
      CanvasToolbarAction.shape =>
        _isShapesPopupOpen ||
            (tool == CanvasToolMode.shape && !_isArrowMode(state)),
      CanvasToolbarAction.arrow =>
        _isArrowMode(state) || tool == CanvasToolMode.arrow,
      CanvasToolbarAction.text => tool == CanvasToolMode.text,
      CanvasToolbarAction.image => tool == CanvasToolMode.image,
      CanvasToolbarAction.layers => state.activeTray == 'layers',
      _ => false,
    };
  }

  Widget _buildWebToolRail(CanvasState state) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Room between the top bar and the bottom-left minimap toggle.
    final available = screenHeight - (_edge + _barHeight + 16) - 84;
    return Positioned(
      left: _edge,
      top: _edge + _barHeight + 16,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(120, available)),
        child: _webBar(
          direction: Axis.vertical,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in _railTools)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _webIconButton(
                      icon: iconForCanvasToolbarAction(action),
                      tooltip: action.label,
                      active: _isRailToolActive(state, action),
                      onPressed: !state.canEdit && action.requiresEdit
                          ? null
                          : () => _executeToolbarAction(action),
                    ),
                  ),
                _webDivider(direction: Axis.vertical),
                _webIconButton(
                  icon: LucideIcons.ellipsis,
                  tooltip: 'All tools & board options',
                  active: state.activeTray == 'actions',
                  onPressed: () => _toggleTray('actions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom left: minimap ──────────────────────────────────────────────

  List<Widget> _buildWebBottomLeft(CanvasState state) {
    return [
      // Beside its toggle, so it never covers the tool rail above.
      if (_webMinimapVisible)
        Positioned(
          left: _edge + _barHeight + 4 + 10,
          bottom: _edge,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _tokens.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _tokens.glassStroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A101828),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: CanvasMinimap(
              elements: state.elements,
              viewportScale: _viewportScale,
              viewportOffset: _viewportOffset,
              viewportSize: _lastCanvasSize,
              onJump: (world) => _applyViewportTransform(
                scale: _viewportScale,
                offset: _centerOffsetForScale(
                  _lastCanvasSize,
                  world,
                  _viewportScale,
                ),
              ),
            ),
          ),
        ),
      Positioned(
        left: _edge,
        bottom: _edge,
        child: _webBar(
          child: _webIconButton(
            icon: LucideIcons.map,
            tooltip: _webMinimapVisible ? 'Hide minimap' : 'Show minimap',
            active: _webMinimapVisible,
            onPressed: _toggleWebMinimap,
          ),
        ),
      ),
    ];
  }

  // ── Bottom right: selection mode, zoom, undo/redo, history ────────────

  Widget _buildWebBottomRight(CanvasState state) {
    final tokens = _tokens;
    final selecting = state.currentToolMode == CanvasToolMode.select;
    return Positioned(
      right: _edge,
      bottom: _edge,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _webBar(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _webIconButton(
                  icon: LucideIcons.squareDashed,
                  tooltip: 'Marquee select',
                  active:
                      selecting &&
                      state.selectionMode == CanvasSelectionMode.marquee,
                  onPressed: () {
                    _onToolbarToolSelected(CanvasToolMode.select);
                    _canvasBloc.add(
                      const CanvasSetSelectionMode(CanvasSelectionMode.marquee),
                    );
                  },
                ),
                _webIconButton(
                  icon: LucideIcons.lasso,
                  tooltip: 'Lasso select',
                  active:
                      selecting &&
                      state.selectionMode == CanvasSelectionMode.lasso,
                  onPressed: () {
                    _onToolbarToolSelected(CanvasToolMode.select);
                    _canvasBloc.add(
                      const CanvasSetSelectionMode(CanvasSelectionMode.lasso),
                    );
                  },
                ),
                _webDivider(),
                _webIconButton(
                  icon: LucideIcons.zoomOut,
                  tooltip: 'Zoom out',
                  onPressed: () => _zoomFromCenter(1 / 1.25),
                ),
                Tooltip(
                  message: 'Reset view',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _toggleResetView,
                    child: SizedBox(
                      width: 54,
                      height: 34,
                      child: Center(
                        child: Text(
                          canvasZoomPercentLabel(_viewportScale),
                          style: InkType.label(tokens.ink),
                        ),
                      ),
                    ),
                  ),
                ),
                _webIconButton(
                  icon: LucideIcons.zoomIn,
                  tooltip: 'Zoom in',
                  onPressed: () => _zoomFromCenter(1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _webBar(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _webIconButton(
                  icon: LucideIcons.undo2,
                  tooltip: 'Undo',
                  onPressed: state.canEdit ? _undo : null,
                ),
                _webIconButton(
                  icon: LucideIcons.redo2,
                  tooltip: 'Redo',
                  onPressed: state.canEdit ? _redo : null,
                ),
                _webDivider(),
                _webIconButton(
                  icon: LucideIcons.history,
                  tooltip: 'History',
                  onPressed: _openHistoryScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
