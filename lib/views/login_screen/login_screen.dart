import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../data/providers/language_provider.dart';
import '../../viewModels/login_viewmodel.dart';
import '../../viewModels/welcome_viewmodel.dart';
import '../dashboard_screen/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _obscurePassword = true;

  static const Color green = Color(0xFF08683C);
  static const Color brightGreen = Color(0xFF0D874E);
  static const Color darkGreen = Color(0xFF064B32);
  static const Color fieldColor = Color(0xFFF3F8F5);
  static const Color textGrey = Color(0xFF6B7785);
  static const Color bankMaroon = Color(0xFF8C1D24);

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('auth.credentials_required')),
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
            content: Text(
              vm.errorMessage ?? context.tr('auth.login_failed'),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('auth.unable_to_sign_in', args: {'error': '$e'}),
          ),
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
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    final bottomInset = mediaQuery.padding.bottom;
    final keyboardOpen = mediaQuery.viewInsets.bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F9F5),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF6FBF7),
                Color(0xFFECF5EF),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: -90,
                left: -80,
                child: _ambientGlow(220, const Color(0xFFD5EFE0)),
              ),
              Positioned(
                bottom: -110,
                right: -90,
                child: _ambientGlow(240, const Color(0xFFD8EBFB)),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final viewportHeight = constraints.maxHeight;
                  final compact = viewportHeight < 680;
                  final backdropHeight = topInset + (compact ? 196.0 : 236.0);

                  return SingleChildScrollView(
                    physics: keyboardOpen
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: viewportHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: backdropHeight,
                                  child: _buildHeroBackdrop(),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: topInset + (compact ? 6 : 12),
                                    ),
                                    _buildTopBar(context),
                                    SizedBox(height: compact ? 6 : 12),
                                    _buildHeroBrand(context, compact: compact),
                                    SizedBox(height: compact ? 14 : 20),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                      ),
                                      child: _buildSignInCard(
                                        context,
                                        vm,
                                        compact: compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            SizedBox(height: compact ? 10 : 14),
                            _buildFooter(context),
                            SizedBox(
                              height:
                                  (bottomInset > 0 ? bottomInset : 6) +
                                  (compact ? 8 : 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBackdrop() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(32),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF043B27),
              darkGreen,
              green,
              brightGreen,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -45,
              right: -35,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -55,
              left: -40,
              child: Container(
                width: 165,
                height: 165,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF42E68F).withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildLanguagePill(context),
        ],
      ),
    );
  }

  Widget _buildLanguagePill(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final welcomeVm = context.watch<WelcomeViewModel>();
    final currentCode = languageProvider.currentLanguageCode;

    const shortLabels = <String, String>{
      'en': 'English',
      'hi': 'हिन्दी',
      'as': 'অসমীয়া',
    };

    const fullLabels = <String, String>{
      'en': 'English',
      'hi': 'हिन्दी (Hindi)',
      'as': 'অসমীয়া (Assamese)',
    };

    final codes = fullLabels.keys.toList();

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: fullLabels.containsKey(currentCode) ? currentCode : 'en',
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Colors.white,
          icon: const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: darkGreen,
              size: 17,
            ),
          ),
          selectedItemBuilder: (context) {
            return codes.map((code) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    size: 14,
                    color: green,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    shortLabels[code] ?? 'English',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: darkGreen,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: codes.map((code) {
            return DropdownMenuItem<String>(
              value: code,
              child: Text(
                fullLabels[code]!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      code == currentCode ? FontWeight.w700 : FontWeight.w500,
                  color: code == currentCode ? darkGreen : const Color(0xFF1F2933),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              languageProvider.setLanguage(value);
              welcomeVm.setLanguage(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeroBrand(BuildContext context, {required bool compact}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 76 : 84,
            height: compact ? 42 : 48,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset(
              'lib/assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.eco_rounded,
                  color: green,
                  size: 28,
                );
              },
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            context.tr('common.app_name'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 20 : 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.15,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.tr('auth.portal_tagline'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: Color(0xFFD6F2E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInCard(
    BuildContext context,
    LoginViewModel vm, {
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        compact ? 15 : 18,
        18,
        compact ? 16 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFDCEEE3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF14B866), green],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr('auth.sign_in'),
                  style: TextStyle(
                    fontSize: compact ? 19 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('auth.login_subtitle'),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: textGrey,
            ),
          ),
          SizedBox(height: compact ? 12 : 14),
          _buildInputField(
            controller: _usernameController,
            hint: context.tr('auth.mobile_number'),
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: compact ? 9 : 11),
          _buildInputField(
            controller: _passwordController,
            hint: context.tr('auth.password'),
            icon: Icons.lock_outline_rounded,
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
                  _obscurePassword = !_obscurePassword;
                });
              },
              splashRadius: 18,
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF53635C),
                size: 19,
              ),
            ),
          ),
          SizedBox(height: compact ? 7 : 8),
          InkWell(
            onTap: () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(
                        color: green,
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('auth.remember_me'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF42504A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 14),
          _buildSignInButton(context, vm, compact: compact),
        ],
      ),
    );
  }

  Widget _buildSignInButton(
    BuildContext context,
    LoginViewModel vm, {
    required bool compact,
  }) {
    final buttonHeight = compact ? 44.0 : 46.0;

    return Container(
      width: double.infinity,
      height: buttonHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: vm.isLoading
              ? [
                  green.withValues(alpha: 0.72),
                  darkGreen.withValues(alpha: 0.72),
                ]
              : const [
                  brightGreen,
                  green,
                  darkGreen,
                ],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: vm.isLoading
            ? null
            : [
                BoxShadow(
                  color: green.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: vm.isLoading ? null : _login,
          child: Center(
            child: vm.isLoading
                ? const SizedBox(
                    height: 19,
                    width: 19,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr('auth.login_button'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
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
      height: 45,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        textInputAction: textInputAction,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A2521),
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF7D8B97),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            size: 19,
            color: green,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 42,
          ),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          filled: true,
          fillColor: fieldColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: Color(0xFFD9EAE0),
              width: 1.1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(
              color: green,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 2.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFC2E4CF),
                green,
                Color(0xFFC2E4CF),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Powered by ',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5C6C65),
                ),
              ),
              TextSpan(
                text: 'Indev Consultancy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: bankMaroon,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          context.tr('auth.version_label'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7D8D85),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  static Widget _ambientGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.55),
      ),
    );
  }
}
