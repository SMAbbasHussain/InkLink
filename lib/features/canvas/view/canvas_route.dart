import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/canvas/canvas_service.dart';
import '../../../domain/services/settings/settings_service.dart';
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
    final settingsService = context.read<SettingsService>();
    final quality = await settingsService.getBoardPreviewQuality();
    final compressionEnabled = await settingsService
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
          create: (_) => CanvasBloc(
            canvasService: context.read<CanvasService>(),
            boardService: context.read<BoardService>(),
            boardId: widget.boardId,
          )..add(CanvasInitializeCrdt(widget.boardId)),
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
