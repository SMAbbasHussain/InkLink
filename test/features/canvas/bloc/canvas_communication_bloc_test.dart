import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

void main() {
  group('CanvasBloc Module 11 Communication Events', () {
    late CanvasBloc bloc;

    setUp(() {
      bloc = CanvasBloc(boardId: 'test-board-comm');
    });

    tearDown(() {
      bloc.close();
    });

    test('updates comments when CanvasCommentsUpdated is dispatched', () async {
      final comment = CanvasComment(
        id: 'c1',
        boardId: 'test-board-comm',
        canvasPosition: const Offset(50, 100),
        authorUid: 'u1',
        authorName: 'Alice',
        text: 'Checking communication',
        createdAt: DateTime.now(),
      );

      bloc.add(CanvasCommentsUpdated([comment]));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.comments.length, 1);
      expect(bloc.state.comments.first.id, 'c1');
    });

    test('appends message when CanvasChatMessageReceived is dispatched', () async {
      const msg = BoardChatMessage(
        id: 'm1',
        boardId: 'test-board-comm',
        senderUid: 'u2',
        senderName: 'Bob',
        text: 'Hello via WebSocket',
        timestamp: 1729000000000,
      );

      bloc.add(const CanvasChatMessageReceived(msg));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.chatMessages.length, 1);
      expect(bloc.state.chatMessages.first.text, 'Hello via WebSocket');
    });

    test('toggles chat drawer and comments tray', () async {
      expect(bloc.state.isChatDrawerOpen, isFalse);
      expect(bloc.state.isCommentsTrayOpen, isFalse);

      bloc.add(const CanvasToggleChatDrawer());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isChatDrawerOpen, isTrue);
      expect(bloc.state.isCommentsTrayOpen, isFalse);

      bloc.add(const CanvasToggleCommentsTray());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isCommentsTrayOpen, isTrue);
      expect(bloc.state.isChatDrawerOpen, isFalse);
    });

    test('updates voice participants and active status', () async {
      const p = VoiceParticipant(
        uid: 'u3',
        displayName: 'Charlie',
        joinedAt: 1729000000000,
        isSpeaking: true,
      );

      bloc.add(const CanvasVoiceParticipantsUpdated([p]));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.voiceParticipants.length, 1);
      expect(bloc.state.voiceParticipants.first.isSpeaking, isTrue);

      bloc.add(const CanvasVoiceCallStatusChanged(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isVoiceCallActive, isTrue);

      bloc.add(const CanvasVoiceMuteStatusChanged(true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isMicMuted, isTrue);
    });

    test('toggles comment placement mode', () async {
      expect(bloc.state.isPlacingComment, isFalse);

      bloc.add(const CanvasToggleCommentPlacementMode());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isPlacingComment, isTrue);

      bloc.add(const CanvasToggleCommentPlacementMode(enable: false));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isPlacingComment, isFalse);
    });
  });
}
