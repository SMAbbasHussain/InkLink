import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/auth_service.dart';
import '../../../domain/models/canvas/canvas_toolbar_action.dart';
import '../../../domain/services/ai/ai_image_service.dart';
import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/canvas/board_chat_service.dart';
import '../../../domain/services/canvas/board_comments_service.dart';
import '../../../domain/services/canvas/canvas_service.dart';
import '../../../domain/services/history/board_history_service.dart';
import '../../../domain/services/settings/settings_service.dart';
import '../../../domain/services/voice/voice_service.dart';
import '../bloc/ai_image_bloc.dart';
import '../bloc/canvas_bloc.dart';
import 'canvas_screen.dart';

Route<void> buildCanvasRoute(
  BuildContext context, {
  required String boardId,
  bool showTrayTipsOnEntry = false,
  String? initialTemplateId,
}) {
  return MaterialPageRoute(
    builder: (_) => CanvasSessionView(
      boardId: boardId,
      showTrayTipsOnEntry: showTrayTipsOnEntry,
      initialTemplateId: initialTemplateId,
    ),
  );
}

/// Shared canvas session host used by both the mobile route (`buildCanvasRoute`)
/// and the web canvas route (`buildWebCanvasRoute`). Loads canvas preferences
/// from [SettingsService], constructs [CanvasBloc] and [AiImageBloc] from the
/// active provider scope, and renders [CanvasScreen].
class CanvasSessionView extends StatefulWidget {
  final String boardId;
  final bool showTrayTipsOnEntry;
  final String? initialTemplateId;

  const CanvasSessionView({
    super.key,
    required this.boardId,
    this.showTrayTipsOnEntry = false,
    this.initialTemplateId,
  });

  @override
  State<CanvasSessionView> createState() => _CanvasSessionViewState();
}

class _CanvasSessionViewState extends State<CanvasSessionView> {
  late Future<
    ({
      String quality,
      bool compressionEnabled,
      List<CanvasToolbarAction> bottomBarActions,
    })
  >
  _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  Future<
    ({
      String quality,
      bool compressionEnabled,
      List<CanvasToolbarAction> bottomBarActions,
    })
  >
  _loadSettings() async {
    final settingsService = context.read<SettingsService>();
    final quality = await settingsService.getBoardPreviewQuality();
    final compressionEnabled = await settingsService
        .getBoardPreviewCompressionEnabled();
    final bottomBarActions = await settingsService.getBottomBarActions();
    return (
      quality: quality,
      compressionEnabled: compressionEnabled,
      bottomBarActions: bottomBarActions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.read<SettingsService>();
    return FutureBuilder<
      ({
        String quality,
        bool compressionEnabled,
        List<CanvasToolbarAction> bottomBarActions,
      })
    >(
      future: _settingsFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => CanvasBloc(
                canvasService: context.read<CanvasService>(),
                boardService: context.read<BoardService>(),
                boardExportService: context.read<BoardExportService>(),
                boardCommentsService: context.read<BoardCommentsService>(),
                boardChatService: context.read<BoardChatService>(),
                voiceService: context.read<VoiceService>(),
                historyService: context.read<BoardHistoryService>(),
                currentUserId:
                    context.read<AuthService>().getCurrentUserId() ?? '',
                boardId: widget.boardId,
              )..add(CanvasInitializeCrdt(widget.boardId)),
            ),
            BlocProvider(
              create: (_) =>
                  AiImageBloc(aiImageService: context.read<AiImageService>()),
            ),
          ],
          child: CanvasScreen(
            boardId: widget.boardId,
            showTrayTipsOnEntry: widget.showTrayTipsOnEntry,
            boardPreviewQuality: data?.quality ?? 'medium',
            boardPreviewCompressionEnabled: data?.compressionEnabled ?? true,
            initialBottomBarActions:
                data?.bottomBarActions ??
                CanvasToolbarAction.defaultBottomBarActions,
            onSaveBottomBarActions: settingsService.setBottomBarActions,
            historyService: context.read<BoardHistoryService>(),
            initialTemplateId: widget.initialTemplateId,
          ),
        );
      },
    );
  }
}
