import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const String demoPartnerPhone = '+91 98765 43210';
  static const String demoPartnerDialNumber = '+919876543210';

  static const Color green = Color(0xFF08683C);
  static const Color brightGreen = Color(0xFF0D874E);
  static const Color darkGreen = Color(0xFF06452D);

  Future<void> _callSupport(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: demoPartnerDialNumber);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('support.dialer_error'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('support.dialer_error'))),
        );
      }
    }
  }

  Future<void> _copyNumber(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: demoPartnerPhone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('support.copied_msg')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F7F5),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _buildHeaderBanner(context),
          const SizedBox(height: 14),
          _buildPartnerContactCard(context),
          const SizedBox(height: 14),
          _buildHelpTopicsCard(context),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD9EDFF),
            Color(0xFFF3F9FF),
            Color(0xFFE3F2FF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF9ACBFF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B62D6).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF339DFF), Color(0xFF0B62D6)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B62D6).withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('support.title'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F2D54),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr('support.subtitle'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: Color(0xFF334E6E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerContactCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD6FCE5),
            Color(0xFFF4FFF9),
            Color(0xFFC4FBD9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6CE29D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B8A54).withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 26,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.72),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF17A864), green],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: green.withValues(alpha: 0.28),
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('support.partner_title'),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: darkGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('support.partner_org'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3E5E4F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF6CE29D),
                            width: 0.9,
                          ),
                        ),
                        child: Text(
                          context.tr('support.demo_badge'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B8A54),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFB5ECCD),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('support.mobile_label'),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5A6D63),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                demoPartnerPhone,
                                style: TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: darkGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copyNumber(context),
                          tooltip: context.tr('support.copy_number'),
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: green,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF0B8A54),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.tr('support.working_hours'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF285741),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [brightGreen, green, darkGreen],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: green.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _callSupport(context),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.call_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    context.tr('support.call_now'),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _copyNumber(context),
                            icon: const Icon(
                              Icons.content_copy_rounded,
                              size: 17,
                              color: green,
                            ),
                            label: Text(
                              context.tr('support.copy_number'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.92),
                              side: const BorderSide(
                                color: Color(0xFF5DC88E),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpTopicsCard(BuildContext context) {
    final topics = [
      context.tr('support.topic_account'),
      context.tr('support.topic_sync'),
      context.tr('support.topic_schemes'),
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E6DC), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('support.help_topics_title'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...topics.map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Color(0xFF17A864),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      topic,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF45574E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
