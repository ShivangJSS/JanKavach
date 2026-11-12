import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../login_screen/login_screen.dart';
import '../widgets/language_selector_sheet.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color green = Color(0xFF075832);
  static const Color paleGreen = Color(0xFFEDF7EE);
  static const Color textColor = Color(0xFF29313D);
  static const Color background = Color(0xFFFFFEFA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;

            final logoHeight = compact ? 100.0 : 130.0;
            final titleSize = compact ? 26.0 : 30.0;
            final featureCircleSize = compact ? 56.0 : 68.0;
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
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      // Top row with Language Selector
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          LanguageSelectorButton(),
                        ],
                      ),

                      SizedBox(height: compact ? 10 : 20),

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

                      SizedBox(height: compact ? 12 : 18),

                      Text(
                        context.tr('common.app_name'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: green,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        context.tr('welcome.tagline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Color(0xFF626872),
                        ),
                      ),

                      SizedBox(height: compact ? 10 : 14),

                      Text(
                        context.tr('welcome.subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),

                      SizedBox(height: compact ? 14 : 22),

                      // Feature cards
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.manage_search,
                              label: context.tr('welcome.feature_check_eligibility'),
                              circleSize: featureCircleSize,
                              fontSize: featureFontSize,
                            ),
                          ),
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.edit_note,
                              label: context.tr('welcome.feature_apply_track'),
                              circleSize: featureCircleSize,
                              fontSize: featureFontSize,
                            ),
                          ),
                          Expanded(
                            child: _FeatureItem(
                              icon: Icons.volunteer_activism_outlined,
                              label: context.tr('welcome.feature_confirm_benefits'),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  context.tr('auth.sign_in'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
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
