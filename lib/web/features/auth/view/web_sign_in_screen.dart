import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../features/auth/view/widgets/social_auth_button.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/auth_hero.dart';
import '../../../../ui/widgets/desk_background.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_auth_cubit.dart';
import 'web_auth_branding_panel.dart';

/// Wide screens use a two-column layout from this width up.
const double _wideLayoutWidth = 900;

/// Form modes for the web auth card: signing in or creating an account.
enum WebSignInMode { signIn, signUp }

/// Email/password sign-in and sign-up, plus Google sign-in, styled with Desk
/// tokens and delegating all auth calls to [WebAuthCubit].
class WebSignInScreen extends StatefulWidget {
  /// The board a link pointed at. When set, the form notifies the user that
  /// the board opens immediately after sign-in.
  final String? targetBoardId;

  const WebSignInScreen({super.key, this.targetBoardId});

  @override
  State<WebSignInScreen> createState() => _WebSignInScreenState();
}

class _WebSignInScreenState extends State<WebSignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  WebSignInMode _mode = WebSignInMode.signIn;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _creating => _mode == WebSignInMode.signUp;

  WebAuthCubit get _auth => context.read<WebAuthCubit>();

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
    await _run(() => _auth.signInWithEmail(_email.text, _password.text));
  }

  Future<void> _signUp() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Use at least 6 characters for your password.');
      return;
    }
    await _run(
      () => _auth.signUpWithEmail(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      ),
    );
  }

  void _switchMode() {
    if (_busy) return;
    setState(() {
      _mode = _creating ? WebSignInMode.signIn : WebSignInMode.signUp;
      _error = null;
    });
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
      await _auth.sendPasswordReset(_email.text);
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

  Widget _buildWide(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(InkSpacing.s32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: WebAuthBrandingPanel()),
              const SizedBox(width: InkSpacing.s32 * 2),
              SizedBox(width: 420, child: _buildFormCard(context)),
            ],
          ),
        ),
      ),
    );
  }

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
            if (widget.targetBoardId != null) ...[
              const WebTargetBoardBanner(),
              const SizedBox(height: InkSpacing.s16),
            ],
            Semantics(
              header: true,
              child: Text(
                _creating ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: InkType.display(ink.ink),
              ),
            ),
            const SizedBox(height: InkSpacing.s8),
            Text(
              _creating
                  ? 'Free, in the browser. No phone needed.'
                  : 'Sign in to manage your boards, invites and friends.',
              textAlign: TextAlign.center,
              style: InkType.body(ink.inkSecondary),
            ),
            const SizedBox(height: InkSpacing.s24),
            if (_creating) ...[
              InkTextField(
                controller: _name,
                hintText: 'Your name',
                leadingIcon: LucideIcons.user,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofocus: true,
                enabled: !_busy,
              ),
              const SizedBox(height: InkSpacing.s12),
            ],
            InkTextField(
              controller: _email,
              hintText: 'Email address',
              leadingIcon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofocus: !_creating,
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
              onSubmitted: (_) => _creating ? _signUp() : _signIn(),
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
            if (!_creating)
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
              label: _creating ? 'Create account' : 'Sign in',
              isLoading: _busy,
              onPressed: _busy ? null : (_creating ? _signUp : _signIn),
            ),
            if (!_creating) ...[
              const SizedBox(height: InkSpacing.s20),
              WebAuthOrDivider(color: ink.glassStroke, textColor: ink.inkMuted),
              const SizedBox(height: InkSpacing.s20),
              IgnorePointer(
                ignoring: _busy,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _busy ? 0.5 : 1,
                  child: SocialAuthButton(
                    text: 'Continue with Google',
                    assetPath: 'images/google-logo.png',
                    onTap: () => _run(_auth.signInWithGoogle),
                  ),
                ),
              ),
            ],
            const SizedBox(height: InkSpacing.s20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _creating ? 'Already have an account?' : 'New to InkLink?',
                    style: InkType.caption(ink.inkMuted),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _switchMode,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    _creating ? 'Sign in' : 'Create an account',
                    style: InkType.bodyStrong(ink.accentText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
