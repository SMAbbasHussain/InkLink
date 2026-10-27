import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/profile/profile_service.dart';
import 'package:inklink/features/dashboard/bloc/public_boards/public_boards_bloc.dart';
import 'package:inklink/features/dashboard/bloc/public_boards/public_boards_event.dart';
import 'package:inklink/features/dashboard/bloc/public_boards/public_boards_state.dart';

class FakeBoardService implements BoardService {
  List<Board> publicBoards = [];
  List<Board> recommendedBoards = [];

  @override
  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  }) async {
    var result = List<Board>.from(publicBoards);
    if (tag != null && tag.isNotEmpty) {
      result = result.where((b) => b.tags.contains(tag)).toList();
    }
    if (sort == PublicBoardSort.popular) {
      result.sort((a, b) => b.membersCount.compareTo(a.membersCount));
    } else {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return PublicBoardsPage(
      boards: result,
      lastDocCursor: 'cursor_token',
      hasMore: false,
    );
  }

  @override
  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  }) async {
    return recommendedBoards;
  }

  @override
  Future<void> archiveBoard(String boardId) async {}
  @override
  Future<CreateBoardResult> createBoard({
    String? title,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required String inviteTargetRole,
    required List<String> tags,
    bool allowMembersToCopy = false,
    List<String>? invitedUserIds,
    int? inviteExpiryHours,
  }) async =>
      const CreateBoardResult(boardId: 'b1');
  @override
  Future<void> deleteBoard(String boardId) async {}
  @override
  Future<String> duplicateBoard(String boardId, {String? customTitle}) async =>
      'b2';
  @override
  Stream<Board?> getBoardById(String boardId) => const Stream.empty();
  @override
  Stream<List<BoardMember>> getBoardMembers(String boardId) =>
      const Stream.empty();
  @override
  Stream<List<Board>> getJoinedBoards() => const Stream.empty();
  @override
  Stream<List<Board>> getOwnedBoards() => const Stream.empty();
  @override
  Future<void> joinBoard(String boardId) async {}
  @override
  Future<void> removeBoardMember(String boardId, String targetUid) async {}
  @override
  Future<void> renameBoard(String boardId, String newName) async {}
  @override
  Future<SendBoardInviteResult> sendBoardInvite({
    required String boardId,
    required String boardTitle,
    required List<String> invitedUserIds,
    required String targetRole,
    int? inviteExpiryHours,
  }) async =>
      const SendBoardInviteResult();
  @override
  Future<void> startBoardsSync() async {}
  @override
  Future<void> stopBoardsSync() async {}
  @override
  Future<void> unarchiveBoard(String boardId) async {}
  @override
  Future<void> updateBoardMemberRole(
          String boardId, String targetUid, String role) async {}
  @override
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  }) async {}
  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) async {}
  @override
  Future<void> requestBoardAccess({
    required String boardId,
    required String requestType,
    String? message,
  }) async {}
  @override
  Future<void> respondToBoardAccessRequest({
    required String boardId,
    required String requesterUid,
    required String notificationId,
    required String action,
    required String requestType,
  }) async {}
}

class FakeProfileService implements ProfileService {
  Map<String, dynamic>? currentUserData = {
    'preferredTags': ['design', 'flutter'],
  };

  @override
  Future<Map<String, dynamic>?> getCurrentUserData() async => currentUserData;
  @override
  String? getCurrentUserId() => 'user_123';
  @override
  Future<ProfileViewData> loadProfile(String userId) async => ProfileViewData(
        userData: currentUserData ?? {},
        isSelf: true,
        isFriend: false,
        isBlocked: false,
      );
  @override
  Future<String?> saveProfileChanges({
    required String name,
    required String bio,
    String? imageData,
    String? filename,
  }) async =>
      null;
  @override
  Future<void> updateNotificationPreferences({
    String? uid,
    bool? pushNotificationsEnabled,
    bool? inviteAlertsEnabled,
    bool? friendAlertsEnabled,
  }) async {}
  @override
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  }) async {}
  @override
  Future<void> updateProfile({required String name, required String bio}) async {}
  @override
  Future<String> uploadProfilePhoto({
    required String imageData,
    required String filename,
  }) async =>
      'photo_url';
  @override
  Stream<Map<String, dynamic>?> watchUserById(String userId) =>
      const Stream.empty();
  @override
  Future<void> updatePreferredTags(List<String> tags) async {
    currentUserData = {'preferredTags': tags};
  }
}

void main() {
  late FakeBoardService fakeBoardService;
  late FakeProfileService fakeProfileService;
  late PublicBoardsBloc bloc;

  final sampleBoard1 = Board(
    id: 'b1',
    title: 'Mobile Architecture Design',
    ownerId: 'u1',
    members: ['u1', 'u2'],
    membersCount: 2,
    visibility: Board.visibilityPublic,
    tags: const ['architecture', 'design'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleBoard2 = Board(
    id: 'b2',
    title: 'Flutter Brainstorm Session',
    ownerId: 'u2',
    members: ['u2', 'u3', 'u4', 'u5'],
    membersCount: 4,
    visibility: Board.visibilityPublic,
    tags: const ['flutter', 'brainstorm'],
    createdAt: DateTime(2026, 1, 5),
    updatedAt: DateTime(2026, 1, 5),
  );

  setUp(() {
    fakeBoardService = FakeBoardService();
    fakeProfileService = FakeProfileService();
    fakeBoardService.publicBoards = [sampleBoard1, sampleBoard2];
    fakeBoardService.recommendedBoards = [sampleBoard2];

    bloc = PublicBoardsBloc(
      boardService: fakeBoardService,
      profileService: fakeProfileService,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state has empty boards and default sort', () {
    expect(bloc.state.status, PublicBoardsStatus.initial);
    expect(bloc.state.boards, isEmpty);
    expect(bloc.state.sort, PublicBoardSort.recent);
  });

  test('PublicBoardsFetchStarted loads recommended and public boards', () async {
    bloc.add(const PublicBoardsFetchStarted());

    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<PublicBoardsState>(
            (s) => s.status == PublicBoardsStatus.loading),
        predicate<PublicBoardsState>((s) =>
            s.status == PublicBoardsStatus.success &&
            s.boards.length == 2 &&
            s.recommendedBoards.length == 1),
      ]),
    );

    expect(bloc.state.availableTags, containsAll(['architecture', 'design', 'flutter', 'brainstorm']));
  });

  test('PublicBoardsSearchChanged filters boards in-memory via filteredBoards', () async {
    bloc.add(const PublicBoardsFetchStarted());
    await bloc.stream.firstWhere((s) => s.status == PublicBoardsStatus.success);

    bloc.add(const PublicBoardsSearchChanged('Flutter'));
    await pumpEventQueue();

    expect(bloc.state.searchQuery, 'Flutter');
    expect(bloc.state.filteredBoards.length, 1);
    expect(bloc.state.filteredBoards.first.title, 'Flutter Brainstorm Session');
  });

  test('PublicBoardsTagSelected updates selectedTag and re-fetches', () async {
    bloc.add(const PublicBoardsFetchStarted());
    await bloc.stream.firstWhere((s) => s.status == PublicBoardsStatus.success);

    bloc.add(const PublicBoardsTagSelected('design'));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<PublicBoardsState>((s) =>
            s.status == PublicBoardsStatus.loading && s.selectedTag == 'design'),
        predicate<PublicBoardsState>((s) =>
            s.status == PublicBoardsStatus.success &&
            s.boards.length == 1 &&
            s.boards.first.id == 'b1'),
      ]),
    );
  });

  test('PublicBoardsSortChanged sorts by popularity (membersCount)', () async {
    bloc.add(const PublicBoardsFetchStarted());
    await bloc.stream.firstWhere((s) => s.status == PublicBoardsStatus.success);

    bloc.add(const PublicBoardsSortChanged(PublicBoardSort.popular));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<PublicBoardsState>((s) =>
            s.status == PublicBoardsStatus.loading &&
            s.sort == PublicBoardSort.popular),
        predicate<PublicBoardsState>((s) =>
            s.status == PublicBoardsStatus.success &&
            s.boards.first.id == 'b2'), // b2 has 4 members, b1 has 2
      ]),
    );
  });

  test('PublicBoardsRequestJoinAccess sends join request and emits actionSuccessMessage', () async {
    bloc.add(const PublicBoardsRequestJoinAccess('b1', message: 'Can I join?'));

    await expectLater(
      bloc.stream,
      emits(
        predicate<PublicBoardsState>((s) =>
            s.actionSuccessMessage == 'Join request sent to board owner.'),
      ),
    );
  });

  test('PublicBoardsRequestEditAccess sends edit request and emits actionSuccessMessage', () async {
    bloc.add(const PublicBoardsRequestEditAccess('b1', message: 'Need edit rights'));

    await expectLater(
      bloc.stream,
      emits(
        predicate<PublicBoardsState>((s) =>
            s.actionSuccessMessage == 'Edit access request sent to board owner.'),
      ),
    );
  });

  test('PublicBoardsJoinBoard calls joinBoard and emits success message', () async {
    bloc.add(const PublicBoardsJoinBoard('b1', boardTitle: 'Alpha Design'));

    await expectLater(
      bloc.stream,
      emits(
        predicate<PublicBoardsState>((s) =>
            s.actionSuccessMessage == 'Joined board "Alpha Design"! Added to your dashboard.'),
      ),
    );
  });

  test('PublicBoardsUserPreferencesChanged updates recommended boards dynamically (FR14-10)', () async {
    fakeBoardService.recommendedBoards = [
      Board(
        id: 'rec_dynamic',
        title: 'Dynamic Retro',
        ownerId: 'u9',
        members: const ['u9'],
        tags: const ['retro', 'agile'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    bloc.add(const PublicBoardsUserPreferencesChanged(['retro']));

    await expectLater(
      bloc.stream,
      emits(
        predicate<PublicBoardsState>((s) =>
            s.recommendedBoards.length == 1 &&
            s.recommendedBoards.first.id == 'rec_dynamic' &&
            s.availableTags.contains('retro')),
      ),
    );
  });
}

