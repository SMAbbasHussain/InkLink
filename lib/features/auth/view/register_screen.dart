import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../navigation/view/main_wrapper.dart';
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
  final TextEditingController _confirmPasswordController = TextEditingController();

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
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      // 2. Wrap with BlocListener for Navigation/Errors
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainWrapper()),
              (route) => false,
            );
          }
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            bool isLoading = state is AuthLoading;

            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Create Account",
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        Text("Start your collaborative journey today",
                            style: TextStyle(color: Colors.grey.shade500)),
                        
                        const SizedBox(height: 40),
                        
                        // 3. Input Fields linked to controllers
                        AuthTextField(
                          controller: _nameController,
                          hintText: "Full Name", 
                          icon: Icons.person_outline
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _emailController,
                          hintText: "Email Address", 
                          icon: Icons.email_outlined
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          hintText: "Password", 
                          icon: Icons.lock_outline, 
                          isPassword: true
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _confirmPasswordController,
                          hintText: "Confirm Password", 
                          icon: Icons.lock_reset, 
                          isPassword: true
                        ),
                        
                        const SizedBox(height: 40),

                        // 4. Functional Sign Up Button
                        _buildSignUpButton(context, isLoading),
                        
                        const SizedBox(height: 30),
                        const Center(
                          child: Text(
                            "By signing up, you agree to our Terms & Conditions",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        _buildFooter(context),
                      ],
                    ),
                  ),
                ),
                // Full screen loader
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.2),
                    child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSignUpButton(BuildContext context, bool isLoading) {
    return InkWell(
      onTap: isLoading ? null : _handleSignUp,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5F6D).withOpacity(0.3), 
              blurRadius: 10, 
              offset: const Offset(0, 5)
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "Sign Up",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  void _handleSignUp() {
    // Basic Validation logic
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      return;
    }

    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    // Trigger BLoC
    context.read<AuthBloc>().add(
      RegisterRequested(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Login", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}