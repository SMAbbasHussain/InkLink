import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/helpers.dart'; // FIX: Import validation helpers
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/auth_hero.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import './register_screen.dart';
import './widgets/auth_text_field.dart';
import './widgets/social_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetTop = screenHeight * 0.39;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // AppView handles the authenticated → MainWrapper transition declaratively
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
          } else if (state is PasswordResetSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.check, size: 16, color: tokens.success),
                    const SizedBox(width: InkSpacing.s8),
                    Flexible(
                      child: Text(
                        "Password reset link sent to ${state.email}. Check your inbox!",
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return DeskBackground(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: sheetTop,
                    child: const ExcludeSemantics(child: AuthHero()),
                  ),
                  Positioned(
                    top: sheetTop,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _AuthSheet(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          InkSpacing.s24,
                          InkSpacing.s32,
                          InkSpacing.s24,
                          InkSpacing.s24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Welcome Back!", style: InkType.display(tokens.ink)),
                            const SizedBox(height: InkSpacing.s8),
                            Text(
                              "Sign in to start collaborating",
                              style: InkType.body(tokens.inkSecondary),
                            ),
                            const SizedBox(height: InkSpacing.s24),
                            AuthTextField(
                              controller: _emailController,
                              hintText: "Email Address",
                              icon: LucideIcons.mail,
                            ),
                            const SizedBox(height: InkSpacing.s12),
                            AuthTextField(
                              controller: _passwordController,
                              hintText: "Password",
                              icon: LucideIcons.lock,
                              isPassword: true,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showForgotPasswordDialog(context),
                                child: Text(
                                  "Forgot Password?",
                                  style: InkType.bodyStrong(tokens.accentText),
                                ),
                              ),
                            ),
                            const SizedBox(height: InkSpacing.s8),
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
                                    label: "Login",
                                    onPressed: () => _handleLogin(context),
                                  ),
                            const SizedBox(height: InkSpacing.s24),
                            _buildDivider(tokens),
                            const SizedBox(height: InkSpacing.s24),
                            SocialAuthButton(
                              text: "Continue with Google",
                              iconUrl:
                                  "https://img.icons8.com/color/48/000000/google-logo.png",
                              onTap: () => context.read<AuthBloc>().add(
                                GoogleSignInRequested(),
                              ),
                            ),
                            const SizedBox(height: InkSpacing.s32),
                            _buildFooter(context, tokens),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: sheetTop - 34,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildLogoTile(tokens)),
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

  void _handleLogin(BuildContext context) {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // FIX: Added comprehensive validation with helpful error messages
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address")),
      );
      return;
    }

    context.read<AuthBloc>().add(LoginRequested(email, password));
  }

  Widget _buildLogoTile(InkTokens tokens) {
    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: BorderRadius.circular(22),
        boxShadow: tokens.paperShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: tokens.accentGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'images/app_icon.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(InkTokens tokens) {
    return Row(
      children: [
        Expanded(child: Divider(color: tokens.glassStroke)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text("OR", style: InkType.caption(tokens.inkMuted)),
        ),
        Expanded(child: Divider(color: tokens.glassStroke)),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, InkTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account?", style: InkType.body(tokens.inkSecondary)),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: Text("Sign Up", style: InkType.bodyStrong(tokens.accentText)),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final tokens = context.ink;
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return InkDialog(
          title: "Reset Password",
          icon: LucideIcons.keyRound,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter your registered email address and we'll send you a link to reset your password.",
                style: InkType.body(tokens.inkSecondary),
              ),
              const SizedBox(height: InkSpacing.s16),
              InkTextField(
                controller: resetEmailController,
                hintText: "Email Address",
                keyboardType: TextInputType.emailAddress,
                leadingIcon: LucideIcons.mail,
              ),
            ],
          ),
          actions: [
            InkButton.secondary(
              label: "Cancel",
              onPressed: () => Navigator.pop(dialogContext),
            ),
            InkButton.primary(
              label: "Send Link",
              onPressed: () {
                final email = resetEmailController.text.trim();
                if (email.isEmpty || !isValidEmail(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Please enter a valid email address"),
                      backgroundColor: context.ink.danger,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                context.read<AuthBloc>().add(PasswordResetRequested(email));
              },
            ),
          ],
        );
      },
    );
  }
}

class _AuthSheet extends StatelessWidget {
  final Widget child;

  const _AuthSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: tokens.paperShadow,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: child,
      ),
    );
  }
}
