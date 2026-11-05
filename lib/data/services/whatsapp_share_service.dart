import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/eligible_scheme_model.dart';

class WhatsAppShareService {
  static const Color green = Color(0xFF087443);
  static const Color whatsAppGreen = Color(0xFF25D366);

  /// Formats all essential scheme details into a clean, WhatsApp-styled message.
  static String formatSchemeMessage({
    required EligibleSchemeModel scheme,
    String? beneficiaryName,
    String? beneficiaryCode,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🏛️ *Jan Kavach - Welfare Scheme Information*');
    buffer.writeln();

    if (beneficiaryName != null && beneficiaryName.trim().isNotEmpty) {
      final codeSuffix = (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty)
          ? ' ($beneficiaryCode)'
          : '';
      buffer.writeln('Namaste, here are the welfare scheme details matched for *${beneficiaryName.trim()}*$codeSuffix:');
      buffer.writeln();
    }

    buffer.writeln('📌 *Scheme Name:* ${scheme.schemeName.trim()}');
    if (scheme.schemeCode.trim().isNotEmpty) {
      buffer.writeln('🔢 *Scheme Code:* ${scheme.schemeCode.trim()}');
    }
    if (scheme.themeName != null && scheme.themeName!.trim().isNotEmpty) {
      buffer.writeln('🏢 *Department / Category:* ${scheme.themeName!.trim()}');
    }
    if (scheme.schemeLevel != null && scheme.schemeLevel!.trim().isNotEmpty) {
      buffer.writeln('📍 *Level:* ${scheme.schemeLevel!.trim()}');
    }
    if (scheme.eligibilityStatus.trim().isNotEmpty) {
      buffer.writeln('🏷️ *Eligibility Status:* ${scheme.eligibilityStatus.trim()} (${scheme.matchPercent.toStringAsFixed(0)}% Match)');
    }
    buffer.writeln();

    // Benefits
    final benefitDesc = scheme.benefitDescription;
    final benefitAmount = scheme.benefit['amount_text']?.toString() ??
        scheme.benefit['amount']?.toString();
    if (benefitDesc != null && benefitDesc.trim().isNotEmpty) {
      buffer.writeln('💰 *Benefits:*');
      buffer.writeln(benefitDesc.trim());
      buffer.writeln();
    } else if (benefitAmount != null && benefitAmount.trim().isNotEmpty) {
      buffer.writeln('💰 *Benefit Amount:* ₹${benefitAmount.trim()}');
      buffer.writeln();
    }

    // Application details
    if (scheme.applicationMode != null && scheme.applicationMode!.trim().isNotEmpty) {
      buffer.writeln('📝 *Application Mode:* ${scheme.applicationMode!.trim()}');
    }
    if (scheme.applicationProcess != null && scheme.applicationProcess!.trim().isNotEmpty) {
      buffer.writeln('📋 *How to Apply / Process:*');
      buffer.writeln(scheme.applicationProcess!.trim());
      buffer.writeln();
    }

    // Documents
    if (scheme.missingDocuments.isNotEmpty) {
      buffer.writeln('📄 *Required Documents Checklist:*');
      for (final doc in scheme.missingDocuments) {
        buffer.writeln('• $doc');
      }
      buffer.writeln();
    }

    // Official links & helplines
    if (scheme.isOnline && scheme.applicationUrl != null && scheme.applicationUrl!.trim().isNotEmpty) {
      buffer.writeln('📝 *Application Form URL:* ${scheme.applicationUrl!.trim()}');
      buffer.writeln();
    }

    final url = scheme.officialWebsiteUrl ?? scheme.sourceUrl ?? scheme.portalUrl ?? scheme.actionUrl;
    if (url != null && url.trim().isNotEmpty && url.trim() != scheme.applicationUrl?.trim()) {
      buffer.writeln('🌐 *Official Portal / Website:* ${url.trim()}');
      buffer.writeln();
    } else if (url != null && url.trim().isNotEmpty && !scheme.isOnline) {
      buffer.writeln('🌐 *Official Portal / Website:* ${url.trim()}');
      buffer.writeln();
    }

    if (scheme.helplineNumber != null && scheme.helplineNumber!.trim().isNotEmpty) {
      buffer.writeln('📞 *Helpline Number:* ${scheme.helplineNumber!.trim()}');
      buffer.writeln();
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('_Shared via Jan Kavach Mobile Application_');
    return buffer.toString();
  }

  /// Cleans and formats phone numbers to standard country code format (e.g. 91XXXXXXXXXX).
  static String? cleanPhoneNumber(String? rawPhone) {
    if (rawPhone == null) return null;
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '91$digits';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      return digits;
    } else if (digits.length > 10) {
      return digits;
    }
    return null;
  }

  /// Launches WhatsApp with the formatted scheme message.
  /// Tries native app first, then universal links and web fallback.
  static Future<bool> launchWhatsApp({
    required String message,
    String? phone,
  }) async {
    final encodedMessage = Uri.encodeComponent(message);
    final cleanPhone = cleanPhoneNumber(phone);

    final List<Uri> urisToTry = [];

    if (cleanPhone != null && cleanPhone.isNotEmpty) {
      // Direct chat with beneficiary
      urisToTry.add(Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage'));
      urisToTry.add(Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage'));
      urisToTry.add(Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMessage'));
    }

    // General WhatsApp share to contact picker / groups
    urisToTry.add(Uri.parse('whatsapp://send?text=$encodedMessage'));
    urisToTry.add(Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage'));
    urisToTry.add(Uri.parse('https://wa.me/?text=$encodedMessage'));

    for (final uri in urisToTry) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (e) {
        debugPrint('Failed to launch WhatsApp URI $uri: $e');
      }
    }

    return false;
  }

  /// Interactive share method that shows destination options if beneficiary phone is available.
  static Future<void> shareScheme({
    required BuildContext context,
    required EligibleSchemeModel scheme,
    String? beneficiaryName,
    String? beneficiaryCode,
    String? beneficiaryMobile,
  }) async {
    final message = formatSchemeMessage(
      scheme: scheme,
      beneficiaryName: beneficiaryName,
      beneficiaryCode: beneficiaryCode,
    );

    final cleanPhone = cleanPhoneNumber(beneficiaryMobile);

    if (cleanPhone != null && cleanPhone.isNotEmpty) {
      // Show bottom sheet to let user choose between sending directly to beneficiary or selecting another contact
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final displayDigits = cleanPhone.length > 10
              ? cleanPhone.substring(cleanPhone.length - 10)
              : cleanPhone;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.share_rounded,
                      color: whatsAppGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Share "${scheme.schemeName}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16231C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F8EE),
                    child: Icon(Icons.person_pin_rounded, color: whatsAppGreen),
                  ),
                  title: Text(
                    beneficiaryName != null && beneficiaryName.trim().isNotEmpty
                        ? 'Send to $beneficiaryName'
                        : 'Send to Beneficiary',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text('+91 $displayDigits (Registered Number)'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _executeLaunch(context, message, cleanPhone);
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF0F3F1),
                    child: Icon(Icons.group_outlined, color: Color(0xFF3B4A41)),
                  ),
                  title: const Text(
                    'Choose Another Contact or Group',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text('Opens WhatsApp contact picker'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _executeLaunch(context, message, null);
                  },
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Direct launch to WhatsApp contact picker
      await _executeLaunch(context, message, null);
    }
  }

  static Future<void> _executeLaunch(
    BuildContext context,
    String message,
    String? phone,
  ) async {
    final success = await launchWhatsApp(
      message: message,
      phone: phone,
    );

    if (!success && context.mounted) {
      // Copy to clipboard fallback so the message is never lost
      await Clipboard.setData(ClipboardData(text: message));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open WhatsApp automatically. Scheme details copied to clipboard!',
          ),
          backgroundColor: Color(0xFF087443),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}
