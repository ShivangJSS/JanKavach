import '../models/eligible_scheme_model.dart';
import 'eligibility_attributes_data.dart';
import 'scheme_rules_data.dart';
import 'schemes_catalog_data.dart';

/// Dart implementation of the JanKavach Scheme Eligibility Engine
/// matching JanKavach\Libraries\EligibilityEngine with 1:1 precision.
class OfflineEligibilityEngine {
  static const String eligible = 'Eligible';
  static const String potential = 'Potentially Eligible';
  static const String verify = 'Needs Verification';
  static const String notEligible = 'Not Eligible';

  final int eligibleThreshold;
  final int potentialThreshold;

  final Map<String, EligibilityAttributeData> _attributes = {};
  final Map<int, List<SchemeRuleData>> _rulesByScheme = {};
  final List<Map<String, dynamic>> _schemesCatalog = [];

  OfflineEligibilityEngine({
    this.eligibleThreshold = 90,
    this.potentialThreshold = 60,
    List<SchemeRuleData>? customRules,
    List<EligibilityAttributeData>? customAttributes,
    List<Map<String, dynamic>>? customSchemes,
  }) {
    final attrs = customAttributes ?? kBundledAttributes;
    for (final a in attrs) {
      _attributes[a.attributeKey] = a;
    }

    final rules = customRules ?? kBundledSchemeRules;
    for (final r in rules) {
      if (r.isActive) {
        _rulesByScheme.putIfAbsent(r.schemeId, () => []).add(r);
      }
    }

    final rawCatalog = customSchemes ?? kBundledSchemes;
    _schemesCatalog.addAll(rawCatalog);
  }

  /// Builds and normalizes profile map from beneficiary fields.
  Map<String, dynamic> buildProfile(Map<String, dynamic> beneficiary) {
    final Map<String, dynamic> profile = {};

    // 1. Direct and aliased attributes
    for (final entry in _attributes.entries) {
      final key = entry.key;
      final attr = entry.value;

      dynamic val = beneficiary[key];
      if (val == null && attr.sourceColumn != null) {
        val = beneficiary[attr.sourceColumn];
      }

      // Check common aliases
      if (val == null) {
        if (key == 'gender') {
          val = beneficiary['gender'] ?? beneficiary['sex'];
        } else if (key == 'dob') {
          val = beneficiary['dob'] ?? beneficiary['date_of_birth'];
        } else if (key == 'age') {
          val = beneficiary['age'];
        } else if (key == 'state_id') {
          val = beneficiary['state_id'] ??
              (beneficiary['state'] is Map
                  ? beneficiary['state']['id']
                  : null);
        } else if (key == 'district_id') {
          val = beneficiary['district_id'] ??
              (beneficiary['district'] is Map
                  ? beneficiary['district']['id']
                  : null);
        } else if (key == 'area_type') {
          val = beneficiary['area_type'];
        } else if (key == 'marital_status') {
          val = beneficiary['marital_status'];
        } else if (key == 'social_category') {
          val = beneficiary['social_category'] ??
              beneficiary['category'] ??
              beneficiary['caste'];
        } else if (key == 'religion') {
          val = beneficiary['religion'];
        } else if (key == 'bpl_status') {
          val = beneficiary['bpl_status'];
        } else if (key == 'annual_income') {
          val = beneficiary['annual_income'] ?? beneficiary['income'];
        } else if (key == 'ration_card_type') {
          val = beneficiary['ration_card_type'];
        }
      }

      if (val != null && val.toString().trim().isNotEmpty) {
        profile[key] = val;
      }
    }

    // 2. Unpack questionnaire / assessment answers if present
    if (beneficiary['answers'] is Map) {
      final answers = beneficiary['answers'] as Map;
      answers.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) {
          profile[k.toString()] = v;
        }
      });
    }

    // 3. Normalize categories & statuses to backend standard lookup codes
    if (profile['social_category'] != null) {
      final sc = profile['social_category'].toString().trim().toUpperCase();
      if (sc == 'GENERAL' || sc == 'GEN') {
        profile['social_category'] = 'GEN';
      } else if (sc.contains('OBC') || sc.contains('OTHER BACKWARD')) {
        profile['social_category'] = 'OBC';
      } else if (sc.contains('SC') || sc.contains('SCHEDULED CASTE')) {
        profile['social_category'] = 'SC';
      } else if (sc.contains('ST') || sc.contains('SCHEDULED TRIBE')) {
        profile['social_category'] = 'ST';
      }
    }

    if (profile['marital_status'] != null) {
      final ms = profile['marital_status'].toString().trim().toUpperCase();
      if (ms == 'SINGLE' || ms == 'UNMARRIED') {
        profile['marital_status'] = 'UNMARRIED';
      } else if (ms == 'MARRIED') {
        profile['marital_status'] = 'MARRIED';
      } else if (ms == 'WIDOW' || ms == 'WIDOWED') {
        profile['marital_status'] = 'WIDOWED';
      } else if (ms == 'DIVORCED') {
        profile['marital_status'] = 'DIVORCED';
      } else if (ms == 'SEPARATED') {
        profile['marital_status'] = 'SEPARATED';
      }
    }

    // 4. Ration card & BPL derivation
    if (profile['doc_ration_aay'] == 'Yes' || profile['doc_ration_phh'] == 'Yes') {
      profile['has_ration_card'] = 1;
      profile['bpl_status'] = 'Yes';
      profile['ration_card_type'] ??=
          (profile['doc_ration_aay'] == 'Yes') ? 'AAY' : 'PHH';
    }

    // 5. Vulnerability groups normalization
    if (profile['vulnerability_group'] != null) {
      final vg = profile['vulnerability_group'].toString().toUpperCase();
      if (vg.contains('ELDERLY')) profile['senior_citizen'] = 1;
      if (vg.contains('PWD_CHRONIC') || vg.contains('PWD')) profile['has_disability'] = 1;
      if (vg.contains('TRIBAL')) profile['social_category'] = 'ST';
      if (vg.contains('MINORITY')) profile['is_minority'] = 1;
      if (vg.contains('MIGRANT')) profile['is_migrant'] = 1;
    }

    // 6. Disability card
    if (profile['doc_disability_card'] == 'Yes') {
      profile['has_disability'] = 1;
    }

    // 7. Income & Earning
    if (profile['earning_status'] != null) {
      final es = profile['earning_status'].toString().trim().toUpperCase();
      if (es == 'NO' || es == 'UNEMPLOYED') {
        profile['annual_income'] ??= 0;
      }
    }

    // 8. Fallback age calculation from DOB if age is missing
    if ((profile['age'] == null || profile['age'] == 0 || profile['age'] == '') &&
        profile['dob'] != null) {
      final dobStr = profile['dob'].toString().trim();
      final parsed = DateTime.tryParse(dobStr);
      if (parsed != null) {
        final now = DateTime.now();
        int calcAge = now.year - parsed.year;
        if (now.month < parsed.month ||
            (now.month == parsed.month && now.day < parsed.day)) {
          calcAge--;
        }
        profile['age'] = calcAge;
      }
    }

    return applyDerived(profile);
  }

  /// Derives synthetic attributes (senior_citizen, has_disability, is_farmer, etc.)
  Map<String, dynamic> applyDerived(Map<String, dynamic> raw) {
    final p = Map<String, dynamic>.from(raw);

    // Senior citizen
    if (p['age'] != null && p['age'] != '') {
      final a = (p['age'] as num?)?.toInt() ?? int.tryParse(p['age'].toString()) ?? 0;
      if (a >= 60) {
        p['senior_citizen'] = 1;
      } else {
        p['senior_citizen'] ??= 0;
      }
    }

    // Disability
    if (p['disability_status'] != null) {
      final s = p['disability_status'].toString().trim().toUpperCase();
      p['has_disability'] = (s.isNotEmpty && s != 'NONE') ? 1 : 0;
    } else if (p['disability_percent'] != null) {
      final dp = double.tryParse(p['disability_percent'].toString()) ?? 0.0;
      p['has_disability'] = (dp >= 40.0) ? 1 : 0;
    }

    // Farmer
    final farmerCat = (p['farmer_category'] ?? '').toString().trim().toUpperCase();
    final occupation = (p['occupation'] ?? '').toString().trim().toUpperCase();
    if (farmerCat.isNotEmpty || occupation.isNotEmpty) {
      final isFarmer = (farmerCat.isNotEmpty && farmerCat != 'NOT_FARMER') ||
          (occupation == 'CULTIVATOR' || occupation == 'AGRI_LABOUR');
      p['is_farmer'] = isFarmer ? 1 : 0;
    }

    // Minority
    final category = (p['social_category'] ?? '').toString().trim().toUpperCase();
    final religion = (p['religion'] ?? '').toString().trim().toUpperCase();
    if (category.isNotEmpty || religion.isNotEmpty) {
      p['is_minority'] = (category == 'MIN' ||
              const [
                'MUSLIM',
                'CHRISTIAN',
                'SIKH',
                'BUDDHIST',
                'JAIN',
                'PARSI'
              ].contains(religion))
          ? 1
          : (p['is_minority'] ?? 0);
    }

    // Ration card
    if (p['ration_card_type'] != null) {
      final card = p['ration_card_type'].toString().trim().toUpperCase();
      p['has_ration_card'] = (card.isNotEmpty && card != 'NONE') ? 1 : 0;
    }

    // Transgender
    if (p['gender'] != null) {
      final g = p['gender'].toString().trim().toLowerCase();
      p['is_transgender'] = (g == 'other') ? 1 : 0;
    }

    return p;
  }

  /// Evaluates all applicable schemes for the given beneficiary profile.
  EligibleSchemesResponse evaluateBeneficiary(
    Map<String, dynamic> beneficiaryRaw, {
    List<Map<String, dynamic>>? availableSchemes,
  }) {
    final profile = buildProfile(beneficiaryRaw);

    final int? stateId = profile['state_id'] != null
        ? ((profile['state_id'] as num?)?.toInt() ??
            int.tryParse(profile['state_id'].toString()))
        : null;

    final catalog = availableSchemes ?? _schemesCatalog;
    final applicable = _filterApplicableSchemes(catalog, stateId);

    final List<EligibleSchemeModel> eligibleList = [];
    final List<EligibleSchemeModel> potentialList = [];
    int verifyCount = 0;
    int notEligibleCount = 0;

    for (final scheme in applicable) {
      final schemeId = (scheme['id'] as num?)?.toInt() ?? 0;
      final rules = _rulesByScheme[schemeId] ?? [];

      final outcome = evaluateScheme(profile, schemeId, rules);
      final status = outcome['eligibility_status'] as String;

      final model = _formatSchemeMatch(scheme, outcome);

      if (status == eligible) {
        eligibleList.add(model);
      } else if (status == potential) {
        potentialList.add(model);
      } else if (status == verify) {
        verifyCount++;
      } else {
        notEligibleCount++;
      }
    }

    // Sort by priority first (Priority 1, Priority 2, non-null ascending, null last),
    // then matchPercent descending, then schemeId ascending.
    int comparePriorityAndScore(EligibleSchemeModel a, EligibleSchemeModel b) {
      final aPriority = (a.priority['id'] as num?)?.toInt();
      final bPriority = (b.priority['id'] as num?)?.toInt();

      if (aPriority == null && bPriority != null) return 1;
      if (aPriority != null && bPriority == null) return -1;
      if (aPriority != null && bPriority != null) {
        final cmp = aPriority.compareTo(bPriority);
        if (cmp != 0) return cmp;
      }

      final scoreCmp = b.matchPercent.compareTo(a.matchPercent);
      if (scoreCmp != 0) return scoreCmp;

      return (a.schemeId ?? 0).compareTo(b.schemeId ?? 0);
    }

    eligibleList.sort(comparePriorityAndScore);
    potentialList.sort(comparePriorityAndScore);

    final int totalEvaluated = applicable.length;
    final int eligibleCount = eligibleList.length;
    final int potentialCount = potentialList.length;

    final beneficiarySummary = {
      'id': beneficiaryRaw['id'] ?? beneficiaryRaw['server_id'] ?? 0,
      'name': beneficiaryRaw['name'] ?? beneficiaryRaw['full_name'] ?? 'Beneficiary',
      'gender': profile['gender']?.toString() ?? '',
      'dob': profile['dob']?.toString() ?? '',
      'age': profile['age'],
      'mobile': beneficiaryRaw['mobile']?.toString() ?? '',
      'state_id': stateId,
      'state_name': beneficiaryRaw['state_name'] ??
          (beneficiaryRaw['state'] is Map
              ? beneficiaryRaw['state']['name']
              : null),
    };

    final summary = {
      'total_evaluated': totalEvaluated,
      'eligible_count': eligibleCount,
      'potential_count': potentialCount,
      'verify_count': verifyCount,
      'not_eligible_count': notEligibleCount,
    };

    return EligibleSchemesResponse(
      success: true,
      message: 'Eligibility evaluated successfully from beneficiary profile and scheme rules.',
      beneficiary: beneficiarySummary,
      summary: summary,
      eligibleSchemes: eligibleList,
      potentiallyEligibleSchemes: potentialList,
    );
  }

  /// Filters active schemes applicable nationally or in the beneficiary's State.
  List<Map<String, dynamic>> _filterApplicableSchemes(
    List<Map<String, dynamic>> catalog,
    int? stateId,
  ) {
    return catalog.where((s) {
      // 1. Must not be discontinued or deleted
      final status = (s['scheme_status'] ?? s['status'] ?? '').toString();
      if (status.toLowerCase() == 'discontinued') return false;

      final isActive = s['is_active'];
      if (isActive == false || isActive == 0 || isActive == '0') return false;

      // 2. Geography filter
      final level = (s['scheme_level'] ?? s['level'] ?? 'National')
          .toString()
          .toLowerCase();

      if (level == 'national') return true;

      if (stateId != null) {
        final schemeStateId = (s['state_id'] as num?)?.toInt() ??
            (s['state'] is Map ? (s['state']['id'] as num?)?.toInt() : null);
        if (schemeStateId != null && schemeStateId == stateId) return true;

        if (s['applicable_states'] is List) {
          final states = s['applicable_states'] as List;
          for (final st in states) {
            final stId = st is Map ? (st['id'] as num?)?.toInt() : (st as num?)?.toInt();
            if (stId != null && stId == stateId) return true;
          }
        }
      }

      return false;
    }).toList();
  }

  /// Evaluates one scheme against a beneficiary profile.
  Map<String, dynamic> evaluateScheme(
    Map<String, dynamic> profile,
    int schemeId,
    List<SchemeRuleData> rules,
  ) {
    if (rules.isEmpty) {
      return {
        'scheme_id': schemeId,
        'match_percent': 0.0,
        'eligibility_status': verify,
        'rules_total': 0,
        'rules_passed': 0,
        'rules_failed': 0,
        'rules_unknown': 0,
        'passed_reasons': <Map<String, dynamic>>[],
        'failed_reasons': <Map<String, dynamic>>[],
        'unknown_reasons': <Map<String, dynamic>>[],
        'reason_text':
            'No eligibility rules have been configured for this scheme yet, so eligibility must be confirmed manually.',
      };
    }

    // Group rules by rule_group (ANDed within group; separate groups are ORed)
    final Map<int, List<SchemeRuleData>> groups = {};
    for (final r in rules) {
      groups.putIfAbsent(r.ruleGroup, () => []).add(r);
    }

    Map<String, dynamic>? best;
    for (final entry in groups.entries) {
      final outcome = evaluateGroup(profile, entry.value);
      outcome['rule_group'] = entry.key;

      if (best == null || _isBetter(outcome, best)) {
        best = outcome;
      }
    }

    final status = grade(best!);
    final percent = double.parse((best['percent'] as double).toStringAsFixed(2));

    return {
      'scheme_id': schemeId,
      'match_percent': percent,
      'eligibility_status': status,
      'rules_total': (best['passed'] as List).length +
          (best['failed'] as List).length +
          (best['unknown'] as List).length,
      'rules_passed': (best['passed'] as List).length,
      'rules_failed': (best['failed'] as List).length,
      'rules_unknown': (best['unknown'] as List).length,
      'passed_reasons': best['passed'],
      'failed_reasons': best['failed'],
      'unknown_reasons': best['unknown'],
      'reason_text': explain(status, best),
    };
  }

  /// Evaluates the AND-ed rules of one group.
  Map<String, dynamic> evaluateGroup(
    Map<String, dynamic> profile,
    List<SchemeRuleData> rules,
  ) {
    final List<Map<String, dynamic>> passed = [];
    final List<Map<String, dynamic>> failed = [];
    final List<Map<String, dynamic>> unknown = [];
    int totalWeight = 0;
    int passedWeight = 0;
    bool mandatoryFailed = false;
    int mandatoryCount = 0;

    for (final rule in rules) {
      final weight = rule.weight > 0 ? rule.weight : 1;
      totalWeight += weight;
      if (rule.isMandatory) {
        mandatoryCount++;
      }

      final key = rule.attributeKey;
      final value = profile[key];
      final label = attributeLabel(key);
      final expected = describeExpectation(rule);

      // is_set / not_set are the only operators that judge absence
      if (rule.operator != 'is_set' &&
          rule.operator != 'not_set' &&
          (value == null || value == '')) {
        unknown.add({
          'attribute': key,
          'label': label,
          'expected': expected,
          'message': '$label has not been recorded for this beneficiary',
          'rule': rule.description,
          'mandatory': rule.isMandatory,
        });
        continue;
      }

      if (testRule(value, rule)) {
        passedWeight += weight;
        passed.add({
          'attribute': key,
          'label': label,
          'actual': displayValue(key, value),
          'expected': expected,
          'message': '$label is ${displayValue(key, value)}',
          'rule': rule.description,
        });
      } else {
        failed.add({
          'attribute': key,
          'label': label,
          'actual': displayValue(key, value),
          'expected': expected,
          'message':
              '$label is ${displayValue(key, value)}, but the scheme requires $expected',
          'rule': rule.description,
          'mandatory': rule.isMandatory,
        });
        if (rule.isMandatory) {
          mandatoryFailed = true;
        }
      }
    }

    return {
      'passed': passed,
      'failed': failed,
      'unknown': unknown,
      'percent': totalWeight > 0 ? (passedWeight / totalWeight) * 100.0 : 0.0,
      'mandatory_failed': mandatoryFailed,
      'rule_count': rules.length,
      'mandatory_count': mandatoryCount,
    };
  }

  /// Prefer a group with no mandatory failure, then higher score, then fewer unknowns.
  bool _isBetter(Map<String, dynamic> candidate, Map<String, dynamic> current) {
    if (candidate['mandatory_failed'] != current['mandatory_failed']) {
      return candidate['mandatory_failed'] == false;
    }
    final double diff =
        (candidate['percent'] as double) - (current['percent'] as double);
    if (diff.abs() > 0.001) {
      return candidate['percent'] > current['percent'];
    }
    return (candidate['unknown'] as List).length <
        (current['unknown'] as List).length;
  }

  /// Exact replica of EligibilityEngine.php grade()
  String grade(Map<String, dynamic> outcome) {
    if (outcome['mandatory_failed'] == true) {
      return notEligible;
    }
    final double percent = outcome['percent'] as double;
    final bool hasUnknown = (outcome['unknown'] as List).isNotEmpty;
    final bool wellEvidenced = (outcome['mandatory_count'] as int) > 0 ||
        (outcome['rule_count'] as int) >= 3;

    if (!hasUnknown && percent >= eligibleThreshold && wellEvidenced) {
      return eligible;
    }
    if (percent >= potentialThreshold) {
      return potential;
    }
    return verify;
  }

  /// Evaluates single comparison condition against an attribute.
  bool testRule(dynamic value, SchemeRuleData rule) {
    final op = rule.operator;
    final attr = _attributes[rule.attributeKey];
    final type = attr?.dataType ?? 'string';

    final v1 = rule.value1;
    final v2 = rule.value2;
    final List<String> list = (rule.valueList ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (op == 'is_set') return value != null && value != '';
    if (op == 'not_set') return value == null || value == '';

    if (type == 'int' || type == 'decimal') {
      final double actual = double.tryParse(value.toString()) ?? 0.0;
      final double? target1 = v1 != null ? double.tryParse(v1) : null;
      final double? target2 = v2 != null ? double.tryParse(v2) : null;

      switch (op) {
        case 'eq':
          return target1 != null && (actual - target1).abs() < 0.00001;
        case 'neq':
          return target1 != null && (actual - target1).abs() >= 0.00001;
        case 'gt':
          return target1 != null && actual > target1;
        case 'gte':
          return target1 != null && actual >= target1;
        case 'lt':
          return target1 != null && actual < target1;
        case 'lte':
          return target1 != null && actual <= target1;
        case 'between':
          return target1 != null &&
              target2 != null &&
              actual >= target1 &&
              actual <= target2;
        case 'any_of':
          return list.any((item) {
            final parsed = double.tryParse(item);
            return parsed != null && (actual - parsed).abs() < 0.00001;
          });
        case 'not_in':
          return !list.any((item) {
            final parsed = double.tryParse(item);
            return parsed != null && (actual - parsed).abs() < 0.00001;
          });
        case 'contains':
          return value.toString().contains(v1 ?? '');
        default:
          return false;
      }
    }

    if (type == 'bool') {
      final bool actual = toBool(value);
      final bool want = toBool(v1);
      switch (op) {
        case 'eq':
          return actual == want;
        case 'neq':
          return actual != want;
        case 'any_of':
          return list.any((x) => toBool(x) == actual);
        case 'not_in':
          return !list.any((x) => toBool(x) == actual);
        default:
          return false;
      }
    }

    if (type == 'date') {
      final actual = DateTime.tryParse(value.toString());
      final target1 = v1 != null ? DateTime.tryParse(v1) : null;
      final target2 = v2 != null ? DateTime.tryParse(v2) : null;
      if (actual == null) return false;

      switch (op) {
        case 'eq':
          return target1 != null && actual.isAtSameMomentAs(target1);
        case 'neq':
          return target1 != null && !actual.isAtSameMomentAs(target1);
        case 'gt':
          return target1 != null && actual.isAfter(target1);
        case 'gte':
          return target1 != null &&
              (actual.isAfter(target1) || actual.isAtSameMomentAs(target1));
        case 'lt':
          return target1 != null && actual.isBefore(target1);
        case 'lte':
          return target1 != null &&
              (actual.isBefore(target1) || actual.isAtSameMomentAs(target1));
        case 'between':
          return target1 != null &&
              target2 != null &&
              (actual.isAfter(target1) || actual.isAtSameMomentAs(target1)) &&
              (actual.isBefore(target2) || actual.isAtSameMomentAs(target2));
        default:
          return false;
      }
    }

    if (type == 'set') {
      final members = value
          .toString()
          .toLowerCase()
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toSet();
      final wanted = list.map((l) => l.toLowerCase()).toSet();
      final target = (v1 ?? '').toLowerCase();

      switch (op) {
        case 'eq':
        case 'contains':
          return members.contains(target);
        case 'neq':
          return !members.contains(target);
        case 'any_of':
          return members.intersection(wanted).isNotEmpty;
        case 'not_in':
          return members.intersection(wanted).isEmpty;
        default:
          return false;
      }
    }

    // String / Enum case-insensitive
    final actual = value.toString().trim().toLowerCase();
    final lower1 = (v1 ?? '').trim().toLowerCase();
    final lowerList = list.map((x) => x.trim().toLowerCase()).toList();

    switch (op) {
      case 'eq':
        return actual == lower1;
      case 'neq':
        return actual != lower1;
      case 'contains':
        return lower1.isNotEmpty && actual.contains(lower1);
      case 'any_of':
        return lowerList.contains(actual);
      case 'not_in':
        return !lowerList.contains(actual);
      default:
        return false;
    }
  }

  bool toBool(dynamic value) {
    if (value is bool) return value;
    final s = value.toString().trim().toLowerCase();
    return s == '1' || s == 'yes' || s == 'true' || s == 'y' || s == 'on';
  }

  String attributeLabel(String key) {
    return _attributes[key]?.label ??
        key.replaceAll('_', ' ').split(' ').map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        }).join(' ');
  }

  String displayValue(String attributeKey, dynamic value) {
    if (value == null || value == '') return 'not recorded';
    final attr = _attributes[attributeKey];
    if (attr != null && attr.dataType == 'bool') {
      return toBool(value) ? 'Yes' : 'No';
    }
    return value.toString();
  }

  String describeExpectation(SchemeRuleData rule) {
    final key = rule.attributeKey;
    final v1 = rule.value1 ?? '';
    final v2 = rule.value2 ?? '';
    final list = (rule.valueList ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    switch (rule.operator) {
      case 'eq':
        return displayValue(key, v1);
      case 'neq':
        return 'anything other than ${displayValue(key, v1)}';
      case 'gt':
        return 'more than ${displayValue(key, v1)}';
      case 'gte':
        return '${displayValue(key, v1)} or above';
      case 'lt':
        return 'less than ${displayValue(key, v1)}';
      case 'lte':
        return '${displayValue(key, v1)} or below';
      case 'between':
        return '${displayValue(key, v1)} to ${displayValue(key, v2)}';
      case 'contains':
        return 'text containing "$v1"';
      case 'any_of':
        return 'one of ${list.map((x) => displayValue(key, x)).join(', ')}';
      case 'not_in':
        return 'none of ${list.map((x) => displayValue(key, x)).join(', ')}';
      case 'is_set':
        return 'to be recorded';
      case 'not_set':
        return 'to be blank';
      default:
        return v1;
    }
  }

  String explain(String status, Map<String, dynamic> outcome) {
    final passed = (outcome['passed'] as List)
        .map((r) => '${r['label']} is ${r['actual']}')
        .toList();
    final failed = (outcome['failed'] as List)
        .map((r) => '${r['label']} is ${r['actual']} (needs ${r['expected']})')
        .toList();
    final unknown = (outcome['unknown'] as List)
        .map((r) => r['label'].toString())
        .toList();

    final List<String> parts = [];
    if (status == notEligible) {
      final blockers = (outcome['failed'] as List)
          .where((r) => r['mandatory'] == true)
          .map((r) =>
              '${r['label']} is ${r['actual']} but the scheme requires ${r['expected']}')
          .take(3)
          .toList();
      parts.add('Not eligible because ${blockers.join('; ')}.');
      if (passed.isNotEmpty) {
        parts.add('Other conditions met: ${passed.take(4).join(', ')}.');
      }
      return parts.join(' ');
    }

    if (passed.isNotEmpty) {
      parts.add('Matched because ${passed.take(5).join(', ')}.');
    }
    if (failed.isNotEmpty) {
      parts.add('Conditions not met: ${failed.take(3).join('; ')}.');
    }
    if (unknown.isNotEmpty) {
      parts.add('Still to confirm: ${unknown.take(5).join(', ')}.');
    }
    if (parts.isEmpty) {
      parts.add(
          'Eligibility could not be determined from the information recorded so far.');
    }
    return parts.join(' ');
  }

  /// Formats evaluation result into standard EligibleSchemeModel
  EligibleSchemeModel _formatSchemeMatch(
    Map<String, dynamic> scheme,
    Map<String, dynamic> outcome,
  ) {
    final theme = scheme['theme'] is Map
        ? Map<String, dynamic>.from(scheme['theme'])
        : {
            'name': scheme['theme_name'],
            'color': scheme['theme_color'],
            'icon': scheme['theme_icon'],
          };

    final priority = scheme['priority'] is Map
        ? Map<String, dynamic>.from(scheme['priority'])
        : {
            'id': scheme['priority_id'],
            'name': scheme['priority_name'],
            'rank': scheme['priority_rank'],
          };

    final benefit = scheme['benefit'] is Map
        ? Map<String, dynamic>.from(scheme['benefit'])
        : {
            'type': scheme['benefit_type'],
            'description': scheme['benefit_description'],
            'amount': scheme['benefit_amount'],
            'amount_text': scheme['benefit_amount_text'],
            'mode': scheme['benefit_mode'],
            'frequency': scheme['benefit_frequency'],
          };

    final application = scheme['application'] is Map
        ? Map<String, dynamic>.from(scheme['application'])
        : {
            'mode': scheme['application_mode'],
            'process': scheme['application_process'],
            'portal_url': scheme['portal_url'],
            'source_url': scheme['source_url'],
            'source_website': scheme['source_website'],
            'helpline_number': scheme['helpline_number'],
          };

    final passedReasons = (outcome['passed_reasons'] as List? ?? [])
        .map((r) => r is Map ? (r['message'] ?? r.toString()) : r.toString())
        .toList();

    final failedReasons = (outcome['failed_reasons'] as List? ?? [])
        .map((r) => r is Map ? (r['message'] ?? r.toString()) : r.toString())
        .toList();

    final unknownReasons = (outcome['unknown_reasons'] as List? ?? [])
        .map((r) => r is Map ? (r['message'] ?? r.toString()) : r.toString())
        .toList();

    return EligibleSchemeModel(
      matchId: null,
      schemeId: (scheme['id'] as num?)?.toInt() ?? 0,
      schemeCode: scheme['scheme_code']?.toString() ??
          scheme['code']?.toString() ??
          '',
      schemeName: scheme['name']?.toString() ??
          scheme['scheme_name']?.toString() ??
          'Unnamed scheme',
      shortName: scheme['short_name']?.toString(),
      description: scheme['description']?.toString() ??
          scheme['benefit_description']?.toString(),
      schemeLevel: scheme['scheme_level']?.toString() ??
          scheme['level']?.toString() ??
          'National',
      schemeStatus: scheme['scheme_status']?.toString() ??
          scheme['status']?.toString() ??
          'Active',
      eligibilityStatus: outcome['eligibility_status'] as String,
      matchPercent: outcome['match_percent'] as double,
      reasonText: outcome['reason_text'] as String?,
      theme: theme,
      priority: priority,
      rules: {
        'total': outcome['rules_total'],
        'passed': outcome['rules_passed'],
        'failed': outcome['rules_failed'],
        'unknown': outcome['rules_unknown'],
      },
      passedReasons: passedReasons,
      failedReasons: failedReasons,
      unknownReasons: unknownReasons,
      missingDocuments: const [],
      benefit: benefit,
      application: application,
      sourceUrl: scheme['source_url']?.toString(),
      sourceWebsite: scheme['source_website']?.toString(),
      matchedAt: DateTime.now().toIso8601String(),
    );
  }
}
