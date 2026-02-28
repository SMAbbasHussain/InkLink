import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../navigation/view/main_wrapper.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            // Navigate to Main App on Success
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainWrapper()),
            );
          }
          if (state is AuthError) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 80),

                        // 1. Glitter Logo Area
                        Center(child: _buildLogo()),

                        const SizedBox(height: 40),
                        Text(
                          "Welcome Back!",
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                        ),
                        Text(
                          "Sign in to start collaborating",
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // 2. Input Fields
                        AuthTextField(
                          controller: _emailController,
                          hintText: "Email Address",
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          hintText: "Password",
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text("Forgot Password?"),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 3. Glitter Login Button
                        _buildLoginButton(context, state),

                        const SizedBox(height: 30),

                        // 4. Divider
                        _buildDivider(),

                        const SizedBox(height: 30),

                        // 5. Social Login
                        SocialAuthButton(
                          text: "Continue with Google",
                          iconUrl:
                              "https://img.icons8.com/color/48/000000/google-logo.png",
                          onTap: () => context.read<AuthBloc>().add(
                            GoogleSignInRequested(),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // 6. Footer
                        _buildFooter(context),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                // Full screen loading overlay for a professional feel
                if (state is AuthLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A11CB).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.edit_note_rounded, size: 65, color: Colors.white),
    );
  }

  Widget _buildLoginButton(BuildContext context, AuthState state) {
    // 1. Check if the BLoC is currently in a loading state
    final bool isLoading = state is AuthLoading;

    return InkWell(
      // 2. Disable the tap if we are already loading to prevent double-requests
      onTap: isLoading
          ? null
          : () {
              // Validate basic inputs before sending to BLoC
              if (_emailController.text.trim().isEmpty ||
                  _passwordController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter email and password"),
                  ),
                );
                return;
              }

              // 3. Dispatch the event to our AuthBloc
              context.read<AuthBloc>().add(
                LoginRequested(
                  _emailController.text.trim(),
                  _passwordController.text.trim(),
                ),
              );
            },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          // 4. The "Glitter" Gradient
          gradient: LinearGradient(
            colors: isLoading
                ? [Colors.grey, Colors.grey.shade400] // Desaturate when loading
                : [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!isLoading)
              BoxShadow(
                color: const Color(0xFF6A11CB).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Center(
          // 5. Switch between Text and Progress Indicator
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  "Login",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("OR", style: TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?"),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text(
            "Sign Up",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
