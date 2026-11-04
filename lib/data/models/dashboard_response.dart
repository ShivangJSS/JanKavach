import 'package:flutter/foundation.dart';

@immutable
class DashboardSummary {
  final int beneficiariesRegistered;
  final int applicationsSubmitted;
  final int applicationsApproved;
  final int followupsDone;

  const DashboardSummary({
    this.beneficiariesRegistered = 0,
    this.applicationsSubmitted = 0,
    this.applicationsApproved = 0,
    this.followupsDone = 0,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'beneficiaries_registered': beneficiariesRegistered,
      'applications_submitted': applicationsSubmitted,
      'applications_approved': applicationsApproved,
      'followups_done': followupsDone,
    };
  }

  DashboardSummary copyWith({
    int? beneficiariesRegistered,
    int? applicationsSubmitted,
    int? applicationsApproved,
    int? followupsDone,
  }) {
    return DashboardSummary(
      beneficiariesRegistered:
          beneficiariesRegistered ?? this.beneficiariesRegistered,
      applicationsSubmitted:
          applicationsSubmitted ?? this.applicationsSubmitted,
      applicationsApproved:
          applicationsApproved ?? this.applicationsApproved,
      followupsDone: followupsDone ?? this.followupsDone,
    );
  }
}
