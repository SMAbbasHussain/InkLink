import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/view/widgets/social_auth_button.dart';
import '../../ui/theme/ink_colors.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/auth_hero.dart';
import '../../ui/widgets/desk_background.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/sticky_note.dart';
import '../data/web_companion_repository.dart';
import '../widgets/web_widgets.dart';

/// Wide screens get a two-column layout from this width up.
const double _wideLayoutWidth = 900;

/// Email/password and Google sign-in for existing InkLink accounts, styled
/// like the mobile login ("Desk" design: dot grid, live-board hero, paper
/// sheet) without changing any mobile file.
class WebSignInScreen extends StatefulWidget {
  const WebSignInScreen({super.key});

  @override
  State<WebSignInScreen> createState() => _WebSignInScreenState();
}

class _WebSignInScreenState extends State<WebSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
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
      setState(
        () =>
            _error = 'Enter your email above, then select "Forgot password?".',
      );
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
    final wide = MediaQuery.sizeOf(context).width >= _wideLayoutWidth;
    return Scaffold(
      backgroundColor: ink.surfaceDesk,
      body: DeskBackground(
        child: SafeArea(
          child: wide ? _buildWide(context) : _buildNarrow(context),
        ),
      ),
    );
  }

  /// Desktop: what the web version is for on the left, the form on the right.
  Widget _buildWide(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(InkSpacing.s32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: _WebIntroPanel()),
              const SizedBox(width: InkSpacing.s32 * 2),
              SizedBox(width: 420, child: _buildFormCard(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// Phone-width browsers: the same hero-over-sheet layout as the mobile app.
  Widget _buildNarrow(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(
            height: 190,
            width: double.infinity,
            child: ExcludeSemantics(child: AuthHero()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InkSpacing.s16,
              0,
              InkSpacing.s16,
              InkSpacing.s24,
            ),
            child: _buildFormCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final ink = context.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s20,
      ),
      decoration: BoxDecoration(
        color: ink.paper,
        borderRadius: BorderRadius.circular(InkRadii.dialog),
        border: Border.all(color: ink.glassStroke),
        boxShadow: ink.paperShadow,
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: WebLogoTile()),
            const SizedBox(height: InkSpacing.s16),
            Semantics(
              header: true,
              child: Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: InkType.display(ink.ink),
              ),
            ),
            const SizedBox(height: InkSpacing.s8),
            Text(
              'Sign in to manage your boards, invites and friends.',
              textAlign: TextAlign.center,
              style: InkType.body(ink.inkSecondary),
            ),
            const SizedBox(height: InkSpacing.s24),
            InkTextField(
              controller: _email,
              hintText: 'Email address',
              leadingIcon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofocus: true,
              enabled: !_busy,
            ),
            const SizedBox(height: InkSpacing.s12),
            InkTextField(
              controller: _password,
              hintText: 'Password',
              leadingIcon: LucideIcons.lock,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              enabled: !_busy,
              onSubmitted: (_) => _signIn(),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                icon: Icon(
                  _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                  color: ink.inkMuted,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                child: Text(
                  'Forgot password?',
                  style: InkType.bodyStrong(ink.accentText),
                ),
              ),
            ),
            if (_error != null) ...[
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(InkSpacing.s12),
                  decoration: BoxDecoration(
                    color: ink.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circleAlert,
                        size: 18,
                        color: ink.danger,
                      ),
                      const SizedBox(width: InkSpacing.s8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: InkType.caption(ink.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: InkSpacing.s12),
            ],
            InkButton.hero(
              label: 'Sign in',
              isLoading: _busy,
              onPressed: _busy ? null : _signIn,
            ),
            const SizedBox(height: InkSpacing.s20),
            _OrDivider(color: ink.glassStroke, textColor: ink.inkMuted),
            const SizedBox(height: InkSpacing.s20),
            IgnorePointer(
              ignoring: _busy,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _busy ? 0.5 : 1,
                child: SocialAuthButton(
                  text: 'Continue with Google',
                  assetPath: 'images/google-logo.png',
                  onTap: () => _run(_repo.signInWithGoogle),
                ),
              ),
            ),
            const SizedBox(height: InkSpacing.s20),
            Text(
              'New to InkLink? Create your account in the mobile app, then sign in here.',
              textAlign: TextAlign.center,
              style: InkType.caption(ink.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Left column on desktop: the live-board hero and what the web can do.
class _WebIntroPanel extends StatelessWidget {
  const _WebIntroPanel();

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
          'Keep up with your boards and people from the browser. '
          'Drawing and live editing stay in the InkLink mobile app.',
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
              text: 'Search, filter and jump into any board on your phone.',
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

class _OrDivider extends StatelessWidget {
  final Color color;
  final Color textColor;
  const _OrDivider({required this.color, required this.textColor});

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

/// The app-icon tile used on the mobile login, rebuilt for the web.
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
      final verified = await context
          .read<WebCompanionRepository>()
          .reloadEmailVerified();
      if (!mounted) return;
      if (verified) {
        // Rebuild the gate with the refreshed user.
        context.read<WebAuthRefresh>().refresh();
      } else {
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
    try {
      await context.read<WebCompanionRepository>().resendVerificationEmail();
      if (mounted) {
        showWebMessage(context, 'Verification email sent to ${widget.email}.');
      }
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
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
                      onPressed: () =>
                          context.read<WebCompanionRepository>().signOut(),
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

/// Lets the email-verification screen ask the auth gate to rebuild after
/// `user.reload()` (Firebase does not emit an auth event for that).
class WebAuthRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
