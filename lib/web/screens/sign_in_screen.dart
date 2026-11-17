import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_logo.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_companion_repository.dart';
import '../widgets/web_widgets.dart';

/// Email/password and Google sign-in for existing InkLink accounts.
class WebSignInScreen extends StatefulWidget {
  const WebSignInScreen({super.key});

  @override
  State<WebSignInScreen> createState() => _WebSignInScreenState();
}

class _WebSignInScreenState extends State<WebSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  WebCompanionRepository get _repo => context.read<WebCompanionRepository>();

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = webErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    await _run(() => _repo.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email above, then tap "Forgot password?".');
      return;
    }
    await _run(() async {
      await _repo.sendPasswordReset(_email.text);
      if (mounted) showWebMessage(context, 'Password reset email sent.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Scaffold(
      backgroundColor: ink.surfaceDesk,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(InkSpacing.s16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: PaperCard(
              padding: const EdgeInsets.all(InkSpacing.s24),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: InkLogo(size: 44)),
                    const SizedBox(height: InkSpacing.s16),
                    Text('InkLink on the web',
                        textAlign: TextAlign.center, style: InkType.title(ink.ink)),
                    const SizedBox(height: InkSpacing.s4),
                    Text(
                      'Sign in to manage your boards, invites and friends.',
                      textAlign: TextAlign.center,
                      style: InkType.body(ink.inkSecondary),
                    ),
                    const SizedBox(height: InkSpacing.s24),
                    InkTextField(
                      controller: _email,
                      hintText: 'Email',
                      leadingIcon: LucideIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_busy,
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    InkTextField(
                      controller: _password,
                      hintText: 'Password',
                      leadingIcon: LucideIcons.lock,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      enabled: !_busy,
                      onSubmitted: (_) => _signIn(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: Text('Forgot password?', style: InkType.caption(ink.accentText)),
                      ),
                    ),
                    if (_error != null) ...[
                      Text(_error!, style: InkType.caption(ink.danger)),
                      const SizedBox(height: InkSpacing.s12),
                    ],
                    InkButton(label: 'Sign in', isLoading: _busy, onPressed: _busy ? null : _signIn),
                    const SizedBox(height: InkSpacing.s12),
                    InkButton(
                      label: 'Continue with Google',
                      variant: InkButtonVariant.secondary,
                      icon: Icon(LucideIcons.logIn, size: 18, color: ink.ink),
                      onPressed: _busy ? null : () => _run(_repo.signInWithGoogle),
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    Text(
                      'New to InkLink? Create your account in the mobile app, then sign in here.',
                      textAlign: TextAlign.center,
                      style: InkType.caption(ink.inkMuted),
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
      final verified = await context.read<WebCompanionRepository>().reloadEmailVerified();
      if (!mounted) return;
      if (verified) {
        // Rebuild the gate with the refreshed user.
        context.read<WebAuthRefresh>().refresh();
      } else {
        showWebMessage(context, 'Not verified yet. Check your inbox and spam folder.');
      }
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<WebCompanionRepository>().resendVerificationEmail();
      if (mounted) showWebMessage(context, 'Verification email sent to ${widget.email}.');
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Scaffold(
      backgroundColor: ink.surfaceDesk,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.s16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: PaperCard(
              padding: const EdgeInsets.all(InkSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(LucideIcons.mailCheck, size: 40, color: ink.accent),
                  const SizedBox(height: InkSpacing.s12),
                  Text('Verify your email',
                      textAlign: TextAlign.center, style: InkType.title(ink.ink)),
                  const SizedBox(height: InkSpacing.s8),
                  Text(
                    'We sent a link to ${widget.email}. Open it, then tap the button below.',
                    textAlign: TextAlign.center,
                    style: InkType.body(ink.inkSecondary),
                  ),
                  const SizedBox(height: InkSpacing.s24),
                  InkButton(label: "I've verified", isLoading: _busy, onPressed: _busy ? null : _check),
                  const SizedBox(height: InkSpacing.s12),
                  InkButton(
                    label: 'Resend email',
                    variant: InkButtonVariant.secondary,
                    onPressed: _busy ? null : _resend,
                  ),
                  TextButton(
                    onPressed: () => context.read<WebCompanionRepository>().signOut(),
                    child: Text('Use a different account', style: InkType.caption(ink.inkMuted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the email-verification screen ask the auth gate to rebuild after
/// `user.reload()` (Firebase does not emit an auth event for that).
class WebAuthRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
