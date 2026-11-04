// Data models for the Jan Kavach Mobile Scheme Follow-up Module.

class FollowupDashboardData {
  final int totalUsersRegistered;
  final int totalApplied;
  final int pending;
  final int complete;

  final int notAppliedYet;
  final int applicationPending;
  final int documentIssue;
  final int verificationPending;

  final int overdue;
  final int today;
  final int upcoming;

  const FollowupDashboardData({
    required this.totalUsersRegistered,
    required this.totalApplied,
    required this.pending,
    required this.complete,
    required this.notAppliedYet,
    required this.applicationPending,
    required this.documentIssue,
    required this.verificationPending,
    required this.overdue,
    required this.today,
    required this.upcoming,
  });

  factory FollowupDashboardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary_cards'] as Map<String, dynamic>? ?? {};
    final breakdown = json['pending_breakdown'] as Map<String, dynamic>? ?? {};
    final due = json['followup_due'] as Map<String, dynamic>? ?? {};

    return FollowupDashboardData(
      totalUsersRegistered: summary['total_users_registered'] as int? ?? 0,
      totalApplied: summary['total_applied'] as int? ?? 0,
      pending: summary['pending'] as int? ?? 0,
      complete: summary['complete'] as int? ?? 0,
      notAppliedYet: breakdown['not_applied_yet'] as int? ?? 0,
      applicationPending: breakdown['application_pending'] as int? ?? 0,
      documentIssue: breakdown['document_issue'] as int? ?? 0,
      verificationPending: breakdown['verification_pending'] as int? ?? 0,
      overdue: due['overdue'] as int? ?? 0,
      today: due['today'] as int? ?? 0,
      upcoming: due['upcoming'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary_cards': {
        'total_users_registered': totalUsersRegistered,
        'total_applied': totalApplied,
        'pending': pending,
        'complete': complete,
      },
      'pending_breakdown': {
        'not_applied_yet': notAppliedYet,
        'application_pending': applicationPending,
        'document_issue': documentIssue,
        'verification_pending': verificationPending,
      },
      'followup_due': {
        'overdue': overdue,
        'today': today,
        'upcoming': upcoming,
      },
    };
  }
}

class FollowupRegisterItem {
  final int? followupId;
  final int beneficiaryId;
  final String beneficiaryCode;
  final String beneficiaryName;
  final String? mobile;
  final String? gender;
  final int? age;
  final String? village;

  final int schemeId;
  final String schemeCode;
  final String schemeName;
  final String? applicationMode;

  final String? eligibilityStatus;
  final String status; // 'Pending', 'Applied', 'Complete'
  final String? pendingReason;
  final String? documentIssue;
  final String? applicationNumber;
  final String? submissionDate;
  final String? benefitReceivedDate;
  final String? nextFollowupDate;
  final String? notes;
  final String? lastUpdatedAt;
  final String? lastUpdatedBy;

  const FollowupRegisterItem({
    this.followupId,
    required this.beneficiaryId,
    required this.beneficiaryCode,
    required this.beneficiaryName,
    this.mobile,
    this.gender,
    this.age,
    this.village,
    required this.schemeId,
    required this.schemeCode,
    required this.schemeName,
    this.applicationMode,
    this.eligibilityStatus,
    required this.status,
    this.pendingReason,
    this.documentIssue,
    this.applicationNumber,
    this.submissionDate,
    this.benefitReceivedDate,
    this.nextFollowupDate,
    this.notes,
    this.lastUpdatedAt,
    this.lastUpdatedBy,
  });

  factory FollowupRegisterItem.fromJson(Map<String, dynamic> json) {
    final b = json['beneficiary'] as Map<String, dynamic>? ?? {};
    final s = json['scheme'] as Map<String, dynamic>? ?? {};

    return FollowupRegisterItem(
      followupId: json['followup_id'] as int?,
      beneficiaryId: b['id'] as int? ?? 0,
      beneficiaryCode: b['code']?.toString() ?? '',
      beneficiaryName: b['name']?.toString() ?? 'Unnamed Beneficiary',
      mobile: b['mobile']?.toString(),
      gender: b['gender']?.toString(),
      age: b['age'] as int?,
      village: b['village']?.toString(),
      schemeId: s['id'] as int? ?? 0,
      schemeCode: s['code']?.toString() ?? '',
      schemeName: s['name']?.toString() ?? 'Scheme',
      applicationMode: s['application_mode']?.toString(),
      eligibilityStatus: json['eligibility_status']?.toString(),
      status: json['status']?.toString() ?? 'Pending',
      pendingReason: json['pending_reason']?.toString(),
      documentIssue: json['document_issue'] is Map
          ? (json['document_issue'] as Map)['document_name']?.toString()
          : json['document_issue']?.toString(),
      applicationNumber: json['application_number']?.toString(),
      submissionDate: json['submission_date']?.toString(),
      benefitReceivedDate: json['benefit_received_date']?.toString(),
      nextFollowupDate: json['next_followup_date']?.toString(),
      notes: json['notes']?.toString(),
      lastUpdatedAt: json['last_updated_at']?.toString(),
      lastUpdatedBy: json['last_updated_by']?.toString(),
    );
  }
}

class FollowupRegisterResponse {
  final List<FollowupRegisterItem> items;
  final int currentPage;
  final int totalItems;
  final int totalPages;

  const FollowupRegisterResponse({
    required this.items,
    required this.currentPage,
    required this.totalItems,
    required this.totalPages,
  });

  factory FollowupRegisterResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final rawItems = (data['items'] as List<dynamic>?) ??
        (json['items'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        [];
    final pagination = (data['pagination'] as Map<String, dynamic>?) ?? {};
    final meta = (data['meta'] as Map<String, dynamic>?) ??
        (json['meta'] as Map<String, dynamic>?) ??
        {};

    final page = (meta['page'] as num?)?.toInt() ??
        (pagination['page'] as num?)?.toInt() ??
        (meta['current_page'] as num?)?.toInt() ??
        (pagination['current_page'] as num?)?.toInt() ??
        1;

    final total = (meta['total'] as num?)?.toInt() ??
        (pagination['total'] as num?)?.toInt() ??
        (pagination['total_items'] as num?)?.toInt() ??
        (data['total'] as num?)?.toInt() ??
        rawItems.length;

    final totalPages = (meta['last_page'] as num?)?.toInt() ??
        (pagination['total_pages'] as num?)?.toInt() ??
        (meta['total_pages'] as num?)?.toInt() ??
        1;

    return FollowupRegisterResponse(
      items: rawItems
          .map((e) => FollowupRegisterItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: page,
      totalItems: total,
      totalPages: totalPages,
    );
  }
}

class FollowupDocumentType {
  final int id;
  final String documentName;
  final String documentCode;
  final String? category;

  const FollowupDocumentType({
    required this.id,
    required this.documentName,
    required this.documentCode,
    this.category,
  });

  factory FollowupDocumentType.fromJson(Map<String, dynamic> json) {
    return FollowupDocumentType(
      id: json['id'] as int? ?? json['document_type_id'] as int? ?? 0,
      documentName: (json['document_name'] ??
              json['name'] ??
              json['doc_name'] ??
              json['title'])
          ?.toString() ??
          'Document',
      documentCode: (json['document_code'] ?? json['code'])?.toString() ?? '',
      category: json['category']?.toString(),
    );
  }
}

class RequiredDocumentItem {
  final int id;
  final String name;
  final String code;
  final bool isMandatory;

  const RequiredDocumentItem({
    required this.id,
    required this.name,
    required this.code,
    required this.isMandatory,
  });

  factory RequiredDocumentItem.fromJson(Map<String, dynamic> json) {
    return RequiredDocumentItem(
      id: json['document_type_id'] as int? ?? json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? json['document_name']?.toString() ?? '',
      code: json['code']?.toString() ?? json['document_code']?.toString() ?? '',
      isMandatory: json['is_mandatory'] == true || json['is_mandatory'] == 1,
    );
  }
}

class SchemeFollowupDetail {
  final int? id;
  final String status; // 'Pending', 'Applied', 'Complete'
  final String? pendingReason;
  final String? documentIssueName;
  final String? documentIssueType;
  final String? documentNotes;
  final String? applicationNumber;
  final String? submissionDate;
  final String? benefitReceivedDate;
  final String? nextFollowupDate;
  final String? notes;
  final String? lastUpdatedAt;
  final String? lastUpdatedBy;

  const SchemeFollowupDetail({
    this.id,
    required this.status,
    this.pendingReason,
    this.documentIssueName,
    this.documentIssueType,
    this.documentNotes,
    this.applicationNumber,
    this.submissionDate,
    this.benefitReceivedDate,
    this.nextFollowupDate,
    this.notes,
    this.lastUpdatedAt,
    this.lastUpdatedBy,
  });

  factory SchemeFollowupDetail.fromJson(Map<String, dynamic> json) {
    final docIssue = json['document_issue'];
    String? docName;
    String? docIssueType;
    String? docNotes;

    if (docIssue is Map) {
      docName = (docIssue['document_name'] ?? docIssue['name'])?.toString();
      docIssueType = docIssue['issue_type']?.toString();
      docNotes = (docIssue['notes'] ?? docIssue['description'])?.toString();
    } else if (docIssue != null) {
      docName = docIssue.toString();
    }

    return SchemeFollowupDetail(
      id: (json['id'] ?? json['followup_id']) as int?,
      status: json['status']?.toString() ?? 'Pending',
      pendingReason: json['pending_reason']?.toString(),
      documentIssueName: docName,
      documentIssueType: docIssueType,
      documentNotes: docNotes,
      applicationNumber: json['application_number']?.toString(),
      submissionDate: json['submission_date']?.toString(),
      benefitReceivedDate: json['benefit_received_date']?.toString(),
      nextFollowupDate: json['next_followup_date']?.toString(),
      notes: json['notes']?.toString(),
      lastUpdatedAt: json['last_updated_at']?.toString(),
      lastUpdatedBy: (json['last_updated_by'] ?? json['updated_by_name'] ?? json['last_updated_by_name'])?.toString(),
    );
  }
}

class BeneficiaryEligibleSchemeFollowup {
  final int schemeId;
  final String schemeCode;
  final String schemeName;
  final String? departmentName;
  final String? applicationMode;
  final String? benefitSummary;
  final List<RequiredDocumentItem> requiredDocuments;
  final SchemeFollowupDetail? followup;

  const BeneficiaryEligibleSchemeFollowup({
    required this.schemeId,
    required this.schemeCode,
    required this.schemeName,
    this.departmentName,
    this.applicationMode,
    this.benefitSummary,
    required this.requiredDocuments,
    this.followup,
  });

  factory BeneficiaryEligibleSchemeFollowup.fromJson(Map<String, dynamic> json) {
    final docs = (json['required_documents'] as List<dynamic>?) ??
        (json['documents'] as List<dynamic>?) ??
        [];
    final fu = json['tracking'] ?? json['followup'];
    final fuMap = fu is Map ? Map<String, dynamic>.from(fu) : null;

    return BeneficiaryEligibleSchemeFollowup(
      schemeId: (json['scheme_id'] ?? json['id']) as int? ?? 0,
      schemeCode: json['scheme_code']?.toString() ?? json['code']?.toString() ?? '',
      schemeName: json['scheme_name']?.toString() ?? json['name']?.toString() ?? '',
      departmentName: (json['department_name'] ?? json['department'])?.toString(),
      applicationMode: json['application_mode']?.toString(),
      benefitSummary: (json['benefit_summary'] ?? json['description'] ?? json['benefit_description'])?.toString(),
      requiredDocuments: docs
          .map((e) => RequiredDocumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      followup: fuMap != null ? SchemeFollowupDetail.fromJson(fuMap) : null,
    );
  }
}

class BeneficiaryFollowupProfile {
  final int id;
  final String beneficiaryCode;
  final String fullName;
  final String? mobileNumber;
  final String? gender;
  final int? age;
  final String? villageName;
  final String? districtName;
  final String? blockName;
  final List<BeneficiaryEligibleSchemeFollowup> eligibleSchemes;

  const BeneficiaryFollowupProfile({
    required this.id,
    required this.beneficiaryCode,
    required this.fullName,
    this.mobileNumber,
    this.gender,
    this.age,
    this.villageName,
    this.districtName,
    this.blockName,
    required this.eligibleSchemes,
  });

  factory BeneficiaryFollowupProfile.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final b = data['beneficiary'] as Map<String, dynamic>? ?? data;
    final schemes = (data['eligible_schemes'] as List<dynamic>?) ??
        (data['schemes'] as List<dynamic>?) ??
        [];

    final name = (b['name'] ?? b['full_name'] ?? b['beneficiary_name'])?.toString();

    return BeneficiaryFollowupProfile(
      id: (b['id'] ?? b['beneficiary_id']) as int? ?? 0,
      beneficiaryCode: (b['beneficiary_code'] ?? b['code'])?.toString() ?? '',
      fullName: (name != null && name.trim().isNotEmpty) ? name.trim() : 'Unnamed Beneficiary',
      mobileNumber: (b['mobile'] ?? b['mobile_number'] ?? b['phone'])?.toString(),
      gender: b['gender']?.toString(),
      age: (b['age'] as num?)?.toInt(),
      villageName: (b['village_name'] ?? b['village'])?.toString(),
      districtName: (b['district_name'] ?? b['district'])?.toString(),
      blockName: (b['block_name'] ?? b['block'])?.toString(),
      eligibleSchemes: schemes
          .map((e) => BeneficiaryEligibleSchemeFollowup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RecordFollowupPayload {
  final int beneficiaryId;
  final int schemeId;
  final String status; // 'Pending', 'Applied', 'Complete'
  final String? pendingReason; // 'Not applied yet', 'Document issue', 'Application pending', 'Verification pending'
  final int? documentTypeId;
  final String? issueType; // 'Missing', 'Expired', 'Invalid'
  final String? documentNotes;
  final String? applicationNumber;
  final String? submissionDate;
  final String? benefitReceivedDate;
  final String? nextFollowupDate;
  final String? notes;

  const RecordFollowupPayload({
    required this.beneficiaryId,
    required this.schemeId,
    required this.status,
    this.pendingReason,
    this.documentTypeId,
    this.issueType,
    this.documentNotes,
    this.applicationNumber,
    this.submissionDate,
    this.benefitReceivedDate,
    this.nextFollowupDate,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'beneficiary_id': beneficiaryId,
      'scheme_id': schemeId,
      'status': status,
    };

    if (pendingReason != null) map['pending_reason'] = pendingReason;
    if (documentTypeId != null) map['document_type_id'] = documentTypeId;
    if (issueType != null) map['issue_type'] = issueType;
    if (documentNotes != null && documentNotes!.isNotEmpty) {
      map['document_notes'] = documentNotes;
    }
    if (applicationNumber != null && applicationNumber!.isNotEmpty) {
      map['application_number'] = applicationNumber;
    }
    if (submissionDate != null && submissionDate!.isNotEmpty) {
      map['submission_date'] = submissionDate;
    }
    if (benefitReceivedDate != null && benefitReceivedDate!.isNotEmpty) {
      map['benefit_received_date'] = benefitReceivedDate;
    }
    if (nextFollowupDate != null && nextFollowupDate!.isNotEmpty) {
      map['next_followup_date'] = nextFollowupDate;
    }
    if (notes != null && notes!.isNotEmpty) {
      map['notes'] = notes;
    }

    return map;
  }
}
