import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/canvas/canvas_toolbar_action.dart';

/// Persists the user's preferred ordered list of canvas bottom bar actions.
class CanvasToolbarPreferences {
  final SharedPreferences _prefs;

  CanvasToolbarPreferences({required SharedPreferences prefs}) : _prefs = prefs;

  static const String _bottomBarActionsKey = 'canvas_bottom_bar_actions';

  Future<List<CanvasToolbarAction>> getBottomBarActions() async {
    final raw = _prefs.getStringList(_bottomBarActionsKey);
    return CanvasToolbarAction.decodeIds(raw);
  }

  Future<void> setBottomBarActions(List<CanvasToolbarAction> actions) async {
    await _prefs.setStringList(
      _bottomBarActionsKey,
      CanvasToolbarAction.encodeIds(actions),
    );
  }
}
