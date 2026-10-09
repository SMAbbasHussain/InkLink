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
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import './widgets/auth_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 1. Define Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetTop = screenHeight * 0.25;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      // 2. Wrap with BlocListener for Navigation/Errors
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
                    child: _RegisterSheet(
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
                            Text("Create Account", style: InkType.display(tokens.ink)),
                            const SizedBox(height: InkSpacing.s8),
                            Text(
                              "Start your collaborative journey today",
                              style: InkType.body(tokens.inkSecondary),
                            ),
                            const SizedBox(height: InkSpacing.s24),
                            AuthTextField(
                              controller: _nameController,
                              hintText: "Full Name",
                              icon: LucideIcons.user,
                            ),
                            const SizedBox(height: InkSpacing.s12),
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
                            const SizedBox(height: InkSpacing.s12),
                            AuthTextField(
                              controller: _confirmPasswordController,
                              hintText: "Confirm Password",
                              icon: LucideIcons.lock,
                              isPassword: true,
                            ),
                            const SizedBox(height: InkSpacing.s24),
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
                                    label: "Sign Up",
                                    onPressed: _handleSignUp,
                                  ),
                            const SizedBox(height: InkSpacing.s20),
                            Center(
                              child: Text(
                                "By signing up, you agree to our Terms & Conditions",
                                textAlign: TextAlign.center,
                                style: InkType.caption(tokens.inkMuted),
                              ),
                            ),
                            const SizedBox(height: InkSpacing.s32),
                            _buildFooter(context, tokens),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.2),
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

  void _handleSignUp() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // FIX: Added comprehensive validation with helpful error messages
    // 1. Check if all fields are filled
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    // 2. Validate name length
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name must be at least 2 characters")),
      );
      return;
    }

    // 3. Validate email format
    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address")),
      );
      return;
    }

    // 4. Validate password strength
    if (!isValidPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    // 5. Validate password confirmation
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    // All validations passed - trigger registration
    context.read<AuthBloc>().add(RegisterRequested(name, email, password));
  }

  Widget _buildFooter(BuildContext context, InkTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account?", style: InkType.body(tokens.inkSecondary)),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Login", style: InkType.bodyStrong(tokens.accentText)),
        ),
      ],
    );
  }
}

class _RegisterSheet extends StatelessWidget {
  final Widget child;

  const _RegisterSheet({required this.child});

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
