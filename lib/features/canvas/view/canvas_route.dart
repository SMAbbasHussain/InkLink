import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/board/board_repository.dart';
import '../../../domain/repositories/canvas/canvas_sync_repository.dart';
import '../../../domain/repositories/settings/settings_repository.dart';
import '../../../domain/services/canvas/canvas_service.dart';
import '../bloc/canvas_bloc.dart';
import 'canvas_screen.dart';

Route<void> buildCanvasRoute(
  BuildContext context, {
  required String boardId,
  bool showTrayTipsOnEntry = false,
}) {
  return MaterialPageRoute(
    builder: (_) => _CanvasRouteWrapper(
      boardId: boardId,
      showTrayTipsOnEntry: showTrayTipsOnEntry,
    ),
  );
}

class _CanvasRouteWrapper extends StatefulWidget {
  final String boardId;
  final bool showTrayTipsOnEntry;

  const _CanvasRouteWrapper({
    required this.boardId,
    required this.showTrayTipsOnEntry,
  });

  @override
  State<_CanvasRouteWrapper> createState() => _CanvasRouteWrapperState();
}

class _CanvasRouteWrapperState extends State<_CanvasRouteWrapper> {
  late Future<({String quality, bool compressionEnabled})> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  Future<({String quality, bool compressionEnabled})> _loadSettings() async {
    final settingsRepository = context.read<SettingsRepository>();
    final quality = await settingsRepository.getBoardPreviewQuality();
    final compressionEnabled = await settingsRepository
        .getBoardPreviewCompressionEnabled();
    return (quality: quality, compressionEnabled: compressionEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String quality, bool compressionEnabled})>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return BlocProvider(
          create: (_) =>
              CanvasBloc(
                  canvasService: CanvasServiceImpl(
                    boardRepository: context.read<BoardRepository>(),
                    syncRepository: context.read<CanvasSyncRepository>(),
                  ),
                  boardId: widget.boardId,
                )
                ..add(const CanvasStartBoardSyncRequested())
                ..add(CanvasInitializeCrdt(widget.boardId)),
          child: CanvasScreen(
            boardId: widget.boardId,
            showTrayTipsOnEntry: widget.showTrayTipsOnEntry,
            boardPreviewQuality: data?.quality ?? 'medium',
            boardPreviewCompressionEnabled: data?.compressionEnabled ?? true,
          ),
        );
      },
    );
  }
}
