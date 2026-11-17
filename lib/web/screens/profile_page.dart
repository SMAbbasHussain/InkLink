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
            return WebReadableWidth(maxWidth: 620, child: _buildCard(context, profile));
          },
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, UserModel profile) {
    final ink = context.ink;
    const bannerHeight = 120.0;
    const avatarSize = 92.0;
    final hasBio = (profile.bio ?? '').trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: ink.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink.glassStroke),
        boxShadow: ink.paperShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner with the avatar overlapping its bottom edge.
          SizedBox(
            height: bannerHeight + avatarSize / 2,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: bannerHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: ink.accentGradient),
                    child: const CustomPaint(painter: _BannerPainter()),
                  ),
                ),
                Positioned(
                  left: InkSpacing.s24,
                  top: bannerHeight - avatarSize / 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: ink.paper, shape: BoxShape.circle),
                    child: InkAvatar(
                      id: profile.uid,
                      imageUrl: profile.photoURL,
                      initials: initialsOf(profile.displayName),
                      size: avatarSize - 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InkSpacing.s24,
              InkSpacing.s12,
              InkSpacing.s24,
              InkSpacing.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName, style: InkType.headline(ink.ink)),
                const SizedBox(height: 2),
                Text(profile.email, style: InkType.body(ink.inkMuted)),
                const SizedBox(height: InkSpacing.s20),
                Wrap(
                  spacing: InkSpacing.s12,
                  runSpacing: InkSpacing.s12,
                  children: [
                    _StatTile(
                      icon: LucideIcons.layoutGrid,
                      value: '${profile.boardCount}',
                      label: profile.boardCount == 1 ? 'Board' : 'Boards',
                    ),
                    _StatTile(
                      icon: LucideIcons.users,
                      value: '${profile.friendCount}',
                      label: profile.friendCount == 1 ? 'Friend' : 'Friends',
                    ),
                    _StatTile(
                      icon: LucideIcons.calendarDays,
                      value: memberSince(profile.createdAt),
                      label: 'Member since',
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s24),
                if (!_editing) ...[
                  Text('About', style: InkType.label(ink.inkMuted)),
                  const SizedBox(height: InkSpacing.s8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(InkSpacing.s16),
                    decoration: BoxDecoration(
                      color: ink.field,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasBio ? profile.bio! : 'No bio yet.',
                      style: InkType.body(hasBio ? ink.ink : ink.inkMuted),
                    ),
                  ),
                  const SizedBox(height: InkSpacing.s20),
                  // The theme gives buttons an infinite minimum width, so
                  // size them explicitly here.
                  SizedBox(
                    width: 180,
                    child: InkButton(
                      label: 'Edit profile',
                      variant: InkButtonVariant.secondary,
                      icon: Icon(LucideIcons.pencil, size: 16, color: ink.ink),
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
                          onPressed: _saving ? null : () => setState(() => _editing = false),
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
                Row(
                  children: [
                    Icon(LucideIcons.smartphone, size: 14, color: ink.inkMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'To change your photo, use the InkLink mobile app.',
                        style: InkType.caption(ink.inkMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatTile({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ink.glassStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ink.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: ink.accentText),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: InkType.bodyStrong(ink.ink)),
              Text(label, style: InkType.caption(ink.inkMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soft white dots and strokes over the gradient banner.
class _BannerPainter extends CustomPainter {
  const _BannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (double x = 12; x < w; x += 18) {
      for (double y = 10; y < h; y += 18) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.42, h * 0.72)
        ..cubicTo(w * 0.55, h * 0.15, w * 0.7, h * 0.95, w * 0.95, h * 0.3),
      stroke,
    );
    canvas.drawCircle(Offset(w * 0.84, h * 0.62), 14, stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_BannerPainter oldDelegate) => false;
}
