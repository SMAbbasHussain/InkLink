import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/paper_card.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class EmailVerificationScreen extends StatefulWidget {
  final User user;
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.user,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  void _handleResend() {
    if (_cooldownSeconds > 0) return;
    context.read<AuthBloc>().add(SendEmailVerificationRequested());
    _startCooldown();
  }

  void _handleCheckVerified() {
    context.read<AuthBloc>().add(CheckEmailVerificationRequested());
  }

  void _handleLogout() {
    context.read<AuthBloc>().add(LogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.ban, size: 16, color: tokens.danger),
                    const SizedBox(width: InkSpacing.s8),
                    Flexible(child: Text(state.message)),
                  ],
                ),
              ),
            );
          } else if (state is AuthEmailUnverified && state.message != null) {
            final isWarning = state.message!.contains('not verified');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWarning ? LucideIcons.circleAlert : LucideIcons.check,
                      size: 16,
                      color: isWarning ? tokens.pending : tokens.success,
                    ),
                    const SizedBox(width: InkSpacing.s8),
                    Flexible(child: Text(state.message!)),
                  ],
                ),
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading =
                (state is AuthEmailUnverified && state.isChecking) ||
                state is AuthLoading;

            return DeskBackground(
              child: Stack(
                children: [
                  SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: InkSpacing.s20,
                          vertical: InkSpacing.s24,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: PaperCard(
                            hasTape: true,
                            padding: const EdgeInsets.all(InkSpacing.s24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: InkSpacing.s8),

                                // 1. Icon Tile
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: tokens.accentSoft,
                                    borderRadius: BorderRadius.circular(InkRadii.input),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.mailCheck,
                                      size: 32,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: InkSpacing.s20),

                                // 2. Title & Explanation
                                Text(
                                  "Check Your Mail",
                                  style: InkType.headline(tokens.ink),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: InkSpacing.s8),
                                Text(
                                  "We sent a verification link to:",
                                  style: InkType.body(tokens.inkSecondary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: InkSpacing.s8),

                                // 3. Email Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: InkSpacing.s16,
                                    vertical: InkSpacing.s8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.field,
                                    borderRadius: BorderRadius.circular(InkRadii.button),
                                    border: Border.all(color: tokens.glassStroke),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.mail,
                                        size: 16,
                                        color: tokens.accent,
                                      ),
                                      const SizedBox(width: InkSpacing.s8),
                                      Flexible(
                                        child: Text(
                                          widget.email,
                                          style: InkType.bodyStrong(tokens.ink),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: InkSpacing.s16),

                                Text(
                                  "Please open your email inbox (or spam folder) and click the verification link. Once clicked, tap the button below to continue.",
                                  textAlign: TextAlign.center,
                                  style: InkType.body(tokens.inkSecondary),
                                ),

                                const SizedBox(height: InkSpacing.s24),

                                // 4. Primary Button: I've Verified / Clicked The Link
                                isLoading
                                    ? Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: tokens.accentGradient,
                                          borderRadius: BorderRadius.circular(InkRadii.button),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                        ),
                                      )
                                    : InkButton.hero(
                                        label: "I've Clicked The Link — Continue",
                                        onPressed: _handleCheckVerified,
                                      ),

                                const SizedBox(height: InkSpacing.s12),

                                // 5. Secondary Button: Resend Email
                                InkButton.secondary(
                                  label: _cooldownSeconds > 0
                                      ? "Resend link in ${_cooldownSeconds}s"
                                      : "Resend Verification Link",
                                  icon: const Icon(LucideIcons.refreshCw),
                                  onPressed: (_cooldownSeconds > 0 || isLoading)
                                      ? null
                                      : _handleResend,
                                ),

                                const SizedBox(height: InkSpacing.s20),

                                // 6. Sign Out Button
                                TextButton.icon(
                                  onPressed: isLoading ? null : _handleLogout,
                                  icon: Icon(
                                    LucideIcons.logOut,
                                    size: 16,
                                    color: tokens.inkMuted,
                                  ),
                                  label: Text(
                                    "Sign in with a different account",
                                    style: InkType.caption(tokens.inkMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: Center(
                          child: GlassPanel(
                            radius: InkRadii.dialog,
                            padding: const EdgeInsets.all(InkSpacing.s24),
                            child: CircularProgressIndicator(color: tokens.accent),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
