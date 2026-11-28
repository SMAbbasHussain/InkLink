import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/settings/settings_service.dart';
import 'package:inklink/web/bloc/web_auth_cubit.dart';
import 'package:inklink/web/bloc/web_boards_cubit.dart';
import 'package:inklink/web/bloc/web_notifications_cubit.dart';
import 'package:inklink/web/bloc/web_settings_cubit.dart';
import 'package:inklink/web/bloc/web_social_cubit.dart';
import 'package:inklink/web/bloc/web_workspaces_cubit.dart';
import 'package:inklink/web/canvas/web_canvas_support.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_web_companion_service.dart';

void main() {
  test(
    'Web companion cubits hydrate state and delegate mutations via service',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = FakeWebCompanionService();
      final settingsService = SettingsServiceImpl(
        settingsRepository: WebSettingsRepository(prefs),
      );

      final authCubit = WebAuthCubit(service: service);
      final boardsCubit = WebBoardsCubit(service: service);
      final workspacesCubit = WebWorkspacesCubit(service: service);
      final socialCubit = WebSocialCubit(service: service);
      final notificationsCubit = WebNotificationsCubit(service: service);
      final settingsCubit = WebSettingsCubit(
        companionService: service,
        settingsService: settingsService,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(authCubit.currentUser, isNotNull);
      expect(boardsCubit.state.myBoardsLoading, isFalse);
      expect(boardsCubit.state.myBoards, isNotEmpty);
      expect(workspacesCubit.state.loading, isFalse);
      expect(workspacesCubit.state.workspaces, isNotEmpty);
      expect(socialCubit.state.profile, isNotNull);
      expect(notificationsCubit.state.loading, isFalse);
      expect(settingsCubit.state.loading, isFalse);

      final createdId = await boardsCubit.createBoard(name: 'Cubit Test Board');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(boardsCubit.state.myBoards.any((b) => b.id == createdId), isTrue);

      await settingsCubit.setShowTrayTips(false);
      expect(settingsCubit.state.trayTips, isFalse);

      await authCubit.close();
      await boardsCubit.close();
      await workspacesCubit.close();
      await socialCubit.close();
      await notificationsCubit.close();
      await settingsCubit.close();
    },
  );
}
