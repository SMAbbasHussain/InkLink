import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/user_model.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';

/// View and edit the display name and bio. The profile photo is changed in
/// the mobile app.
class WebProfilePage extends StatefulWidget {
  const WebProfilePage({super.key});

  @override
  State<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends State<WebProfilePage> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<UserModel?> _profile = _repo.watchMyProfile();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _nameError;
  String? _bioError;

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
      await _repo.updateProfile(name: _name.text, bio: _bio.text);
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
    final ink = context.ink;
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
      children: [
        const WebPageHeader(title: 'Profile'),
        StreamBuilder<UserModel?>(
          stream: _profile,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return WebErrorBox(message: webErrorText(snapshot.error!));
            }
            final profile = snapshot.data;
            if (profile == null) {
              return const Padding(
                padding: EdgeInsets.all(InkSpacing.s32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return WebReadableWidth(
              maxWidth: 560,
              child: PaperCard(
                padding: const EdgeInsets.all(InkSpacing.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkAvatar(
                          id: profile.uid,
                          imageUrl: profile.photoURL,
                          initials: initialsOf(profile.displayName),
                          size: 64,
                        ),
                        const SizedBox(width: InkSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                style: InkType.title(ink.ink),
                              ),
                              Text(
                                profile.email,
                                style: InkType.caption(ink.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    Text(
                      '${profile.boardCount} ${profile.boardCount == 1 ? 'board' : 'boards'}'
                      ' · ${profile.friendCount} ${profile.friendCount == 1 ? 'friend' : 'friends'}',
                      style: InkType.body(ink.inkSecondary),
                    ),
                    const SizedBox(height: InkSpacing.s24),
                    if (!_editing) ...[
                      Text('Bio', style: InkType.label(ink.inkMuted)),
                      const SizedBox(height: InkSpacing.s4),
                      Text(
                        (profile.bio ?? '').trim().isEmpty
                            ? 'No bio yet.'
                            : profile.bio!,
                        style: InkType.body(ink.ink),
                      ),
                      const SizedBox(height: InkSpacing.s24),
                      // The theme gives buttons an infinite minimum width,
                      // so size them explicitly here.
                      SizedBox(
                        width: 180,
                        child: InkButton(
                          label: 'Edit profile',
                          variant: InkButtonVariant.secondary,
                          icon: Icon(
                            LucideIcons.pencil,
                            size: 16,
                            color: ink.ink,
                          ),
                          onPressed: () => _startEditing(profile),
                        ),
                      ),
                    ] else ...[
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
                      const SizedBox(height: InkSpacing.s16),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: InkButton(
                              label: 'Cancel',
                              variant: InkButtonVariant.secondary,
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _editing = false),
                            ),
                          ),
                          const SizedBox(width: InkSpacing.s12),
                          SizedBox(
                            width: 120,
                            child: InkButton(
                              label: 'Save',
                              isLoading: _saving,
                              onPressed: _saving ? null : _save,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: InkSpacing.s16),
                    Text(
                      'To change your photo, use the InkLink mobile app.',
                      style: InkType.caption(ink.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
