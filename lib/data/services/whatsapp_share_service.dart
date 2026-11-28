import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/localized_value_helper.dart';
import '../models/eligible_scheme_model.dart';

class WhatsAppShareService {
  static const Color green = Color(0xFF087443);
  static const Color whatsAppGreen = Color(0xFF25D366);

  static const Map<String, Map<String, String>> _templates = {
    'en': {
      'header': '🏛️ *Jan Kavach - Welfare Scheme Information*',
      'greeting':
          'Namaste, here are the welfare scheme details matched for *{name}*{code}:',
      'scheme_name': '📌 *Scheme Name:*',
      'scheme_code': '🔢 *Scheme Code:*',
      'department': '🏢 *Department / Category:*',
      'level': '📍 *Level:*',
      'level_national': 'National',
      'level_state': 'State',
      'eligibility_status': '🏷️ *Eligibility Status:*',
      'match_percent': '{percent}% Match',
      'benefits': '💰 *Benefits:*',
      'benefit_amount': '💰 *Benefit Amount:* ₹{amount}',
      'application_mode': '📝 *Application Mode:*',
      'mode_online': 'Online',
      'mode_offline': 'Offline',
      'mode_both': 'Online / Offline',
      'how_to_apply': '📋 *How to Apply / Process:*',
      'required_docs': '📄 *Required Documents Checklist:*',
      'application_url': '📝 *Application Form URL:*',
      'official_portal': '🌐 *Official Portal / Website:*',
      'helpline': '📞 *Helpline Number:*',
      'footer':
          '-----------------------------------\n_Shared via Jan Kavach Mobile Application_',
      'dialog_title': 'Share "{scheme}"',
      'send_to_beneficiary': 'Send to {name}',
      'send_to_beneficiary_default': 'Send to Beneficiary',
      'registered_number': '+91 {phone} (Registered Number)',
      'choose_contact': 'Choose Another Contact or Group',
      'opens_picker': 'Opens WhatsApp contact picker',
      'copied_fallback':
          'Unable to open WhatsApp automatically. Scheme details copied to clipboard!',
      'share_language_label': 'Language:',
    },
    'hi': {
      'header': '🏛️ *जन कवच - कल्याणकारी योजना जानकारी*',
      'greeting':
          'नमस्ते, *{name}*{code} के लिए पात्र सरकारी योजना का विवरण निम्नलिखित है:',
      'scheme_name': '📌 *योजना का नाम:*',
      'scheme_code': '🔢 *योजना कोड:*',
      'department': '🏢 *विभाग / श्रेणी:*',
      'level': '📍 *स्तर:*',
      'level_national': 'राष्ट्रीय',
      'level_state': 'राज्य',
      'eligibility_status': '🏷️ *पात्रता स्थिति:*',
      'match_percent': '{percent}% मेल',
      'benefits': '💰 *योजना के लाभ:*',
      'benefit_amount': '💰 *लाभ राशि:* ₹{amount}',
      'application_mode': '📝 *आवेदन का माध्यम:*',
      'mode_online': 'ऑनलाइन',
      'mode_offline': 'ऑफ़लाइन',
      'mode_both': 'ऑनलाइन / ऑफ़लाइन',
      'how_to_apply': '📋 *आवेदन कैसे करें / प्रक्रिया:*',
      'required_docs': '📄 *आवश्यक दस्तावेज़ सूची:*',
      'application_url': '📝 *ऑनलाइन आवेदन फॉर्म लिंक:*',
      'official_portal': '🌐 *आधिकारिक पोर्टल / वेबसाइट:*',
      'helpline': '📞 *हेल्पलाइन नंबर:*',
      'footer':
          '-----------------------------------\n_जन कवच मोबाइल ऐप द्वारा साझा किया गया_',
      'dialog_title': '"{scheme}" साझा करें',
      'send_to_beneficiary': '{name} को भेजें',
      'send_to_beneficiary_default': 'लाभार्थी को भेजें',
      'registered_number': '+91 {phone} (पंजीकृत नंबर)',
      'choose_contact': 'अन्य संपर्क या समूह चुनें',
      'opens_picker': 'व्हाट्सएप संपर्क चयनकर्ता खुलेगा',
      'copied_fallback':
          'व्हाट्सएप स्वचालित रूप से नहीं खुला। योजना का विवरण क्लिपबोर्ड पर कॉपी किया गया!',
      'share_language_label': 'भाषा:',
    },
    'as': {
      'header': '🏛️ *জন কৱচ - কল্যাণমূলক আঁচনিৰ তথ্য*',
      'greeting':
          'নমস্কাৰ, *{name}*{code}ৰ বাবে প্ৰযোজ্য চৰকাৰী আঁচনিৰ বিৱৰণ তলত দিয়া হ\'ল:',
      'scheme_name': '📌 *আঁচনিৰ নাম:*',
      'scheme_code': '🔢 *আঁচনিৰ ক\'ড:*',
      'department': '🏢 *বিভাগ / শ্ৰেণী:*',
      'level': '📍 *স্তৰ:*',
      'level_national': 'ৰাষ্ট্ৰীয়',
      'level_state': 'ৰাজ্যিক',
      'eligibility_status': '🏷️ *যোগ্যতাৰ স্থিতি:*',
      'match_percent': '{percent}% মিল',
      'benefits': '💰 *আঁচনিৰ সুবিধাসমূহ:*',
      'benefit_amount': '💰 *সুবিধাৰ ধনৰ পৰিমাণ:* ₹{amount}',
      'application_mode': '📝 *আবেদনৰ মাধ্যম:*',
      'mode_online': 'অনলাইন',
      'mode_offline': 'অফলাইন',
      'mode_both': 'অনলাইন / অফলাইন',
      'how_to_apply': '📋 *আবেদন প্ৰক্ৰিয়া:*',
      'required_docs': '📄 *প্ৰয়োজনীয় নথি-পত্ৰসমূহৰ তালিকা:*',
      'application_url': '📝 *অনলাইন আবেদন প্ৰ-পত্ৰৰ লিংক:*',
      'official_portal': '🌐 *চৰকাৰী পৰ্টেল / ৱেবছাইট:*',
      'helpline': '📞 *হেল্পলাইন নম্বৰ:*',
      'footer':
          '-----------------------------------\n_জন কৱচ মোবাইল এপৰ জৰিয়তে শ্বেয়াৰ কৰা হ\'ল_',
      'dialog_title': '"{scheme}" শ্বেয়াৰ কৰক',
      'send_to_beneficiary': '{name}লৈ প্ৰেৰণ কৰক',
      'send_to_beneficiary_default': 'হিতাধিকাৰীলৈ প্ৰেৰণ কৰক',
      'registered_number': '+91 {phone} (পঞ্জীভুক্ত নম্বৰ)',
      'choose_contact': 'অন্য যোগাযোগ বা গোট বাছক',
      'opens_picker': 'হোৱাটছএপ যোগাযোগ বাছনি খোলক',
      'copied_fallback':
          'হোৱাটছএপ স্বয়ংক্ৰিয়ভাৱে খোল খাব পৰা নগ\'ল। আঁচনিৰ বিৱৰণ ক্লিপবৰ্ডত কপি কৰা হ\'ল!',
      'share_language_label': 'ভাষা:',
    },
  };

  static String _tr(
    String key,
    String langCode, [
    Map<String, String>? args,
  ]) {
    final dict = _templates[langCode] ?? _templates['en']!;
    var str = dict[key] ?? _templates['en']?[key] ?? key;
    if (args != null && args.isNotEmpty) {
      args.forEach((placeholder, value) {
        str = str.replaceAll('{$placeholder}', value);
      });
    }
    return str;
  }

  static String _translateOption(
    String raw,
    String langCode, [
    BuildContext? context,
  ]) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;

    final lower = trimmed.toLowerCase();

    // Scheme Level
    if (lower == 'national') {
      return _tr('level_national', langCode);
    }
    if (lower == 'state') {
      return _tr('level_state', langCode);
    }

    // Application Mode
    if (lower == 'online') {
      return _tr('mode_online', langCode);
    }
    if (lower == 'offline') {
      return _tr('mode_offline', langCode);
    }
    if (lower == 'both') {
      return _tr('mode_both', langCode);
    }

    // Eligibility Status
    if (lower == 'eligible') {
      if (langCode == 'hi') return 'पात्र';
      if (langCode == 'as') return 'যোগ্য';
      return 'Eligible';
    }
    if (lower == 'potentially eligible') {
      if (langCode == 'hi') return 'संभावित पात्र';
      if (langCode == 'as') return 'সম্ভাব্য যোগ্য';
      return 'Potentially Eligible';
    }

    // Common standard documents
    if (lower.contains('aadhaar') || lower.contains('adhaar')) {
      if (langCode == 'hi') return 'आधार कार्ड (Aadhaar Card)';
      if (langCode == 'as') return 'আধাৰ কাৰ্ড (Aadhaar Card)';
      return 'Aadhaar Card';
    }
    if (lower.contains('passbook') || lower.contains('bank account')) {
      if (langCode == 'hi') return 'बैंक पासबुक / खाता विवरण';
      if (langCode == 'as') return 'বেংক পাছবুক / একাউণ্টৰ বিৱৰণ';
      return 'Bank Passbook';
    }
    if (lower.contains('ration')) {
      if (langCode == 'hi') return 'राशन कार्ड (Ration Card)';
      if (langCode == 'as') return 'ৰেচন কাৰ্ড (Ration Card)';
      return 'Ration Card';
    }
    if (lower.contains('voter')) {
      if (langCode == 'hi') return 'मतदाता पहचान पत्र (Voter ID)';
      if (langCode == 'as') return 'ভোটাৰ পৰিচয় পত্ৰ (Voter ID)';
      return 'Voter ID Card';
    }
    if (lower.contains('pan card') || lower == 'pan') {
      if (langCode == 'hi') return 'पैन कार्ड (PAN Card)';
      if (langCode == 'as') return 'পেন কাৰ্ড (PAN Card)';
      return 'PAN Card';
    }
    if (lower.contains('income')) {
      if (langCode == 'hi') return 'आय प्रमाण पत्र (Income Certificate)';
      if (langCode == 'as') return 'উপাৰ্জনৰ প্ৰমাণপত্ৰ (Income Certificate)';
      return 'Income Certificate';
    }
    if (lower.contains('caste')) {
      if (langCode == 'hi') return 'जाति प्रमाण पत्र (Caste Certificate)';
      if (langCode == 'as') return 'জাতিগত প্ৰমাণপত্ৰ (Caste Certificate)';
      return 'Caste Certificate';
    }
    if (lower.contains('birth')) {
      if (langCode == 'hi') return 'जन्म प्रमाण पत्र (Birth Certificate)';
      if (langCode == 'as') return 'জন্ম প্ৰমাণপত্ৰ (Birth Certificate)';
      return 'Birth Certificate';
    }
    if (lower.contains('disability')) {
      if (langCode == 'hi') return 'दिव्यांगता प्रमाण पत्र / UDID';
      if (langCode == 'as') return 'দিব্যাংগতা প্ৰমাণপত্ৰ / UDID';
      return 'Disability Certificate';
    }

    if (context != null) {
      return LocalizedValueHelper.translateOption(context, raw);
    }
    return raw;
  }

  /// Formats all essential scheme details into a clean, WhatsApp-styled message
  /// localized according to [languageCode] or the user's active UI [context].
  static String formatSchemeMessage({
    BuildContext? context,
    String? languageCode,
    required EligibleSchemeModel scheme,
    String? beneficiaryName,
    String? beneficiaryCode,
  }) {
    final langCode = languageCode ??
        (context != null
            ? (AppLocalizations.of(context)?.locale.languageCode ?? 'en')
            : 'en');

    final buffer = StringBuffer();
    buffer.writeln(_tr('header', langCode));
    buffer.writeln();

    if (beneficiaryName != null && beneficiaryName.trim().isNotEmpty) {
      final codeSuffix =
          (beneficiaryCode != null && beneficiaryCode.trim().isNotEmpty)
              ? ' ($beneficiaryCode)'
              : '';
      buffer.writeln(
        _tr('greeting', langCode, {
          'name': beneficiaryName.trim(),
          'code': codeSuffix,
        }),
      );
      buffer.writeln();
    }

    buffer.writeln(
      '${_tr('scheme_name', langCode)} ${scheme.schemeName.trim()}',
    );
    if (scheme.schemeCode.trim().isNotEmpty) {
      buffer.writeln(
        '${_tr('scheme_code', langCode)} ${scheme.schemeCode.trim()}',
      );
    }
    if (scheme.themeName != null && scheme.themeName!.trim().isNotEmpty) {
      buffer.writeln(
        '${_tr('department', langCode)} ${scheme.themeName!.trim()}',
      );
    }
    if (scheme.schemeLevel != null && scheme.schemeLevel!.trim().isNotEmpty) {
      final localizedLevel =
          _translateOption(scheme.schemeLevel!, langCode, context);
      buffer.writeln('${_tr('level', langCode)} $localizedLevel');
    }
    if (scheme.eligibilityStatus.trim().isNotEmpty) {
      final localizedStatus =
          _translateOption(scheme.eligibilityStatus, langCode, context);
      if (scheme.isEligible) {
        final matchStr = _tr('match_percent', langCode, {
          'percent': '100',
        });
        buffer.writeln(
          '${_tr('eligibility_status', langCode)} $localizedStatus ($matchStr)',
        );
      } else if (scheme.missingDocuments.isNotEmpty) {
        buffer.writeln(
          '${_tr('eligibility_status', langCode)} $localizedStatus (Missing: ${scheme.missingDocuments.join(', ')})',
        );
      } else {
        buffer.writeln(
          '${_tr('eligibility_status', langCode)} $localizedStatus',
        );
      }
    }
    buffer.writeln();

    // Benefits
    final benefitDesc = scheme.benefitDescription;
    final benefitAmount = scheme.benefit['amount_text']?.toString() ??
        scheme.benefit['amount']?.toString();
    if (benefitDesc != null && benefitDesc.trim().isNotEmpty) {
      buffer.writeln(_tr('benefits', langCode));
      buffer.writeln(benefitDesc.trim());
      buffer.writeln();
    } else if (benefitAmount != null && benefitAmount.trim().isNotEmpty) {
      buffer.writeln(
        _tr('benefit_amount', langCode, {'amount': benefitAmount.trim()}),
      );
      buffer.writeln();
    }

    // Application details
    if (scheme.applicationMode != null &&
        scheme.applicationMode!.trim().isNotEmpty) {
      final localizedMode =
          _translateOption(scheme.applicationMode!, langCode, context);
      buffer.writeln('${_tr('application_mode', langCode)} $localizedMode');
    }
    if (scheme.applicationProcess != null &&
        scheme.applicationProcess!.trim().isNotEmpty) {
      buffer.writeln(_tr('how_to_apply', langCode));
      buffer.writeln(scheme.applicationProcess!.trim());
      buffer.writeln();
    }

    // Documents
    if (scheme.missingDocuments.isNotEmpty) {
      buffer.writeln(_tr('required_docs', langCode));
      for (final doc in scheme.missingDocuments) {
        final localizedDoc = _translateOption(doc, langCode, context);
        buffer.writeln('• $localizedDoc');
      }
      buffer.writeln();
    }

    // Official links & helplines
    if (scheme.isOnline &&
        scheme.applicationUrl != null &&
        scheme.applicationUrl!.trim().isNotEmpty) {
      buffer.writeln(
        '${_tr('application_url', langCode)} ${scheme.applicationUrl!.trim()}',
      );
      buffer.writeln();
    }

    final url = scheme.officialWebsiteUrl ??
        scheme.sourceUrl ??
        scheme.portalUrl ??
        scheme.actionUrl;
    if (url != null &&
        url.trim().isNotEmpty &&
        url.trim() != scheme.applicationUrl?.trim()) {
      buffer.writeln('${_tr('official_portal', langCode)} ${url.trim()}');
      buffer.writeln();
    } else if (url != null && url.trim().isNotEmpty && !scheme.isOnline) {
      buffer.writeln('${_tr('official_portal', langCode)} ${url.trim()}');
      buffer.writeln();
    }

    if (scheme.helplineNumber != null &&
        scheme.helplineNumber!.trim().isNotEmpty) {
      buffer.writeln(
        '${_tr('helpline', langCode)} ${scheme.helplineNumber!.trim()}',
      );
      buffer.writeln();
    }

    buffer.writeln(_tr('footer', langCode));
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
      urisToTry.add(
        Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage'),
      );
      urisToTry.add(Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage'));
      urisToTry.add(
        Uri.parse(
          'https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMessage',
        ),
      );
    }

    // General WhatsApp share to contact picker / groups
    urisToTry.add(Uri.parse('whatsapp://send?text=$encodedMessage'));
    urisToTry.add(
      Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage'),
    );
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

  /// Interactive share method that shows destination options and language picker.
  static Future<void> shareScheme({
    required BuildContext context,
    required EligibleSchemeModel scheme,
    String? beneficiaryName,
    String? beneficiaryCode,
    String? beneficiaryMobile,
  }) async {
    final activeLanguageCode =
        AppLocalizations.of(context)?.locale.languageCode ?? 'en';
    String selectedLanguageCode =
        ['en', 'hi', 'as'].contains(activeLanguageCode)
            ? activeLanguageCode
            : 'en';

    final cleanPhone = cleanPhoneNumber(beneficiaryMobile);

    if (cleanPhone != null && cleanPhone.isNotEmpty) {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final displayDigits = cleanPhone.length > 10
              ? cleanPhone.substring(cleanPhone.length - 10)
              : cleanPhone;

          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
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
                    const SizedBox(height: 14),
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
                            _tr('dialog_title', selectedLanguageCode, {
                              'scheme': scheme.schemeName,
                            }),
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
                    const SizedBox(height: 14),

                    // Language Selector Chips
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8E4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tr('share_language_label', selectedLanguageCode),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF384940),
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 6,
                            children: [
                              ('en', 'English'),
                              ('hi', 'हिन्दी'),
                              ('as', 'অসমীয়া'),
                            ].map((opt) {
                              final isSelected = selectedLanguageCode == opt.$1;
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedLanguageCode = opt.$1;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE8F8EE)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? whatsAppGreen
                                          : const Color(0xFFD6DDD8),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    opt.$2,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? green
                                          : const Color(0xFF26352E),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option 1: Send to Beneficiary
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F8EE),
                        child: Icon(Icons.person_pin_rounded, color: whatsAppGreen),
                      ),
                      title: Text(
                        beneficiaryName != null &&
                                beneficiaryName.trim().isNotEmpty
                            ? _tr('send_to_beneficiary', selectedLanguageCode, {
                                'name': beneficiaryName.trim(),
                              })
                            : _tr(
                                'send_to_beneficiary_default',
                                selectedLanguageCode,
                              ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _tr('registered_number', selectedLanguageCode, {
                          'phone': displayDigits,
                        }),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final message = formatSchemeMessage(
                          context: context,
                          languageCode: selectedLanguageCode,
                          scheme: scheme,
                          beneficiaryName: beneficiaryName,
                          beneficiaryCode: beneficiaryCode,
                        );
                        await _executeLaunch(
                          context,
                          message,
                          cleanPhone,
                          selectedLanguageCode,
                        );
                      },
                    ),
                    const Divider(height: 1),

                    // Option 2: Choose another contact
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF0F3F1),
                        child: Icon(Icons.group_outlined, color: Color(0xFF3B4A41)),
                      ),
                      title: Text(
                        _tr('choose_contact', selectedLanguageCode),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _tr('opens_picker', selectedLanguageCode),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final message = formatSchemeMessage(
                          context: context,
                          languageCode: selectedLanguageCode,
                          scheme: scheme,
                          beneficiaryName: beneficiaryName,
                          beneficiaryCode: beneficiaryCode,
                        );
                        await _executeLaunch(
                          context,
                          message,
                          null,
                          selectedLanguageCode,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } else {
      // Direct launch to WhatsApp contact picker in active language
      final message = formatSchemeMessage(
        context: context,
        languageCode: selectedLanguageCode,
        scheme: scheme,
        beneficiaryName: beneficiaryName,
        beneficiaryCode: beneficiaryCode,
      );
      await _executeLaunch(
        context,
        message,
        null,
        selectedLanguageCode,
      );
    }
  }

  static Future<void> _executeLaunch(
    BuildContext context,
    String message,
    String? phone, [
    String langCode = 'en',
  ]) async {
    final success = await launchWhatsApp(
      message: message,
      phone: phone,
    );

    if (!success && context.mounted) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('copied_fallback', langCode)),
          backgroundColor: green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
