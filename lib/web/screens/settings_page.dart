import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/board_preview_preferences.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_chip.dart';
import '../../ui/widgets/ink_dialog.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/paper_card.dart';
import '../canvas/web_canvas_support.dart';
import '../data/web_account_settings.dart';
import '../data/web_companion_repository.dart';
import '../widgets/web_widgets.dart';
import 'web_shell_nav.dart';

/// A paper card of ListTiles with a transparent Material between them and the
/// card's painted background (Flutter asserts otherwise: tiles paint their
/// ink on the nearest Material).
/// One switch row of a [_TileGroup].
class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: InkType.bodyStrong(tokens.ink)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: InkType.caption(tokens.inkMuted)),
    );
  }
}

class _TileGroup extends StatelessWidget {
  final List<Widget> children;
  const _TileGroup({required this.children});

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );
}

/// The web companion's settings, backed by the same browser-stored
/// preferences the canvas reads ([WebSettingsRepository]): tray tips, board
/// preview quality and compression, alert toggles, cache clearing and the
/// account actions. The phone's Isar-only settings (offline cache, local
/// storage) have no web equivalent and are not shown.
class WebSettingsPage extends StatefulWidget {
  const WebSettingsPage({super.key});

  @override
  State<WebSettingsPage> createState() => _WebSettingsPageState();
}

class _WebSettingsPageState extends State<WebSettingsPage> {
  WebSettingsRepository? _settings;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  bool _trayTips = true;
  String _quality = BoardPreviewPreferences.medium;
  bool _compression = true;
  bool _push = true;
  bool _invite = true;
  bool _friend = true;

  WebAccountSettings _accountSettings = WebAccountSettings.defaults;
  StreamSubscription<WebAccountSettings>? _accountSub;
  final _tagController = TextEditingController();

  String? get _uid => context.read<WebCompanionRepository>().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _accountSub = context
        .read<WebCompanionRepository>()
        .watchAccountSettings()
        .listen((settings) {
          if (mounted) setState(() => _accountSettings = settings);
        });
    _load();
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = WebSettingsRepository(prefs);
      final trayTips = await settings.getShowTrayTips();
      final quality = await settings.getBoardPreviewQuality();
      final compression = await settings.getBoardPreviewCompressionEnabled();
      final push = await settings.getPushNotificationsEnabled(_uid);
      final invite = await settings.getInviteAlertsEnabled(_uid);
      final friend = await settings.getFriendAlertsEnabled(_uid);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _trayTips = trayTips;
        _quality = quality;
        _compression = compression;
        _push = push;
        _invite = invite;
        _friend = friend;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = webErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await context.read<WebCompanionRepository>().signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Delete your account?',
      message:
          'Your boards, workspaces, friends and notifications are removed. '
          'This cannot be undone.',
      confirmLabel: 'Delete account',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<WebCompanionRepository>().deleteAccount();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showWebMessage(context, webErrorText(e), isError: true);
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      await _settings?.clearLocalCache();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      if (mounted) showWebMessage(context, 'Local cache cleared.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  /// Privacy toggles write all three booleans (the phone's
  /// `updatePrivacySettings` takes them together), optimistically and rolled
  /// back on failure.
  Future<void> _setPrivacy({
    bool? isProfilePublic,
    bool? showOnlineStatus,
    bool? showEmail,
  }) async {
    final previous = _accountSettings;
    final next = previous.copyWith(
      isProfilePublic: isProfilePublic,
      showOnlineStatus: showOnlineStatus,
      showEmail: showEmail,
    );
    setState(() => _accountSettings = next);
    try {
      await context.read<WebCompanionRepository>().updatePrivacySettings(
        isProfilePublic: next.isProfilePublic,
        showOnlineStatus: next.showOnlineStatus,
        showEmail: next.showEmail,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _accountSettings = previous);
      showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _toggleTag(String tag) async {
    final previous = _accountSettings;
    final next = previous.copyWith(
      preferredTags: WebAccountSettings.toggleTag(previous.preferredTags, tag),
    );
    setState(() => _accountSettings = next);
    try {
      await context.read<WebCompanionRepository>().updatePreferredTags(
        next.preferredTags,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _accountSettings = previous);
      showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _addTag() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    _tagController.clear();
    await _toggleTag(tag);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        WebReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WebPageHeader(
                title: 'Settings',
                subtitle: 'Canvas, notification and account preferences.',
              ),
              if (_loading) const WebLoading(),
              if (_error != null) WebErrorBox(message: _error!),
              if (!_loading && _error == null) ...[
                const WebSectionLabel('Canvas'),
                _TileGroup(
                  children: <Widget>[
                    _SwitchTile(
                      title: 'Show tool tray tips',
                      subtitle:
                          'Hints that explain a tool the first time you use it.',
                      value: _trayTips,
                      onChanged: (value) {
                        setState(() => _trayTips = value);
                        _settings?.setShowTrayTips(value);
                      },
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: InkSpacing.s12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Board preview quality',
                            style: InkType.bodyStrong(tokens.ink),
                          ),
                          const SizedBox(height: InkSpacing.s8),
                          Wrap(
                            spacing: InkSpacing.s8,
                            children: [
                              for (final (value, label) in const [
                                (BoardPreviewPreferences.low, 'Low'),
                                (BoardPreviewPreferences.medium, 'Medium'),
                                (BoardPreviewPreferences.high, 'High'),
                              ])
                                WebChoiceChip(
                                  label: label,
                                  selected: _quality == value,
                                  onSelected: () {
                                    setState(() => _quality = value);
                                    _settings?.setBoardPreviewQuality(value);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Compress previews',
                      subtitle: 'Smaller previews use less space and battery.',
                      value: _compression,
                      onChanged: (value) {
                        setState(() => _compression = value);
                        _settings?.setBoardPreviewCompressionEnabled(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s16),
                const WebSectionLabel('Alerts'),
                _TileGroup(
                  children: <Widget>[
                    _SwitchTile(
                      title: 'Push notifications',
                      value: _push,
                      onChanged: (value) {
                        setState(() => _push = value);
                        _settings?.setPushNotificationsEnabled(value, _uid);
                      },
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Invite alerts',
                      value: _invite,
                      onChanged: (value) {
                        setState(() => _invite = value);
                        _settings?.setInviteAlertsEnabled(value, _uid);
                      },
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Friend alerts',
                      value: _friend,
                      onChanged: (value) {
                        setState(() => _friend = value);
                        _settings?.setFriendAlertsEnabled(value, _uid);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: InkSpacing.s12),
                      child: Text(
                        'Push delivery needs the mobile app; these choices '
                        'apply to the alerts the phone sends.',
                        style: InkType.caption(tokens.inkMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s16),
                const WebSectionLabel('Privacy'),
                _TileGroup(
                  children: <Widget>[
                    _SwitchTile(
                      title: 'Public profile',
                      subtitle:
                          'Let non-friends view your profile and public boards.',
                      value: _accountSettings.isProfilePublic,
                      onChanged: (value) => _setPrivacy(isProfilePublic: value),
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Show online status',
                      subtitle: 'Let collaborators see when you are active.',
                      value: _accountSettings.showOnlineStatus,
                      onChanged: (value) =>
                          _setPrivacy(showOnlineStatus: value),
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Show email address',
                      subtitle: 'Display your email on your public profile.',
                      value: _accountSettings.showEmail,
                      onChanged: (value) => _setPrivacy(showEmail: value),
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s16),
                const WebSectionLabel('Content preferences'),
                PaperCard(
                  padding: const EdgeInsets.all(InkSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferred content tags',
                        style: InkType.bodyStrong(tokens.ink),
                      ),
                      const SizedBox(height: InkSpacing.s4),
                      Text(
                        'Topics that shape the boards Discover recommends.',
                        style: InkType.caption(tokens.inkMuted),
                      ),
                      const SizedBox(height: InkSpacing.s12),
                      Wrap(
                        spacing: InkSpacing.s8,
                        runSpacing: InkSpacing.s8,
                        children: [
                          for (final tag in _accountSettings.preferredTags)
                            InkChip(
                              label: '#$tag',
                              selected: true,
                              onTap: () => _toggleTag(tag),
                            ),
                          for (final tag in WebAccountSettings.suggestedTags)
                            if (!_accountSettings.preferredTags.any(
                              (chosen) =>
                                  chosen.toLowerCase() == tag.toLowerCase(),
                            ))
                              InkChip(
                                label: '#$tag',
                                onTap: () => _toggleTag(tag),
                              ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.s12),
                      Row(
                        children: [
                          Expanded(
                            child: InkTextField(
                              controller: _tagController,
                              hintText: 'Add a custom tag',
                              onSubmitted: (_) => _addTag(),
                            ),
                          ),
                          const SizedBox(width: InkSpacing.s8),
                          InkButton.secondary(
                            label: 'Add',
                            compact: true,
                            expand: false,
                            onPressed: _addTag,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s16),
                const WebSectionLabel('Storage'),
                _TileGroup(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(LucideIcons.trash2, color: tokens.ink),
                      title: Text(
                        'Clear local cache',
                        style: InkType.bodyStrong(tokens.ink),
                      ),
                      subtitle: Text(
                        'Removes cached images and stored preferences data.',
                        style: InkType.caption(tokens.inkMuted),
                      ),
                      onTap: _clearCache,
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s16),
                const WebSectionLabel('Account'),
                PaperCard(
                  padding: const EdgeInsets.all(InkSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkButton.secondary(
                        label: 'Sign out',
                        icon: Icon(
                          LucideIcons.logOut,
                          size: 16,
                          color: tokens.ink,
                        ),
                        onPressed: _busy ? null : _signOut,
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      InkButton.danger(
                        label: 'Delete account',
                        icon: Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: tokens.danger,
                        ),
                        isLoading: _busy,
                        onPressed: _busy ? null : _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
