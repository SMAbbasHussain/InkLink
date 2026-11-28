import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/utils/board_preview_preferences.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_chip.dart';
import '../../ui/widgets/ink_dialog.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/paper_card.dart';
import '../bloc/web_auth_cubit.dart';
import '../bloc/web_settings_cubit.dart';
import '../data/web_account_settings.dart';
import '../widgets/web_widgets.dart';
import 'web_shell_nav.dart';

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

/// The web companion's settings screen. Purely presentational: reads state
/// from [WebSettingsCubit] and dispatches account actions to [WebAuthCubit].
class WebSettingsPage extends StatefulWidget {
  const WebSettingsPage({super.key});

  @override
  State<WebSettingsPage> createState() => _WebSettingsPageState();
}

class _WebSettingsPageState extends State<WebSettingsPage> {
  final _tagController = TextEditingController();
  bool _busy = false;

  WebSettingsCubit get _settingsCubit => context.read<WebSettingsCubit>();

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _signOut() => context.read<WebAuthCubit>().signOut();

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
      await context.read<WebAuthCubit>().deleteAccount();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showWebMessage(context, webErrorText(e), isError: true);
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      await _settingsCubit.clearLocalCache();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      if (mounted) showWebMessage(context, 'Local cache cleared.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _setPrivacy({
    bool? isProfilePublic,
    bool? showOnlineStatus,
    bool? showEmail,
  }) async {
    try {
      await _settingsCubit.updatePrivacy(
        isProfilePublic: isProfilePublic,
        showOnlineStatus: showOnlineStatus,
        showEmail: showEmail,
      );
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _toggleTag(String tag) async {
    try {
      await _settingsCubit.togglePreferredTag(tag);
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
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
    final state = context.watch<WebSettingsCubit>().state;
    final accountSettings = state.accountSettings;
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
              if (state.loading) const WebLoading(),
              if (state.error != null)
                WebErrorBox(message: webErrorText(state.error!)),
              if (!state.loading && state.error == null) ...[
                const WebSectionLabel('Canvas'),
                _TileGroup(
                  children: <Widget>[
                    _SwitchTile(
                      title: 'Show tool tray tips',
                      subtitle:
                          'Hints that explain a tool the first time you use it.',
                      value: state.trayTips,
                      onChanged: _settingsCubit.setShowTrayTips,
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
                                  selected: state.quality == value,
                                  onSelected: () => _settingsCubit
                                      .setBoardPreviewQuality(value),
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
                      value: state.compression,
                      onChanged:
                          _settingsCubit.setBoardPreviewCompressionEnabled,
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s16),
                const WebSectionLabel('Alerts'),
                _TileGroup(
                  children: <Widget>[
                    _SwitchTile(
                      title: 'Push notifications',
                      value: state.pushEnabled,
                      onChanged: _settingsCubit.setPushNotificationsEnabled,
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Invite alerts',
                      value: state.inviteAlertsEnabled,
                      onChanged: _settingsCubit.setInviteAlertsEnabled,
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Friend alerts',
                      value: state.friendAlertsEnabled,
                      onChanged: _settingsCubit.setFriendAlertsEnabled,
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
                      value: accountSettings.isProfilePublic,
                      onChanged: (value) => _setPrivacy(isProfilePublic: value),
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Show online status',
                      subtitle: 'Let collaborators see when you are active.',
                      value: accountSettings.showOnlineStatus,
                      onChanged: (value) =>
                          _setPrivacy(showOnlineStatus: value),
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    _SwitchTile(
                      title: 'Show email address',
                      subtitle: 'Display your email on your public profile.',
                      value: accountSettings.showEmail,
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
                          for (final tag in accountSettings.preferredTags)
                            InkChip(
                              label: '#$tag',
                              selected: true,
                              onTap: () => _toggleTag(tag),
                            ),
                          for (final tag in WebAccountSettings.suggestedTags)
                            if (!accountSettings.preferredTags.any(
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
