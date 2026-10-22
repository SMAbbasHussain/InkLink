import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_initials.dart';
import '../../bloc/canvas_bloc.dart';

class VoiceCallHud extends StatelessWidget {
  const VoiceCallHud({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (prev, curr) =>
          prev.isVoiceCallActive != curr.isVoiceCallActive ||
          prev.isMicMuted != curr.isMicMuted ||
          prev.voiceParticipants != curr.voiceParticipants,
      builder: (context, state) {
        if (!state.isVoiceCallActive && state.voiceParticipants.isEmpty) {
          return const SizedBox.shrink();
        }

        final topInset = MediaQuery.of(context).padding.top + 64;

        return Positioned(
          top: topInset,
          left: 16,
          child: GlassPanel(
            radius: InkRadii.pill,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Call status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.isVoiceCallActive
                        ? tokens.success
                        : tokens.pending,
                  ),
                ),
                const SizedBox(width: InkSpacing.s8),

                Text(
                  'Voice Call',
                  style: InkType.label(tokens.ink),
                ),
                const SizedBox(width: InkSpacing.s12),

                // Participant Avatars
                ...state.voiceParticipants.map((p) => _ParticipantAvatar(
                      participant: p,
                      tokens: tokens,
                    )),

                const SizedBox(width: InkSpacing.s8),

                // Mute / Unmute Button
                IconButton(
                  icon: Icon(
                    state.isMicMuted ? LucideIcons.micOff : LucideIcons.mic,
                    size: 18,
                    color: state.isMicMuted ? tokens.danger : tokens.ink,
                  ),
                  tooltip: state.isMicMuted ? 'Unmute Mic' : 'Mute Mic',
                  onPressed: () {
                    context
                        .read<CanvasBloc>()
                        .add(const CanvasToggleVoiceMuteRequested());
                  },
                ),

                // End Call / Join Call Button
                if (state.isVoiceCallActive)
                  IconButton(
                    icon: Icon(
                      LucideIcons.phoneOff,
                      size: 18,
                      color: tokens.danger,
                    ),
                    tooltip: 'Leave Call',
                    onPressed: () {
                      context
                          .read<CanvasBloc>()
                          .add(const CanvasLeaveVoiceCallRequested());
                    },
                  )
                else
                  IconButton(
                    icon: Icon(
                      LucideIcons.phone,
                      size: 18,
                      color: tokens.success,
                    ),
                    tooltip: 'Join Call',
                    onPressed: () {
                      context
                          .read<CanvasBloc>()
                          .add(const CanvasJoinVoiceCallRequested());
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final VoiceParticipant participant;
  final InkTokens tokens;

  const _ParticipantAvatar({
    required this.participant,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final isSpeaking = participant.isSpeaking;
    final isMuted = participant.isMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: '${participant.displayName}${isSpeaking ? " (Speaking)" : ""}${isMuted ? " (Muted)" : ""}',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking ? tokens.success : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSpeaking
                    ? [
                        BoxShadow(
                          color: tokens.success.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: InkAvatar(
                imageUrl: participant.photoUrl,
                initials: inkInitialsFor(participant.displayName),
                id: participant.uid,
                size: 26,
              ),
            ),
            if (isMuted)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: tokens.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.micOff,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
