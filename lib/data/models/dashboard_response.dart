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
    int readCount(String key) {
      final value = json[key];

      if (value is int) return value;
      if (value is num) return value.toInt();

      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return DashboardSummary(
      beneficiariesRegistered:
      readCount('beneficiaries_registered'),
      applicationsSubmitted:
      readCount('applications_submitted'),
      applicationsApproved:
      readCount('applications_approved'),
      followupsDone: readCount('followups_done'),
    );
  }
}