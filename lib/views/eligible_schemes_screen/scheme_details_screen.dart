
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/eligible_scheme_model.dart';
import '../../data/services/whatsapp_share_service.dart';

class SchemeDetailsScreen extends StatelessWidget {
  final EligibleSchemeModel scheme;
  final String? beneficiaryName;
  final String? beneficiaryCode;
  final String? beneficiaryMobile;

  const SchemeDetailsScreen({
    super.key,
    required this.scheme,
    this.beneficiaryName,
    this.beneficiaryCode,
    this.beneficiaryMobile,
  });

  static const Color green = Color(0xFF087443);
  static const Color darkGreen = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  String _text(dynamic value, {String fallback = 'Not provided'}) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final mode = scheme.applicationMode ?? '';
    final process = scheme.applicationProcess;
    final benefit = scheme.benefit;
    final benefitDescription = scheme.benefitDescription;
    final benefitAmount = _text(benefit['amount_text'],
        fallback: _text(benefit['amount'], fallback: ''));
    final actionUrl = scheme.actionUrl;
    final actionLabel = scheme.actionLabel;
    final isEligible =
        scheme.eligibilityStatus.toLowerCase() == 'eligible';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Scheme Details'),
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Share on WhatsApp',
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              WhatsAppShareService.shareScheme(
                context: context,
                scheme: scheme,
                beneficiaryName: beneficiaryName,
                beneficiaryCode: beneficiaryCode,
                beneficiaryMobile: beneficiaryMobile,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scheme header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1E8E4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFFE5F5EA),
                  child: Icon(
                    Icons.account_balance_outlined,
                    color: green,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  scheme.schemeName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      scheme.eligibilityStatus,
                      isEligible ? green : Colors.orange.shade800,
                    ),
                    _chip('${scheme.matchPercent}% match', Colors.blue),
                    if (scheme.schemeLevel != null)
                      _chip(scheme.schemeLevel!, darkGreen),
                  ],
                ),
                if (scheme.themeName != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Category: ${scheme.themeName}',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ],
                if (scheme.schemeCode.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Scheme code: ${scheme.schemeCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (scheme.reasonText != null) ...[
            _sectionTitle('Why this scheme matched', Icons.fact_check_outlined),
            _card(
              child: Text(
                scheme.reasonText!,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ],

          // Benefit details
          _sectionTitle('Benefits', Icons.card_giftcard_outlined),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scheme.benefitType != null) ...[
                  const Text(
                    'Benefit type',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(scheme.benefitType!),
                  const SizedBox(height: 14),
                ],
                if (benefitAmount.isNotEmpty) ...[
                  const Text(
                    'Benefit amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(benefitAmount),
                  const SizedBox(height: 14),
                ],
                Text(
                  benefitDescription ?? 'Benefit details not provided.',
                  style: const TextStyle(height: 1.5),
                ),
                if (benefit['mode'] != null ||
                    benefit['frequency'] != null) ...[
                  const SizedBox(height: 12),
                  if (benefit['mode'] != null)
                    Text('Benefit mode: ${benefit['mode']}'),
                  if (benefit['frequency'] != null)
                    Text('Frequency: ${benefit['frequency']}'),
                ],
              ],
            ),
          ),

          // Documents
          _sectionTitle(
            'Documents to check',
            Icons.description_outlined,
          ),
          _card(
            child: scheme.missingDocuments.isEmpty
                ? const Text('No missing documents were reported.')
                : Column(
              children: scheme.missingDocuments.map((document) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: green,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(document)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Application instructions
          _sectionTitle(
            'How to apply',
            Icons.assignment_outlined,
          ),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Application mode: ${_text(mode, fallback: 'Not specified')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  process == null || process.trim().isEmpty
                      ? 'Application instructions are not available.'
                      : process,
                  style: const TextStyle(height: 1.6),
                ),
              ],
            ),
          ),

          // Helpline
          if (scheme.helplineNumber != null) ...[
            _sectionTitle('Helpline', Icons.support_agent_outlined),
            _card(
              child: Row(
                children: [
                  const Icon(Icons.phone_in_talk_outlined, color: green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scheme.helplineNumber!,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Website / application action
          if (actionUrl != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openWebsite(context, actionUrl),
                icon: const Icon(Icons.open_in_new),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will be redirected to an external website. '
                  'Check its details before submitting any information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 11,
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                WhatsAppShareService.shareScheme(
                  context: context,
                  scheme: scheme,
                  beneficiaryName: beneficiaryName,
                  beneficiaryCode: beneficiaryCode,
                  beneficiaryMobile: beneficiaryMobile,
                );
              },
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              label: const Text(
                'Share Scheme on WhatsApp',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: green, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE1E8E4)),
      ),
      child: child,
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openWebsite(
      BuildContext context,
      String url,
      ) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The website URL is invalid.')),
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the website.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the website.')),
        );
      }
    }
  }
}
