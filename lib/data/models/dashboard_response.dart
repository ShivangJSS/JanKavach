import 'package:flutter/foundation.dart';

@immutable
class DashboardSummary {
  final int beneficiariesRegistered;
  final int applicationsSubmitted;
  final int applicationsApproved;
  final int followupsDone;
  final int beneficiariesWithApproved;
  final num totalAmountDistributed;

  const DashboardSummary({
    this.beneficiariesRegistered = 0,
    this.applicationsSubmitted = 0,
    this.applicationsApproved = 0,
    this.followupsDone = 0,
    this.beneficiariesWithApproved = 0,
    this.totalAmountDistributed = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    int readCount(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value != null) {
          final parsed = int.tryParse(value.toString());
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    num readAmount(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) return value;
        if (value != null) {
          final cleaned = value
              .toString()
              .replaceAll(',', '')
              .replaceAll('\u20B9', '')
              .replaceAll('Rs.', '')
              .replaceAll('Rs', '')
              .trim();
          final parsed = num.tryParse(cleaned);
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    return DashboardSummary(
      beneficiariesRegistered: readCount([
        'beneficiaries_registered',
        'total_beneficiaries',
        'total_users_registered',
        'registered_beneficiaries',
      ]),
      applicationsSubmitted: readCount([
        'applications_submitted',
        'total_applied',
        'applied_schemes',
        'total_applications',
      ]),
      applicationsApproved: readCount([
        'applications_approved',
        'approved_applications',
        'complete',
        'completed',
        'total_complete',
      ]),
      followupsDone: readCount([
        'followups_done',
        'followups_due',
        'followup_due',
        'pending_followups',
        'pending',
        'due_followups',
      ]),
      beneficiariesWithApproved: readCount([
        'beneficiaries_with_approved',
        'beneficiaries_with_benefits',
        'approved_beneficiaries',
        'unique_beneficiaries_approved',
        'beneficiaries_approved',
        'beneficiaries_benefit_received',
      ]),
      totalAmountDistributed: readAmount([
        'total_amount_distributed',
        'amount_distributed',
        'total_amount',
        'total_distributed_amount',
        'total_benefit_amount',
        'total_benefits_distributed',
        'benefit_amount_distributed',
        'disbursed_amount',
        'total_disbursed_amount',
        'total_disbursed',
        'amount',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'beneficiaries_registered': beneficiariesRegistered,
      'applications_submitted': applicationsSubmitted,
      'applications_approved': applicationsApproved,
      'followups_done': followupsDone,
      'beneficiaries_with_approved': beneficiariesWithApproved,
      'total_amount_distributed': totalAmountDistributed,
    };
  }

  DashboardSummary copyWith({
    int? beneficiariesRegistered,
    int? applicationsSubmitted,
    int? applicationsApproved,
    int? followupsDone,
    int? beneficiariesWithApproved,
    num? totalAmountDistributed,
  }) {
    return DashboardSummary(
      beneficiariesRegistered:
          beneficiariesRegistered ?? this.beneficiariesRegistered,
      applicationsSubmitted:
          applicationsSubmitted ?? this.applicationsSubmitted,
      applicationsApproved:
          applicationsApproved ?? this.applicationsApproved,
      followupsDone: followupsDone ?? this.followupsDone,
      beneficiariesWithApproved:
          beneficiariesWithApproved ?? this.beneficiariesWithApproved,
      totalAmountDistributed:
          totalAmountDistributed ?? this.totalAmountDistributed,
    );
  }
}
