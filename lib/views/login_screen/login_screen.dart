
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewModels/login_viewmodel.dart';
import '../dashboard_screen/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  bool _rememberMe = true;
  bool _obscurePassword = true;

  static const Color green = Color(0xFF08683C);
  static const Color darkGreen = Color(0xFF064B32);
  static const Color background = Color(0xFFF4F9F3);
  static const Color fieldColor = Color(0xFFF1F6F3);
  static const Color textGrey = Color(0xFF818B98);

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your username and password.'),
        ),
      );
      return;
    }

    final vm = context.read<LoginViewModel>();

    try {
      final success = await vm.login(username, password);

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const DashboardScreen(),
          ),
              (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage ?? 'Login failed.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to sign in: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Soft background decoration
                Positioned(
                  top: -100,
                  left: -110,
                  child: _backgroundCircle(250),
                ),
                Positioned(
                  bottom: -130,
                  right: -100,
                  child: _backgroundCircle(300),
                ),

                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Jan Kavach logo
                        SizedBox(
                          height: 112,
                          width: double.infinity,
                          child: Image.asset(
                            'lib/assets/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.eco,
                                color: green,
                                size: 65,
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 2),

                        const Text(
                          'Jan Kavach',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: darkGreen,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'Connecting citizens with\n'
                              'social security schemes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: textGrey,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Sign-in card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            22,
                            24,
                            22,
                            22,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: darkGreen.withValues(alpha: 0.035),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: darkGreen,
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'Enter your credentials to continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textGrey,
                                ),
                              ),

                              const SizedBox(height: 25),

                              // Username
                              _buildInputField(
                                controller: _usernameController,
                                hint: 'Username',
                                icon: Icons.person_outline,
                                textInputAction: TextInputAction.next,
                              ),

                              const SizedBox(height: 14),

                              // Password
                              _buildInputField(
                                controller: _passwordController,
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!vm.isLoading) {
                                    _login();
                                  }
                                },
                                suffix: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword =
                                      !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF424B49),
                                    size: 23,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Remember me - no forgot password
                              Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    height: 32,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: green,
                                      side: const BorderSide(
                                        color: green,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(5),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  const Expanded(
                                    child: Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF414B50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Login button
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed:
                                  vm.isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: green,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                    green.withValues(alpha: 0.65),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(17),
                                    ),
                                  ),
                                  child: vm.isLoading
                                      ? const SizedBox(
                                    height: 23,
                                    width: 23,
                                    child:
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                      : const Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 18),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 28,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          'Built for FXB India Suraksha field teams.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: textGrey,
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputAction textInputAction = TextInputAction.next,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      height: 64,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF29313D),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: textGrey,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            icon,
            size: 27,
            color: const Color(0xFF414B49),
          ),
          suffixIcon: suffix,
          filled: true,
          fillColor: fieldColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(
              color: Color(0xFFE1EAE6),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(
              color: green,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _backgroundCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE2F0E4).withValues(alpha: 0.4),
      ),
    );
  }
}
