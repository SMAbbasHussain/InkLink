import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/models/chat/chat_message_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import 'chat_thread_event.dart';
import 'chat_thread_state.dart';

class ChatThreadBloc extends Bloc<ChatThreadEvent, ChatThreadState> {
  final ChatService _chatService;
  final String _currentUid;
  String? _activeConversationId;
  StreamSubscription<List<ChatMessageModel>>? _sub;

  ChatThreadBloc({
    required ChatService chatService,
    required String currentUid,
  })  : _chatService = chatService,
        _currentUid = currentUid,
        super(const ChatThreadInitial()) {
    on<LoadChatThread>(_onLoadChatThread);
    on<MessagesUpdated>(_onMessagesUpdated);
    on<SendTextMessageRequested>(_onSendTextMessage);
    on<SendImageMessageRequested>(_onSendImageMessage);
    on<SendGifMessageRequested>(_onSendGifMessage);
    on<SendFileMessageRequested>(_onSendFileMessage);
    on<SendShareCardRequested>(_onSendShareCard);
    on<ToggleReactionRequested>(_onToggleReaction);
    on<EditMessageRequested>(_onEditMessage);
    on<DeleteMessageRequested>(_onDeleteMessage);
  }

  Future<void> _onLoadChatThread(
    LoadChatThread event,
    Emitter<ChatThreadState> emit,
  ) async {
    _activeConversationId = event.conversationId;
    emit(const ChatThreadLoading());
    await _sub?.cancel();

    _sub = _chatService.watchMessages(event.conversationId).listen((messages) {
      add(MessagesUpdated(messages));
    });

    final initialList = await _chatService.getMessages(event.conversationId);
    add(MessagesUpdated(initialList));
    await _chatService.markConversationAsRead(event.conversationId);
  }

  void _onMessagesUpdated(
    MessagesUpdated event,
    Emitter<ChatThreadState> emit,
  ) {
    if (_activeConversationId == null) return;
    emit(ChatThreadLoaded(
      conversationId: _activeConversationId!,
      messages: event.messages,
    ));
  }

  Future<void> _onSendTextMessage(
    SendTextMessageRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      await _chatService.sendTextMessage(
        conversationId: _activeConversationId!,
        text: event.text,
        isGroup: event.isGroup,
        conversationName: event.conversationName,
        conversationAvatar: event.conversationAvatar,
        replyToId: event.replyToId,
        replyToSender: event.replyToSender,
        replyToText: event.replyToText,
      );
      if (_activeConversationId != null && !isClosed) {
        final messages = await _chatService.getMessages(_activeConversationId!);
        emit(ChatThreadLoaded(
          conversationId: _activeConversationId!,
          messages: messages,
        ));
      }
    } catch (e) {
      if (state is! ChatThreadLoaded) {
        emit(ChatThreadError(e.toString()));
      }
    }
  }

  Future<void> _onSendImageMessage(
    SendImageMessageRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      await _chatService.sendImageMessage(
        conversationId: _activeConversationId!,
        filePath: event.filePath,
        isGroup: event.isGroup,
        conversationName: event.conversationName,
        conversationAvatar: event.conversationAvatar,
        replyToId: event.replyToId,
        replyToSender: event.replyToSender,
        replyToText: event.replyToText,
      );
      if (_activeConversationId != null && !isClosed) {
        final messages = await _chatService.getMessages(_activeConversationId!);
        emit(ChatThreadLoaded(
          conversationId: _activeConversationId!,
          messages: messages,
        ));
      }
    } catch (e) {
      if (state is! ChatThreadLoaded) {
        emit(ChatThreadError(e.toString()));
      }
    }
  }

  Future<void> _onSendGifMessage(
    SendGifMessageRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      await _chatService.sendGifMessage(
        conversationId: _activeConversationId!,
        gifUrl: event.gifUrl,
        isGroup: event.isGroup,
        conversationName: event.conversationName,
        conversationAvatar: event.conversationAvatar,
        replyToId: event.replyToId,
        replyToSender: event.replyToSender,
        replyToText: event.replyToText,
      );
    } catch (e) {
      if (state is! ChatThreadLoaded) {
        emit(ChatThreadError(e.toString()));
      }
    }
  }

  Future<void> _onSendFileMessage(
    SendFileMessageRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      await _chatService.sendFileMessage(
        conversationId: _activeConversationId!,
        filePath: event.filePath,
        fileName: event.fileName,
        fileSize: event.fileSize,
        isGroup: event.isGroup,
        conversationName: event.conversationName,
        conversationAvatar: event.conversationAvatar,
        replyToId: event.replyToId,
        replyToSender: event.replyToSender,
        replyToText: event.replyToText,
      );
    } catch (e) {
      if (state is! ChatThreadLoaded) {
        emit(ChatThreadError(e.toString()));
      }
    }
  }

  Future<void> _onSendShareCard(
    SendShareCardRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      await _chatService.sendShareCardMessage(
        conversationId: _activeConversationId!,
        payload: event.payload,
        isGroup: event.isGroup,
        conversationName: event.conversationName,
        conversationAvatar: event.conversationAvatar,
        replyToId: event.replyToId,
        replyToSender: event.replyToSender,
        replyToText: event.replyToText,
      );
    } catch (e) {
      if (state is! ChatThreadLoaded) {
        emit(ChatThreadError(e.toString()));
      }
    }
  }

  Future<void> _onToggleReaction(
    ToggleReactionRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      if (state is ChatThreadLoaded) {
        final current = state as ChatThreadLoaded;
        final msg = current.messages.firstWhere(
          (m) => m.id == event.messageId,
          orElse: () => throw Exception('Message not found'),
        );
        final existingReactors = msg.reactions[event.emoji] ?? [];
        if (existingReactors.contains(_currentUid)) {
          await _chatService.removeReaction(
            conversationId: _activeConversationId!,
            messageId: event.messageId,
            emoji: event.emoji,
          );
        } else {
          await _chatService.addReaction(
            conversationId: _activeConversationId!,
            messageId: event.messageId,
            emoji: event.emoji,
          );
        }
      }
    } catch (e) {
      emit(ChatThreadError(e.toString()));
    }
  }

  Future<void> _onEditMessage(
    EditMessageRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      await _chatService.editMessage(
        conversationId: _activeConversationId!,
        messageId: event.messageId,
        newContent: event.newContent,
      );
    } catch (e) {
      emit(ChatThreadError(e.toString()));
    }
  }

  Future<void> _onDeleteMessage(
    DeleteMessageRequested event,
    Emitter<ChatThreadState> emit,
  ) async {
    if (_activeConversationId == null) return;
    try {
      await _chatService.deleteMessage(
        conversationId: _activeConversationId!,
        messageId: event.messageId,
      );
    } catch (e) {
      emit(ChatThreadError(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
