import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/user_model.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/desk_background.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/paper_card.dart';
import '../bloc/web_social_cubit.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';
import 'web_shell_nav.dart';

/// View and edit the display name, bio and profile photo, laid out like the
/// phone's profile: centred avatar over the desk, name, stat cards and the
/// bio. The photo goes through the same `uploadProfilePhoto` function as the
/// phone (base64 payload).
class WebProfilePage extends StatefulWidget {
  const WebProfilePage({super.key});

  @override
  State<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends State<WebProfilePage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  bool _uploading = false;
  String? _nameError;
  String? _bioError;

  WebSocialCubit get _social => context.read<WebSocialCubit>();

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _startEditing(UserModel profile) {
    _name.text = profile.displayName;
    _bio.text = profile.bio ?? '';
    setState(() {
      _editing = true;
      _nameError = null;
      _bioError = null;
    });
  }

  Future<void> _changePhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) throw 'That image could not be read.';
      final filename = picked.name.toLowerCase().endsWith('.png')
          ? 'avatar.png'
          : 'avatar.jpg';
      setState(() => _uploading = true);
      await _social.uploadProfilePhoto(bytes, filename: filename);
      if (mounted) showWebMessage(context, 'Profile photo updated.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final nameError = validateDisplayName(_name.text);
    final bioError = validateBio(_bio.text);
    setState(() {
      _nameError = nameError;
      _bioError = bioError;
    });
    if (nameError != null || bioError != null) return;
    setState(() => _saving = true);
    try {
      await _social.updateProfile(name: _name.text, bio: _bio.text);
      if (!mounted) return;
      setState(() => _editing = false);
      showWebMessage(context, 'Profile saved.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WebSocialCubit>().state;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        if (state.profileError != null)
          WebErrorBox(message: webErrorText(state.profileError!))
        else if (state.profile == null)
          const WebLoading()
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _buildProfile(state.profile!),
            ),
          ),
      ],
    );
  }

  Widget _buildProfile(UserModel profile) {
    final tokens = context.ink;
    final hasBio = (profile.bio ?? '').trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The phone's header: the desk with the avatar overlapping it.
        SizedBox(
          height: 180 + 48,
          child: Stack(
            children: [
              // The phone's desk-dot cover, tinted so it stands out on the
              // page (which is itself the desk).
              Container(
                height: 180,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InkRadii.card),
                  border: Border.all(color: tokens.glassStroke),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DeskBackground(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.accentSoft.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 180 - 48,
                left: 0,
                right: 0,
                child: Center(
                  child: InkAvatar(
                    imageUrl: profile.photoURL,
                    initials: initialsOf(profile.displayName),
                    id: profile.uid,
                    size: 96,
                    ring: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: InkSpacing.s12),
        Text(
          profile.displayName,
          style: InkType.headline(tokens.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: InkSpacing.s4),
        Text(
          profile.email,
          style: InkType.body(tokens.inkSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: InkSpacing.s20),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: '${profile.boardCount}',
                label: profile.boardCount == 1 ? 'Board' : 'Boards',
              ),
            ),
            const SizedBox(width: InkSpacing.s12),
            Expanded(
              child: _Stat(
                value: '${profile.friendCount}',
                label: profile.friendCount == 1 ? 'Friend' : 'Friends',
              ),
            ),
            const SizedBox(width: InkSpacing.s12),
            Expanded(
              child: _Stat(
                value: memberSince(profile.createdAt),
                label: 'Member since',
              ),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.s16),
        if (!_editing) ...[
          PaperCard(
            padding: const EdgeInsets.all(InkSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: InkType.subhead(tokens.inkSecondary)),
                const SizedBox(height: InkSpacing.s8),
                Text(
                  hasBio ? profile.bio! : 'No bio yet.',
                  style: InkType.body(hasBio ? tokens.ink : tokens.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s16),
          InkButton.secondary(
            label: 'Edit profile',
            icon: Icon(LucideIcons.pencil, size: 16, color: tokens.ink),
            onPressed: () => _startEditing(profile),
          ),
        ] else ...[
          PaperCard(
            padding: const EdgeInsets.all(InkSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkTextField(
                  controller: _name,
                  labelText: 'Name',
                  errorText: _nameError,
                  enabled: !_saving,
                ),
                const SizedBox(height: InkSpacing.s12),
                InkTextField(
                  controller: _bio,
                  labelText: 'Bio',
                  errorText: _bioError,
                  maxLines: 3,
                  enabled: !_saving,
                ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s16),
          Row(
            children: [
              Expanded(
                child: InkButton.secondary(
                  label: 'Cancel',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _editing = false),
                ),
              ),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: InkButton.primary(
                  label: 'Save',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: InkSpacing.s16),
        InkButton.secondary(
          label: 'Change photo',
          icon: Icon(LucideIcons.camera, size: 16, color: tokens.ink),
          isLoading: _uploading,
          onPressed: _uploading ? null : _changePhoto,
        ),
      ],
    );
  }
}

/// A stat card like the phone's (value over label).
class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return PaperCard(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s8,
        vertical: InkSpacing.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: InkType.title(tokens.ink),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: InkType.caption(tokens.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
