import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/desk_background.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_auth_cubit.dart';

/// Shown when an email/password account has not verified its email yet.
class WebVerifyEmailScreen extends StatefulWidget {
  final String email;
  const WebVerifyEmailScreen({super.key, required this.email});

  @override
  State<WebVerifyEmailScreen> createState() => _WebVerifyEmailScreenState();
}

class _WebVerifyEmailScreenState extends State<WebVerifyEmailScreen> {
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final verified = await context.read<WebAuthCubit>().reloadEmailVerified();
      if (!mounted) return;
      if (!verified) {
        showWebMessage(
          context,
          'Not verified yet. Check your inbox and spam folder.',
        );
      }
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<WebAuthCubit>().resendVerificationEmail();
      if (mounted) {
        showWebMessage(context, 'Verification email sent to ${widget.email}.');
      }
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Scaffold(
      backgroundColor: ink.surfaceDesk,
      body: DeskBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(InkSpacing.s16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(InkSpacing.s24),
                decoration: BoxDecoration(
                  color: ink.paper,
                  borderRadius: BorderRadius.circular(InkRadii.dialog),
                  border: Border.all(color: ink.glassStroke),
                  boxShadow: ink.paperShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(LucideIcons.mailCheck, size: 40, color: ink.accent),
                    const SizedBox(height: InkSpacing.s12),
                    Semantics(
                      header: true,
                      child: Text(
                        'Verify your email',
                        textAlign: TextAlign.center,
                        style: InkType.title(ink.ink),
                      ),
                    ),
                    const SizedBox(height: InkSpacing.s8),
                    Text(
                      'We sent a link to ${widget.email}. Open it, then select the button below.',
                      textAlign: TextAlign.center,
                      style: InkType.body(ink.inkSecondary),
                    ),
                    const SizedBox(height: InkSpacing.s24),
                    InkButton.hero(
                      label: "I've verified",
                      isLoading: _busy,
                      onPressed: _busy ? null : _check,
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    InkButton(
                      label: 'Resend email',
                      variant: InkButtonVariant.secondary,
                      onPressed: _busy ? null : _resend,
                    ),
                    TextButton(
                      onPressed: () => context.read<WebAuthCubit>().signOut(),
                      child: Text(
                        'Use a different account',
                        style: InkType.bodyStrong(ink.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
