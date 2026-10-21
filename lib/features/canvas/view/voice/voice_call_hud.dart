import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/canvas_bloc.dart';

class VoiceCallHud extends StatelessWidget {
  const VoiceCallHud({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (prev, curr) =>
          prev.isVoiceCallActive != curr.isVoiceCallActive ||
          prev.isMicMuted != curr.isMicMuted ||
          prev.voiceParticipants != curr.voiceParticipants,
      builder: (context, state) {
        if (!state.isVoiceCallActive && state.voiceParticipants.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 70,
          left: 20,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(30),
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: state.isVoiceCallActive
                      ? Colors.green.withOpacity(0.4)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: 1.5,
                ),
              ),
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
                          ? Colors.greenAccent
                          : Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),

                  Text(
                    'Voice Call',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Participant Avatars
                  ...state.voiceParticipants.map((p) => _ParticipantAvatar(
                        participant: p,
                      )),

                  const SizedBox(width: 8),

                  // Mute / Unmute Button
                  IconButton(
                    icon: Icon(
                      state.isMicMuted ? Icons.mic_off : Icons.mic,
                      size: 20,
                      color: state.isMicMuted ? Colors.redAccent : null,
                    ),
                    tooltip: state.isMicMuted ? 'Unmute Mic' : 'Mute Mic',
                    splashRadius: 18,
                    onPressed: () {
                      context
                          .read<CanvasBloc>()
                          .add(const CanvasToggleVoiceMuteRequested());
                    },
                  ),

                  // End Call / Join Call Button
                  if (state.isVoiceCallActive)
                    IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Leave Call',
                      splashRadius: 18,
                      onPressed: () {
                        context
                            .read<CanvasBloc>()
                            .add(const CanvasLeaveVoiceCallRequested());
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.call,
                        size: 20,
                        color: Colors.green,
                      ),
                      tooltip: 'Join Call',
                      splashRadius: 18,
                      onPressed: () {
                        context
                            .read<CanvasBloc>()
                            .add(const CanvasJoinVoiceCallRequested());
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final VoiceParticipant participant;

  const _ParticipantAvatar({required this.participant});

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
                  color: isSpeaking ? Colors.green : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSpeaking
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueGrey.shade700,
                backgroundImage: participant.photoUrl != null
                    ? NetworkImage(participant.photoUrl!)
                    : null,
                child: participant.photoUrl == null
                    ? Text(
                        participant.displayName.isNotEmpty
                            ? participant.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            if (isMuted)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_off,
                    size: 9,
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
