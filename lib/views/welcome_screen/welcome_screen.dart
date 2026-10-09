
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewModels/welcome_viewmodel.dart';
import '../login_screen/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color green = Color(0xFF075832);
  static const Color paleGreen = Color(0xFFEDF7EE);
  static const Color textColor = Color(0xFF29313D);
  static const Color background = Color(0xFFFFFEFA);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WelcomeViewModel>();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;

            final logoHeight = compact ? 115.0 : 145.0;
            final titleSize = compact ? 27.0 : 31.0;
            final featureCircleSize = compact ? 58.0 : 70.0;
            final featureFontSize = compact ? 10.0 : 11.0;

            return Stack(
              children: [
                // Subtle background decorations
                Positioned(
                  top: -110,
                  left: -115,
                  child: _backgroundCircle(250),
                ),
                Positioned(
                  bottom: -135,
                  right: -125,
                  child: _backgroundCircle(290),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  child: Column(
                    children: [
                      // Main logo
                      SizedBox(
                        height: logoHeight,
                        width: double.infinity,
                        child: Image.asset(
                          'lib/assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 40,
                                color: green,
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 30),

                      Text(
                        'Jan Kavach',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: green,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Connecting citizens with social security schemes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xFF626872),
                        ),
                      ),

                      SizedBox(height: compact ? 12 : 18),

                      // Language dropdown
                      Container(
                        height: compact ? 60 : 68,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFD6E5D8),
                            width: 1.3,
                          ),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.translate,
                              size: 28,
                              color: green,
                            ),
                            const SizedBox(width: 13),

                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Language',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),

                                  SizedBox(
                                    height: 28,
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: vm.selectedLanguage,
                                        isExpanded: true,
                                        isDense: true,
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: green,
                                          size: 24,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'en',
                                            child: Text(
                                              'English',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'hi',
                                            child: Text(
                                              'हिन्दी',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            vm.setLanguage(value);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: compact ? 1 : 18),

                      const Text(
                        'Support citizens to discover and access '
                            'eligible schemes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: textColor,
                        ),
                      ),

                      SizedBox(height: compact ? 15 : 22),

                      // Feature cards
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.manage_search,
                              label: 'Check scheme\neligibility',
                              circleSize: featureCircleSize,
                              fontSize: featureFontSize,
                            ),
                          ),
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.edit_note,
                              label: 'Apply and track\napplications',
                              circleSize: featureCircleSize,
                              fontSize: featureFontSize,
                            ),
                          ),
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.volunteer_activism_outlined,
                              label: 'Confirm benefits\nreceived',
                              circleSize: featureCircleSize,
                              fontSize: featureFontSize,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: compact ? 50 : 58,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Continue to Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward,
                                size: 21,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: compact ? 8 : 12),

                      const Text(
                        'Built for FXB India Suraksha field teams.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF737981),
                        ),
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            );
          },
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
        color: const Color(0xFFE5F1E6).withValues(alpha: 0.45),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double circleSize;
  final double fontSize;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.circleSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: const BoxDecoration(
              color: WelcomeScreen.paleGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: WelcomeScreen.green,
              size: circleSize * 0.50,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.35,
              color: WelcomeScreen.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
