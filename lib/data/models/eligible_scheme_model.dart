class EligibleSchemesResponse {
  final bool success;
  final String message;
  final Map<String, dynamic> beneficiary;
  final Map<String, dynamic> summary;
  final List<EligibleSchemeModel> eligibleSchemes;
  final List<EligibleSchemeModel> potentiallyEligibleSchemes;

  const EligibleSchemesResponse({
    required this.success,
    required this.message,
    required this.beneficiary,
    required this.summary,
    required this.eligibleSchemes,
    required this.potentiallyEligibleSchemes,
  });

  factory EligibleSchemesResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    Map<String, dynamic> data = {};
    List<dynamic> eligibleRaw = [];
    List<dynamic> potentialRaw = [];
    List<dynamic> allSchemesRaw = [];

    if (json['data'] is Map) {
      data = Map<String, dynamic>.from(json['data'] as Map);
      eligibleRaw = _asList(data['eligible_schemes']);
      potentialRaw = _asList(data['potentially_eligible_schemes']);
      allSchemesRaw = _asList(data['schemes']);
    } else if (json['data'] is List) {
      // If data is directly an array of schemes
      eligibleRaw = _asList(json['data']);
    }

    List<EligibleSchemeModel> parseSchemes(
        List<dynamic> items, {
          String defaultStatus = 'Eligible',
        }) {
      return items
          .whereType<Map>()
          .map(
            (item) => EligibleSchemeModel.fromJson(
          Map<String, dynamic>.from(item),
          defaultStatus: defaultStatus,
        ),
      )
          .toList();
    }

    final List<EligibleSchemeModel> allModels = [];
    allModels.addAll(parseSchemes(eligibleRaw, defaultStatus: 'Eligible'));
    allModels.addAll(parseSchemes(potentialRaw, defaultStatus: 'Potentially Eligible'));
    if (allModels.isEmpty && allSchemesRaw.isNotEmpty) {
      allModels.addAll(parseSchemes(allSchemesRaw, defaultStatus: 'Eligible'));
    }

    // Strictly separate Eligible vs Potentially Eligible / Needs Verification
    final eligibleList = allModels
        .where((s) => s.eligibilityStatus.trim().toLowerCase() == 'eligible')
        .toList();
    final potentialList = allModels
        .where((s) => s.eligibilityStatus.trim().toLowerCase() != 'eligible')
        .toList();

    final summaryMap = _asMap(data['summary']);
    summaryMap['eligible_count'] = eligibleList.length;
    summaryMap['potential_count'] = potentialList.length;
    if (summaryMap['total_evaluated'] == null ||
        (summaryMap['total_evaluated'] as num) == 0) {
      summaryMap['total_evaluated'] =
          eligibleList.length + potentialList.length;
    }

    return EligibleSchemesResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      beneficiary: _asMap(data['beneficiary']).isNotEmpty
          ? _asMap(data['beneficiary'])
          : _asMap(json['beneficiary']),
      summary: summaryMap,
      eligibleSchemes: eligibleList,
      potentiallyEligibleSchemes: potentialList,
    );
  }
}

class EligibleSchemeModel {
  final int? matchId;
  final int? schemeId;
  final String schemeCode;
  final String schemeName;
  final String? shortName;
  final String? description;
  final String? schemeLevel;
  final String? schemeStatus;
  final String eligibilityStatus;
  final double matchPercent;
  final String? reasonText;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> priority;
  final Map<String, dynamic> rules;
  final List<dynamic> passedReasons;
  final List<dynamic> failedReasons;
  final List<dynamic> unknownReasons;
  final List<String> missingDocuments;
  final Map<String, dynamic> benefit;
  final Map<String, dynamic> application;
  final String? sourceUrl;
  final String? sourceWebsite;
  final String? matchedAt;

  const EligibleSchemeModel({
    this.matchId,
    this.schemeId,
    required this.schemeCode,
    required this.schemeName,
    this.shortName,
    this.description,
    this.schemeLevel,
    this.schemeStatus,
    required this.eligibilityStatus,
    required this.matchPercent,
    this.reasonText,
    this.theme = const {},
    this.priority = const {},
    this.rules = const {},
    this.passedReasons = const [],
    this.failedReasons = const [],
    this.unknownReasons = const [],
    this.missingDocuments = const [],
    this.benefit = const {},
    this.application = const {},
    this.sourceUrl,
    this.sourceWebsite,
    this.matchedAt,
  });

  factory EligibleSchemeModel.fromJson(
      Map<String, dynamic> json, {
        String defaultStatus = 'Eligible',
      }) {
    final rawPercent = json['match_percent'];

    // Map application configuration supporting nested application object and root fields
    final appMap = _asMap(json['application']);
    if (json['application_mode'] != null && !appMap.containsKey('mode')) {
      appMap['mode'] = json['application_mode'];
    }
    if (json['portal_url'] != null && !appMap.containsKey('portal_url')) {
      appMap['portal_url'] = json['portal_url'];
    }
    if (json['source_url'] != null && !appMap.containsKey('source_url')) {
      appMap['source_url'] = json['source_url'];
    }
    if (json['source_website'] != null && !appMap.containsKey('source_website')) {
      appMap['source_website'] = json['source_website'];
    }

    // Map benefit configuration supporting nested benefit object and benefit_summary
    final benefitMap = _asMap(json['benefit']);
    if (json['benefit_summary'] != null && !benefitMap.containsKey('description')) {
      benefitMap['description'] = json['benefit_summary'];
    }

    // Map theme configuration supporting nested theme and department_name
    final themeMap = _asMap(json['theme']);
    if (json['department_name'] != null && !themeMap.containsKey('name')) {
      themeMap['name'] = json['department_name'];
    }

    // Map documents from missing_documents or required_documents checklist
    final rawDocs = _asList(
      json['missing_documents'] != null && _asList(json['missing_documents']).isNotEmpty
          ? json['missing_documents']
          : json['required_documents'],
    );

    final documentList = rawDocs.map((item) {
      if (item is Map) {
        return (item['name'] ?? item['document_name'] ?? item['title'] ?? item['code'] ?? '').toString();
      }
      return item.toString();
    }).where((s) => s.trim().isNotEmpty).toList();

    final statusString = _toNullableString(json['eligibility_status']);

    return EligibleSchemeModel(
      matchId: _toInt(json['match_id']),
      schemeId: _toInt(json['scheme_id'] ?? json['id']),
      schemeCode: json['scheme_code']?.toString() ?? json['code']?.toString() ?? '',
      schemeName: json['scheme_name']?.toString() ?? json['name']?.toString() ?? 'Unnamed scheme',
      shortName: _toNullableString(json['short_name']),
      description: _toNullableString(json['description'] ?? json['benefit_summary']),
      schemeLevel: _toNullableString(json['scheme_level']),
      schemeStatus: _toNullableString(json['scheme_status']),
      eligibilityStatus: statusString ?? defaultStatus,
      matchPercent: rawPercent is num
          ? rawPercent.toDouble()
          : double.tryParse(rawPercent?.toString() ?? '') ?? 100.0,
      reasonText: _toNullableString(json['reason_text'] ?? json['benefit_summary']),
      theme: themeMap,
      priority: _asMap(json['priority']),
      rules: _asMap(json['rules']),
      passedReasons: _asList(json['passed_reasons']),
      failedReasons: _asList(json['failed_reasons']),
      unknownReasons: _asList(json['unknown_reasons']),
      missingDocuments: documentList,
      benefit: benefitMap,
      application: appMap,
      sourceUrl: _toNullableString(json['source_url'] ?? appMap['source_url']),
      sourceWebsite: _toNullableString(json['source_website'] ?? appMap['source_website']),
      matchedAt: _toNullableString(json['matched_at']),
    );
  }

  // Application information helpers.

  String? get applicationMode =>
      _toNullableString(application['mode']);

  String? get applicationProcess =>
      _toNullableString(application['process']);

  String? get portalUrl =>
      _toNullableString(application['portal_url']);

  String? get applicationSourceUrl =>
      _toNullableString(application['source_url']);

  String? get applicationSourceWebsite =>
      _toNullableString(application['source_website']);

  String? get helplineNumber =>
      _toNullableString(application['helpline_number']);

  String? get benefitDescription =>
      _toNullableString(benefit['description'] ?? description);

  String? get benefitType =>
      _toNullableString(benefit['type']);

  String? get themeName =>
      _toNullableString(theme['name']);

  String? get themeColor =>
      _toNullableString(theme['color']);

  // Prefer the application source URL, then the scheme-level source.
  String? get officialWebsiteUrl =>
      _firstNonEmpty([applicationSourceUrl, sourceUrl]);

  // Never assume a source website is an application portal.
  String? get actionUrl {
    final mode = (applicationMode ?? '').trim().toLowerCase();

    if (mode == 'online') {
      final portal = _validHttpUrl(portalUrl);
      if (portal != null) return portal;
    }

    return _validHttpUrl(officialWebsiteUrl);
  }

  String? get actionLabel {
    final mode = (applicationMode ?? '').trim().toLowerCase();
    final portal = _validHttpUrl(portalUrl);

    if (mode == 'online' && portal != null) {
      return 'Apply Online';
    }

    if (_validHttpUrl(officialWebsiteUrl) != null) {
      return 'Visit Official Website';
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'match_id': matchId,
      'scheme_id': schemeId,
      'scheme_code': schemeCode,
      'scheme_name': schemeName,
      'short_name': shortName,
      'description': description,
      'scheme_level': schemeLevel,
      'scheme_status': schemeStatus,
      'eligibility_status': eligibilityStatus,
      'match_percent': matchPercent,
      'reason_text': reasonText,
      'theme': theme,
      'priority': priority,
      'rules': rules,
      'passed_reasons': passedReasons,
      'failed_reasons': failedReasons,
      'unknown_reasons': unknownReasons,
      'missing_documents': missingDocuments,
      'benefit': benefit,
      'application': application,
      'source_url': sourceUrl,
      'source_website': sourceWebsite,
      'matched_at': matchedAt,
    };
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : <dynamic>[];
}

int? _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _toNullableString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String? _validHttpUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final uri = Uri.tryParse(value.trim());

  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    return null;
  }

  return uri.toString();
}
