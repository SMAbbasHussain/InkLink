import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/user_model.dart';
import '../../ui/widgets/ink_avatar.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';
import '../widgets/web_widgets.dart';
import 'home_shell.dart' show GlassAvatarRing;

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
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
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
                padding: EdgeInsets.all(32),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Glass.accentText),
                  ),
                ),
              );
            }
            return WebReadableWidth(maxWidth: 640, child: _buildCard(profile));
          },
        ),
      ],
    );
  }

  Widget _buildCard(UserModel profile) {
    const bannerHeight = 132.0;
    const avatarSize = 96.0;
    final hasBio = (profile.bio ?? '').trim().isNotEmpty;
    return GlassPanel(
      blur: true, // persistent surface
      radius: Glass.r28,
      shadow: Glass.shadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: bannerHeight + avatarSize / 2,
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: bannerHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(Glass.r28)),
                    child: _MeshBanner(),
                  ),
                ),
                Positioned(
                  left: 24,
                  top: bannerHeight - avatarSize / 2,
                  child: GlassAvatarRing(
                    width: 2.5,
                    glow: true,
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
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName, style: Glass.heading(size: 26)),
                const SizedBox(height: 2),
                Text(profile.email, style: Glass.body(color: Glass.textMuted)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
                const SizedBox(height: 24),
                if (!_editing) ...[
                  Text('ABOUT', style: Glass.label()),
                  const SizedBox(height: 8),
                  GlassPanel(
                    strong: true,
                    radius: Glass.r14,
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        hasBio ? profile.bio! : 'No bio yet.',
                        style: Glass.body(color: hasBio ? Glass.text : Glass.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassButton.ghost(
                    label: 'Edit profile',
                    icon: LucideIcons.pencil,
                    onPressed: () => _startEditing(profile),
                  ),
                ] else ...[
                  InkTextField(
                    controller: _name,
                    labelText: 'Name',
                    errorText: _nameError,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  InkTextField(
                    controller: _bio,
                    labelText: 'Bio',
                    errorText: _bioError,
                    maxLines: 3,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GlassButton.ghost(
                        label: 'Cancel',
                        onPressed: _saving ? null : () => setState(() => _editing = false),
                      ),
                      const SizedBox(width: 10),
                      GlassButton.primary(label: 'Save', loading: _saving, onPressed: _saving ? null : _save),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(LucideIcons.smartphone, size: 14, color: Glass.textMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'To change your photo, use the InkLink mobile app.',
                        style: Glass.small(),
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
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Glass.bg,
        gradient: Glass.sheen,
        borderRadius: BorderRadius.circular(Glass.r14),
        border: Border.all(color: Glass.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x268B5CF6),
              borderRadius: BorderRadius.circular(Glass.r10),
              border: Border.all(color: const Color(0x338B5CF6)),
            ),
            child: Icon(icon, size: 17, color: Glass.accentText),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Glass.strong()),
              Text(label, style: Glass.small()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated gradient mesh with the squiggle drawing itself in on load.
/// With reduced motion it is static and fully drawn.
class _MeshBanner extends StatefulWidget {
  const _MeshBanner();

  @override
  State<_MeshBanner> createState() => _MeshBannerState();
}

class _MeshBannerState extends State<_MeshBanner> with TickerProviderStateMixin {
  late final AnimationController _mesh =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));
  late final AnimationController _draw =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Glass.reduceMotion(context)) {
      _draw.value = 1;
    } else {
      _mesh.repeat();
      _draw.forward();
    }
  }

  @override
  void dispose() {
    _mesh.dispose();
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MeshPainter(mesh: _mesh, draw: _draw),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Animation<double> mesh;
  final Animation<double> draw;
  _MeshPainter({required this.mesh, required this.draw})
      : super(repaint: Listenable.merge([mesh, draw]));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final a = mesh.value * 2 * math.pi;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B1446));

    void blob(Color c, double cx, double cy, double r) {
      final center = Offset(cx * w, cy * h);
      canvas.drawCircle(
        center,
        r * w,
        Paint()
          ..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: r * w)),
      );
    }

    blob(Glass.violet.withValues(alpha: 0.95), 0.25 + 0.08 * math.sin(a), 0.2, 0.55);
    blob(Glass.indigo.withValues(alpha: 0.9), 0.75 + 0.07 * math.cos(a), 0.6, 0.5);
    blob(Glass.magenta.withValues(alpha: 0.55), 0.55 + 0.1 * math.sin(a + 2), 1.0, 0.35);
    blob(Glass.cyan.withValues(alpha: 0.25), 0.05 + 0.05 * math.cos(a + 1), 0.9, 0.3);

    // Faint dots.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (double x = 12; x < w; x += 18) {
      for (double y = 10; y < h; y += 18) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }

    // The squiggle, drawn in progressively.
    final squiggle = Path()
      ..moveTo(w * 0.40, h * 0.74)
      ..cubicTo(w * 0.53, h * 0.12, w * 0.68, h * 0.96, w * 0.95, h * 0.28);
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final t = Curves.easeInOut.transform(draw.value);
    for (final PathMetric m in squiggle.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), stroke);
    }
    if (t > 0.7) {
      final ring = Paint()
        ..color = Colors.white.withValues(alpha: 0.45 * ((t - 0.7) / 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(w * 0.84, h * 0.62), 14, ring);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) => false;
}
