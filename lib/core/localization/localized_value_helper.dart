import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

/// Translates canonical English / database field values and status tokens
/// into the active UI locale (`en`, `hi`, `as`) at display time without
/// mutating stored records or API payloads.
class LocalizedValueHelper {
  LocalizedValueHelper._();

  static const Map<String, String> _optionKeys = {
    'yes': 'common.yes',
    'no': 'common.no',
    'not recorded': 'registration.not_recorded',
    'not_recorded': 'registration.not_recorded',
    'not provided': 'registration.not_provided',
    'not_provided': 'registration.not_provided',
    'available': 'registration.available',
    'not available': 'registration.not_available',
    'not_available': 'registration.not_available',
    'father': 'registration.opt_father',
    'mother': 'registration.opt_mother',
    'spouse': 'registration.opt_spouse',
    'guardian': 'registration.opt_guardian',
    'male': 'registration.gender_male',
    'female': 'registration.gender_female',
    'other': 'registration.gender_other',
    'rural': 'registration.rural',
    'urban': 'registration.urban',
    'general': 'registration.category_gen',
    'obc': 'registration.category_obc',
    'sc': 'registration.category_sc',
    'st': 'registration.category_st',
    'married': 'registration.status_married',
    'unmarried': 'registration.status_unmarried',
    'unmarried / single': 'registration.status_unmarried',
    'single': 'registration.status_unmarried',
    'widowed': 'registration.status_widow',
    'widow': 'registration.status_widow',
    'divorced': 'registration.status_divorced',
    'divorced / separated': 'registration.status_divorced',
    'separated': 'registration.opt_separated',
    'agricultural labourer': 'registration.occ_agri_labour',
    'cultivator / farmer': 'registration.occ_cultivator',
    'daily wage labourer': 'registration.occ_daily_wage',
    'construction worker': 'registration.occ_construction',
    'domestic worker': 'registration.occ_domestic',
    'street vendor': 'registration.occ_street_vendor',
    'artisan / weaver': 'registration.occ_artisan',
    'fisherman': 'registration.occ_fisherman',
    'small business / shop': 'registration.occ_small_business',
    'salaried - private': 'registration.occ_salaried_private',
    'salaried - government': 'registration.occ_salaried_govt',
    'self-employed / own account': 'registration.occ_self_employed',
    'student': 'registration.occ_student',
    'homemaker': 'registration.occ_homemaker',
    'unemployed': 'registration.occ_unemployed',
    'retired': 'registration.occ_retired',
    'unable to work': 'registration.occ_unable_work',
    'trader': 'registration.occ_trader',
    'weaver': 'registration.occ_weaver',
    'unorganized sector': 'registration.occ_unorganized',
    'service': 'registration.occ_service',
    'no income': 'registration.inc_none',
    'less than ₹25,000': 'registration.inc_lt_25k',
    'less than rs 25,000': 'registration.inc_lt_25k',
    '₹25,000–₹50,000': 'registration.inc_25k_50k',
    '₹25,000-₹50,000': 'registration.inc_25k_50k',
    'rs 25,000-50,000': 'registration.inc_25k_50k',
    '₹50,000–₹75,000': 'registration.inc_50k_75k',
    '₹50,000-₹75,000': 'registration.inc_50k_75k',
    'rs 50,000-75,000': 'registration.inc_50k_75k',
    'less than ₹1,00,000': 'registration.inc_lt_1l',
    'less than rs 1,00,000': 'registration.inc_lt_1l',
    'more than ₹1,00,000': 'registration.inc_gt_1l',
    'more than rs 1,00,000': 'registration.inc_gt_1l',
    'less than ₹8,00,000': 'registration.inc_lt_8l',
    'less than rs 8,00,000': 'registration.inc_lt_8l',
    'national': 'whatsapp_share.level_national',
    'state': 'whatsapp_share.level_state',
    'online': 'whatsapp_share.mode_online',
    'offline': 'whatsapp_share.mode_offline',
    'both': 'whatsapp_share.mode_both',
    'eligible': 'eligibility.eligible_badge',
    'potentially eligible': 'eligibility.potentially_eligible_badge',
    'aadhaar card': 'registration.doc_aadhaar',
    'aadhaar': 'registration.doc_aadhaar',
    'bank account details': 'registration.doc_bank_account',
    'bank account': 'registration.doc_bank_account',
    'bank passbook': 'registration.doc_bank_account',
    'bank passbook details': 'registration.doc_bank_account',
    'bank details': 'registration.doc_bank_account',
    'pan card': 'registration.doc_pan',
    'pan': 'registration.doc_pan',
    'voter id': 'registration.doc_voter',
    'voter id card': 'registration.doc_voter',
    'ration card': 'registration.doc_ration',
    'bpl ration card': 'registration.doc_ration',
    'income certificate': 'registration.doc_income_cert',
    'caste certificate': 'registration.doc_caste_cert',
    'disability certificate': 'registration.doc_disability_card',
    'disability card': 'registration.doc_disability_card',
    'udid card': 'registration.doc_disability_card',
    'antyodaya anna yojana (aay) ration card': 'registration.doc_ration_aay',
    'aay ration card': 'registration.doc_ration_aay',
    'priority household (phh) ration card': 'registration.doc_ration_phh',
    'phh ration card': 'registration.doc_ration_phh',
    'death certificate': 'registration.doc_death',
    'death certificate of husband/father/primary earner of family':
        'registration.doc_death',
    'death certificate of breadwinner': 'registration.doc_death',
    'residence / domicile certificate': 'registration.doc_residence',
    'residence certificate': 'registration.doc_residence',
    'domicile certificate': 'registration.doc_residence',
    'proof of residence': 'registration.doc_residence',
    'residence proof': 'registration.doc_residence',
    'address proof': 'registration.doc_residence',
    'medical records': 'registration.doc_medical',
    'medical report': 'registration.doc_medical',
    'medical reports': 'registration.doc_medical',
    'fir / police report copy': 'registration.doc_fir',
    'fir or police complaint copy': 'registration.doc_fir',
    'fir copy': 'registration.doc_fir',
    'police complaint': 'registration.doc_fir',
    'police report': 'registration.doc_fir',
    'birth certificate': 'registration.doc_birth',
  };

  static const Map<String, String> _statusKeys = {
    'matched': 'beneficiaries.status_matched',
    'assessed': 'beneficiaries.status_assessed',
    'completed': 'beneficiaries.status_completed',
    'complete': 'followup.status_complete',
    'approved': 'beneficiaries.status_approved',
    'in progress': 'beneficiaries.status_in_progress',
    'not assessed': 'beneficiaries.status_not_assessed',
    'pending sync': 'common.pending_sync',
    'sync failed': 'dashboard.sync_failed',
    'pending': 'followup.pending_tab',
    'synced': 'common.synced',
    'syncing': 'common.syncing',
    'draft': 'beneficiaries.status_draft',
    'submitted': 'beneficiaries.status_submitted',
    'unknown': 'beneficiaries.status_unknown',
    '': 'beneficiaries.status_unknown',
  };

  static const Map<String, List<String>> _fallbackMonths = {
    'en': [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    'hi': [
      'जन',
      'फ़र',
      'मार्च',
      'अप्रैल',
      'मई',
      'जून',
      'जुल',
      'अग',
      'सित',
      'अक्टू',
      'नव',
      'दिस',
    ],
    'as': [
      'জানু',
      'ফেব্ৰু',
      'মাৰ্চ',
      'এপ্ৰিল',
      'মে',
      'জুন',
      'জুলাই',
      'আগ',
      'ছেপ্টে',
      'অক্টো',
      'নৱে',
      'ডিচে',
    ],
  };

  static String translateOption(BuildContext context, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;

    final key = _optionKeys[trimmed.toLowerCase()];
    if (key != null) {
      return context.tr(key);
    }
    return raw;
  }

  static String translateDocumentName(BuildContext context, String? rawName) {
    if (rawName == null) return '';
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return '';

    // 1. Direct match via optionKeys
    final lower = trimmed.toLowerCase();
    final key = _optionKeys[lower];
    if (key != null) {
      return context.tr(key);
    }

    // 2. Fuzzy / keyword match for document labels from database/catalogs
    if (lower.contains('aadhaar')) {
      return context.tr('registration.doc_aadhaar');
    }
    if (lower.contains('bank') &&
        (lower.contains('account') ||
            lower.contains('passbook') ||
            lower.contains('details'))) {
      return context.tr('registration.doc_bank_account');
    }
    if (lower.contains('pan card') || lower == 'pan') {
      return context.tr('registration.doc_pan');
    }
    if (lower.contains('voter')) {
      return context.tr('registration.doc_voter');
    }
    if (lower.contains('birth certificate') || lower.contains('age proof')) {
      return context.tr('registration.doc_birth');
    }
    if (lower.contains('income cert') || lower.contains('proof of income')) {
      return context.tr('registration.doc_income_cert');
    }
    if (lower.contains('caste cert')) {
      return context.tr('registration.doc_caste_cert');
    }
    if (lower.contains('disability') || lower.contains('udid')) {
      return context.tr('registration.doc_disability_card');
    }
    if (lower.contains('aay')) {
      return context.tr('registration.doc_ration_aay');
    }
    if (lower.contains('phh')) {
      return context.tr('registration.doc_ration_phh');
    }
    if (lower.contains('death cert')) {
      return context.tr('registration.doc_death');
    }
    if (lower.contains('domicile') ||
        lower.contains('residence') ||
        lower.contains('address proof')) {
      return context.tr('registration.doc_residence');
    }
    if (lower.contains('medical') || lower.contains('health record')) {
      return context.tr('registration.doc_medical');
    }
    if (lower.contains('fir') || lower.contains('police')) {
      return context.tr('registration.doc_fir');
    }
    if (lower.contains('ration')) {
      return context.tr('registration.doc_ration');
    }

    return trimmed;
  }

  static String translateGender(
    BuildContext context,
    dynamic rawGender, {
    String? fallback,
  }) {
    final raw = rawGender?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return fallback ?? context.tr('registration.not_provided');
    }
    switch (raw.toLowerCase()) {
      case 'm':
      case 'male':
        return context.tr('registration.gender_male');
      case 'f':
      case 'female':
        return context.tr('registration.gender_female');
      case 'o':
      case 'other':
        return context.tr('registration.gender_other');
      default:
        return translateOption(context, raw);
    }
  }

  static String translateStatus(BuildContext context, String? status) {
    final raw = (status ?? '').trim();
    final normalized = raw.toLowerCase().replaceAll('_', ' ');

    final exactKey = _statusKeys[normalized];
    if (exactKey != null) {
      return context.tr(exactKey);
    }
    if (normalized.contains('sync failed')) {
      return context.tr('dashboard.sync_failed');
    }
    if (normalized.contains('pending sync')) {
      return context.tr('common.pending_sync');
    }
    if (normalized.contains('completed')) {
      return context.tr('beneficiaries.status_completed');
    }
    return raw.isEmpty ? context.tr('beneficiaries.status_unknown') : raw;
  }

  static String formatBool(
    BuildContext context,
    dynamic raw, {
    String? fallback,
  }) {
    if (raw == null) {
      return fallback ?? context.tr('registration.not_provided');
    }
    if (raw is bool) {
      return context.tr(raw ? 'common.yes' : 'common.no');
    }
    final normalized = raw.toString().trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallback ?? context.tr('registration.not_provided');
    }
    if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
      return context.tr('common.yes');
    }
    if (normalized == '0' || normalized == 'false' || normalized == 'no') {
      return context.tr('common.no');
    }
    return translateOption(context, raw.toString());
  }

  static String formatAge(
    BuildContext context,
    dynamic rawAge, {
    String? fallback,
  }) {
    final raw = rawAge?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return fallback ?? context.tr('beneficiaries.age_unavailable');
    }
    return context.tr('beneficiaries.age_years', args: {'age': raw});
  }

  static String formatDate(
    BuildContext context,
    dynamic rawDate, {
    String? fallback,
  }) {
    final raw = rawDate?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return fallback ?? context.tr('registration.not_provided');
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final dt = parsed.isUtc ? parsed.toLocal() : parsed;
    final localeCode = AppLocalizations.of(context)?.locale.languageCode ?? 'en';

    try {
      return DateFormat('d MMM y', localeCode).format(dt);
    } catch (_) {
      final months = _fallbackMonths[localeCode] ?? _fallbackMonths['en']!;
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
  }
}
