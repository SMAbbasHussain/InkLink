import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_colors.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/auth_hero.dart';
import '../../../../ui/widgets/sticky_note.dart';

/// Left column on desktop sign-in: the live-board hero and feature highlights.
class WebAuthBrandingPanel extends StatelessWidget {
  const WebAuthBrandingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 180,
          width: double.infinity,
          child: ExcludeSemantics(child: AuthHero()),
        ),
        const SizedBox(height: InkSpacing.s16),
        Text('InkLink, on any computer', style: InkType.display(ink.ink)),
        const SizedBox(height: InkSpacing.s8),
        Text(
          'Open your boards, draw together live and keep up with your '
          'people, right from the browser.',
          style: InkType.body(ink.inkSecondary),
        ),
        const SizedBox(height: InkSpacing.s24),
        const Wrap(
          spacing: InkSpacing.s16,
          runSpacing: InkSpacing.s16,
          children: [
            _IntroNote(
              color: InkColors.stickyButter,
              icon: LucideIcons.layoutGrid,
              title: 'Your boards',
              text: 'Open any board and draw with your team in real time.',
              tiltId: 'web-intro-boards',
            ),
            _IntroNote(
              color: InkColors.stickyMint,
              icon: LucideIcons.mailOpen,
              title: 'Invites',
              text: 'Accept board and workspace invites in one click.',
              tiltId: 'web-intro-invites',
            ),
            _IntroNote(
              color: InkColors.stickyLilac,
              icon: LucideIcons.users,
              title: 'Friends',
              text: 'Answer friend requests and catch up on notifications.',
              tiltId: 'web-intro-friends',
            ),
          ],
        ),
      ],
    );
  }
}

class _IntroNote extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final String tiltId;

  const _IntroNote({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    required this.tiltId,
  });

  @override
  Widget build(BuildContext context) {
    const noteInk = InkColors.stickyInkDefault;
    return SizedBox(
      width: 168,
      child: StickyNote(
        color: color,
        tiltId: tiltId,
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: noteInk),
            const SizedBox(height: InkSpacing.s8),
            Text(title, style: InkType.bodyStrong(noteInk)),
            const SizedBox(height: InkSpacing.s4),
            Text(text, style: InkType.caption(noteInk)),
          ],
        ),
      ),
    );
  }
}

/// Horizontal divider labeled "or" between email/password and Google auth.
class WebAuthOrDivider extends StatelessWidget {
  final Color color;
  final Color textColor;

  const WebAuthOrDivider({
    super.key,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: color)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or', style: InkType.caption(textColor)),
      ),
      Expanded(child: Divider(color: color)),
    ],
  );
}

/// Banner shown when a visitor follows a `/board/<id>` link before signing in.
class WebTargetBoardBanner extends StatelessWidget {
  const WebTargetBoardBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(InkSpacing.s12),
        decoration: BoxDecoration(
          color: ink.accentSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ink.glassStroke),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.layoutGrid, size: 18, color: ink.accentText),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: Text(
                'A board is waiting for you. Sign in or create an account to '
                'open it.',
                style: InkType.caption(ink.accentText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App-icon badge displayed above the web sign-in card.
class WebLogoTile extends StatelessWidget {
  final double size;
  const WebLogoTile({super.key, this.size = 68});

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Semantics(
      label: 'InkLink',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.147),
        decoration: BoxDecoration(
          color: ink.paper,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: ink.paperShadow,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: ink.accentGradient,
            borderRadius: BorderRadius.circular(size * 0.235),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.235),
            child: Image.asset('images/app_icon.png', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
