
class SchemeModel {
  final int id;
  final String code;
  final String name;
  final String? shortName;
  final String? description;
  final String level;
  final String? stateName;
  final String status;
  final bool activeEnrollment;
  final String? themeName;
  final String? themeColor;
  final String? targetGroupSummary;
  final String? eligibilitySummary;
  final String? benefitType;
  final String? benefitDescription;
  final num? benefitAmount;
  final String? benefitAmountText;
  final String? applicationMode;
  final String? portalUrl;
  final String? applicationUrl;
  final String? sourceUrl;

  const SchemeModel({
    required this.id,
    required this.code,
    required this.name,
    this.shortName,
    this.description,
    required this.level,
    this.stateName,
    required this.status,
    required this.activeEnrollment,
    this.themeName,
    this.themeColor,
    this.targetGroupSummary,
    this.eligibilitySummary,
    this.benefitType,
    this.benefitDescription,
    this.benefitAmount,
    this.benefitAmountText,
    this.applicationMode,
    this.portalUrl,
    this.applicationUrl,
    this.sourceUrl,
  });

  factory SchemeModel.fromJson(Map<String, dynamic> json) {
    final state = json['state'] is Map
        ? Map<String, dynamic>.from(json['state'])
        : <String, dynamic>{};

    final theme = json['theme'] is Map
        ? Map<String, dynamic>.from(json['theme'])
        : <String, dynamic>{};

    final benefit = json['benefit'] is Map
        ? Map<String, dynamic>.from(json['benefit'])
        : <String, dynamic>{};

    return SchemeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed scheme',
      shortName: json['short_name']?.toString(),
      description: json['description']?.toString(),
      level: json['level']?.toString() ?? 'National',
      stateName: state['name']?.toString(),
      status: json['status']?.toString() ?? '',
      activeEnrollment: json['active_enrollment'] == true,
      themeName: theme['name']?.toString(),
      themeColor: theme['color']?.toString(),
      targetGroupSummary: json['target_group_summary']?.toString(),
      eligibilitySummary: json['eligibility_summary']?.toString(),
      benefitType: benefit['type']?.toString(),
      benefitDescription: benefit['description']?.toString(),
      benefitAmount: benefit['amount'] as num?,
      benefitAmountText: benefit['amount_text']?.toString(),
      applicationMode: json['application_mode']?.toString(),
      portalUrl: (json['portal_url'] ?? json['application_url'])?.toString(),
      applicationUrl: (json['application_url'] ?? json['portal_url'])?.toString(),
      sourceUrl: json['source_url']?.toString(),
    );
  }

  bool get isOnline {
    final mode = (applicationMode ?? '').trim().toLowerCase();
    return mode == 'online' || mode == 'both';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'short_name': shortName,
      'description': description,
      'level': level,
      'state': stateName == null
          ? null
          : {'name': stateName},
      'status': status,
      'active_enrollment': activeEnrollment,
      'theme': themeName == null && themeColor == null
          ? null
          : {
        'name': themeName,
        'color': themeColor,
      },
      'target_group_summary': targetGroupSummary,
      'eligibility_summary': eligibilitySummary,
      'benefit': {
        'type': benefitType,
        'description': benefitDescription,
        'amount': benefitAmount,
        'amount_text': benefitAmountText,
      },
      'application_mode': applicationMode,
      'portal_url': portalUrl ?? applicationUrl,
      'application_url': applicationUrl ?? portalUrl,
      'source_url': sourceUrl,
    };
  }

}
