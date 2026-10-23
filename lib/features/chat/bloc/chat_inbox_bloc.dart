import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import 'chat_inbox_event.dart';
import 'chat_inbox_state.dart';

class ChatInboxBloc extends Bloc<ChatInboxEvent, ChatInboxState> {
  final ChatService _chatService;
  StreamSubscription<List<ChatConversationModel>>? _sub;

  ChatInboxBloc({required ChatService chatService})
      : _chatService = chatService,
        super(const ChatInboxInitial()) {
    on<LoadChatInbox>(_onLoadChatInbox);
    on<ConversationsUpdated>(_onConversationsUpdated);
    on<SearchConversations>(_onSearchConversations);
    on<DeleteConversationRequested>(_onDeleteConversation);
    on<ToggleMuteConversationRequested>(_onToggleMuteConversation);
    on<MarkConversationReadRequested>(_onMarkConversationRead);
  }

  Future<void> _onLoadChatInbox(
    LoadChatInbox event,
    Emitter<ChatInboxState> emit,
  ) async {
    emit(const ChatInboxLoading());
    await _sub?.cancel();
    _sub = _chatService.watchConversations().listen((conversations) {
      add(ConversationsUpdated(conversations));
    });

    final initialList = await _chatService.getConversations();
    add(ConversationsUpdated(initialList));
  }

  void _onConversationsUpdated(
    ConversationsUpdated event,
    Emitter<ChatInboxState> emit,
  ) {
    final query = state is ChatInboxLoaded ? (state as ChatInboxLoaded).searchQuery : '';
    final filtered = _filter(event.conversations, query);
    final totalUnread = event.conversations.fold<int>(
      0,
      (sum, item) => sum + (item.isMuted ? 0 : item.unreadCount),
    );

    emit(ChatInboxLoaded(
      allConversations: event.conversations,
      filteredConversations: filtered,
      searchQuery: query,
      totalUnreadCount: totalUnread,
    ));
  }

  void _onSearchConversations(
    SearchConversations event,
    Emitter<ChatInboxState> emit,
  ) {
    if (state is ChatInboxLoaded) {
      final current = state as ChatInboxLoaded;
      final filtered = _filter(current.allConversations, event.query);
      emit(current.copyWith(
        filteredConversations: filtered,
        searchQuery: event.query,
      ));
    }
  }

  List<ChatConversationModel> _filter(List<ChatConversationModel> list, String query) {
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase().trim();
    return list.where((c) {
      final matchesName = c.name.toLowerCase().contains(q);
      final matchesLastMsg = c.lastMessage?.toLowerCase().contains(q) ?? false;
      return matchesName || matchesLastMsg;
    }).toList();
  }

  Future<void> _onDeleteConversation(
    DeleteConversationRequested event,
    Emitter<ChatInboxState> emit,
  ) async {
    try {
      await _chatService.deleteConversation(event.conversationId);
    } catch (e) {
      emit(ChatInboxError(e.toString()));
    }
  }

  Future<void> _onToggleMuteConversation(
    ToggleMuteConversationRequested event,
    Emitter<ChatInboxState> emit,
  ) async {
    try {
      await _chatService.toggleMuteConversation(event.conversationId);
    } catch (e) {
      emit(ChatInboxError(e.toString()));
    }
  }

  Future<void> _onMarkConversationRead(
    MarkConversationReadRequested event,
    Emitter<ChatInboxState> emit,
  ) async {
    try {
      await _chatService.markConversationAsRead(event.conversationId);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
