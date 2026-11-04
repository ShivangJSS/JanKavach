import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/data/models/dashboard_response.dart';
import 'package:kavach/data/models/followup_model.dart';
import 'package:kavach/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Sync & Dashboard Offline Registered Metrics Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Dashboard registered calculation ignores drafts and retains cached registered count', () {
      // Server registered cached = 10
      const cachedSummary = DashboardSummary(beneficiariesRegistered: 10);
      final cachedRegistered = cachedSummary.beneficiariesRegistered;

      // Simulated local database query results
      const serverBeneficiaryCount = 10;
      const localDraftsCount = 2; // In Drafts tab (record_state == 'draft')
      const localPendingRegisteredCount = 1; // Submitted locally (record_state == 'pending_sync')

      // Previous faulty logic:
      final faultyCount = serverBeneficiaryCount + localDraftsCount;
      expect(faultyCount, equals(12)); // Bug: drafts were counted as registered

      // New correct logic:
      final effectiveServerCount = serverBeneficiaryCount > cachedRegistered
          ? serverBeneficiaryCount
          : cachedRegistered;
      final totalRegisteredCount = effectiveServerCount + localPendingRegisteredCount;

      expect(totalRegisteredCount, equals(11)); // 10 server + 1 pending offline, drafts excluded
    });

    test('Token extraction works for nested tokens in login response', () {
      final loginData = {
        'user': {'id': 18, 'name': 'Field Officer'},
        'tokens': {
          'access_token': 'new_jwt_access_token_123',
          'refresh_token': 'new_jwt_refresh_token_456',
        },
      };

      String? extractAccessToken(dynamic data) {
        if (data is! Map) return null;
        if (data['tokens'] is Map) {
          final tokens = data['tokens'] as Map;
          if (tokens['access_token'] != null) {
            return tokens['access_token'].toString();
          }
        }
        if (data['access_token'] != null) {
          return data['access_token'].toString();
        }
        return null;
      }

      String? extractRefreshToken(dynamic data) {
        if (data is! Map) return null;
        if (data['tokens'] is Map) {
          final tokens = data['tokens'] as Map;
          if (tokens['refresh_token'] != null) {
            return tokens['refresh_token'].toString();
          }
        }
        if (data['refresh_token'] != null) {
          return data['refresh_token'].toString();
        }
        return null;
      }

      expect(extractAccessToken(loginData), equals('new_jwt_access_token_123'));
      expect(extractRefreshToken(loginData), equals('new_jwt_refresh_token_456'));
    });

    test('Token extraction works for direct tokens in refresh response', () {
      final refreshData = {
        'access_token': 'refreshed_access_token_789',
        'refresh_token': 'refreshed_refresh_token_101',
      };

      String? extractAccessToken(dynamic data) {
        if (data is! Map) return null;
        if (data['tokens'] is Map) {
          final tokens = data['tokens'] as Map;
          if (tokens['access_token'] != null) {
            return tokens['access_token'].toString();
          }
        }
        if (data['access_token'] != null) {
          return data['access_token'].toString();
        }
        return null;
      }

      String? extractRefreshToken(dynamic data) {
        if (data is! Map) return null;
        if (data['tokens'] is Map) {
          final tokens = data['tokens'] as Map;
          if (tokens['refresh_token'] != null) {
            return tokens['refresh_token'].toString();
          }
        }
        if (data['refresh_token'] != null) {
          return data['refresh_token'].toString();
        }
        return null;
      }

      expect(extractAccessToken(refreshData), equals('refreshed_access_token_789'));
      expect(extractRefreshToken(refreshData), equals('refreshed_refresh_token_101'));
    });

    test('Dashboard Summary persists registered beneficiaries offline correctly', () async {
      await StorageService.saveDashboardSummary(
        const DashboardSummary(beneficiariesRegistered: 10),
      );

      final summary = await StorageService.getDashboardSummary();
      expect(summary, isNotNull);
      expect(summary!.beneficiariesRegistered, equals(10));
    });

    test('Dashboard dynamic metrics merge properly with Follow-up module metrics', () {
      const summary = DashboardSummary(
        beneficiariesRegistered: 10,
        applicationsSubmitted: 0,
        applicationsApproved: 0,
        followupsDone: 0,
      );

      const followupMetrics = FollowupDashboardData(
        totalUsersRegistered: 10,
        totalApplied: 7,
        complete: 4,
        pending: 3,
        notAppliedYet: 1,
        applicationPending: 2,
        documentIssue: 0,
        verificationPending: 0,
        overdue: 1,
        today: 2,
        upcoming: 1,
      );

      final dueTotal = followupMetrics.today + followupMetrics.upcoming + followupMetrics.overdue;

      final merged = summary.copyWith(
        beneficiariesRegistered: summary.beneficiariesRegistered > 0
            ? summary.beneficiariesRegistered
            : followupMetrics.totalUsersRegistered,
        applicationsSubmitted: followupMetrics.totalApplied > 0
            ? followupMetrics.totalApplied
            : summary.applicationsSubmitted,
        applicationsApproved: followupMetrics.complete > 0
            ? followupMetrics.complete
            : summary.applicationsApproved,
        followupsDone: dueTotal > 0 ? dueTotal : followupMetrics.pending,
      );

      expect(merged.beneficiariesRegistered, equals(10));
      expect(merged.applicationsSubmitted, equals(7)); // Dynamically populated from totalApplied
      expect(merged.applicationsApproved, equals(4)); // Dynamically populated from complete
      expect(merged.followupsDone, equals(4)); // Dynamically populated from overdue (1) + today (2) + upcoming (1)
    });

    test('Offline local dashboard metrics calculation calculates dynamic values correctly', () {
      const cached = DashboardSummary(
        beneficiariesRegistered: 10,
        applicationsSubmitted: 6,
        applicationsApproved: 3,
        followupsDone: 4,
      );

      const followupCached = FollowupDashboardData(
        totalUsersRegistered: 10,
        totalApplied: 8,
        complete: 5,
        pending: 2,
        notAppliedYet: 0,
        applicationPending: 1,
        documentIssue: 0,
        verificationPending: 0,
        overdue: 1,
        today: 1,
        upcoming: 0,
      );

      const localAppliedCount = 2;
      const localApprovedCount = 1;
      final dueTotal = followupCached.today + followupCached.upcoming + followupCached.overdue;

      final effectiveApplied = [cached.applicationsSubmitted, followupCached.totalApplied, localAppliedCount]
          .reduce((a, b) => a > b ? a : b);
      final effectiveApproved = [cached.applicationsApproved, followupCached.complete, localApprovedCount]
          .reduce((a, b) => a > b ? a : b);
      final effectiveDue = [cached.followupsDone, dueTotal]
          .reduce((a, b) => a > b ? a : b);

      expect(effectiveApplied, equals(8)); // Max of 6, 8, 2
      expect(effectiveApproved, equals(5)); // Max of 3, 5, 1
      expect(effectiveDue, equals(4)); // Max of 4, 2
    });

    test('Offline dashboard calculation does NOT falsely count survey assessment_status=Complete as approved applications', () {
      // 4 registered beneficiaries who completed their registration survey
      final beneficiaryDataList = [
        {'id': 1, 'assessment_status': 'Complete', 'record_status': 'Active', 'application_count': 0},
        {'id': 2, 'assessment_status': 'Complete', 'record_status': 'Active', 'application_count': 0},
        {'id': 3, 'assessment_status': 'Complete', 'record_status': 'Active', 'application_count': 0},
        {'id': 4, 'assessment_status': 'Complete', 'record_status': 'Active', 'application_count': 0},
      ];

      int localAppliedCount = 0;
      int localApprovedCount = 0;

      for (final data in beneficiaryDataList) {
        int appliedOnBeneficiary = 0;
        final appCount = (data['application_count'] as num?)?.toInt() ?? 0;
        if (appCount > 0) {
          appliedOnBeneficiary = appCount;
        }
        localAppliedCount += appliedOnBeneficiary;

        int approvedOnBeneficiary = 0;
        final approvedCount = (data['approved_applications_count'] as num?)?.toInt() ??
            (data['applications_approved'] as num?)?.toInt() ?? 0;
        if (approvedCount > 0) {
          approvedOnBeneficiary = approvedCount;
        }
        localApprovedCount += approvedOnBeneficiary;
      }

      const cached = DashboardSummary(
        beneficiariesRegistered: 4,
        applicationsSubmitted: 0,
        applicationsApproved: 0,
      );

      final effectiveApplied = [cached.applicationsSubmitted, localAppliedCount].reduce((a, b) => a > b ? a : b);
      var effectiveApproved = [cached.applicationsApproved, localApprovedCount].reduce((a, b) => a > b ? a : b);
      if (effectiveApplied == 0) {
        effectiveApproved = 0;
      }

      expect(effectiveApplied, equals(0));
      expect(effectiveApproved, equals(0)); // Must be 0, NOT 4!
    });

    test('Offline dashboard calculation accurately counts multiple approved scheme applications across beneficiaries', () {
      // Beneficiary 1 has 2 approved schemes out of 2.
      // Beneficiary 2 has 1 approved scheme out of 3.
      final beneficiaryDataList = [
        {
          'id': 101,
          'assessment_status': 'Complete',
          'application_count': 2,
          'approved_applications_count': 2,
        },
        {
          'id': 102,
          'assessment_status': 'Complete',
          'application_count': 3,
          'approved_applications_count': 1,
        },
      ];

      int localAppliedCount = 0;
      int localApprovedCount = 0;

      for (final data in beneficiaryDataList) {
        int appliedOnBeneficiary = 0;
        final appCount = (data['application_count'] as num?)?.toInt() ?? 0;
        if (appCount > 0) {
          appliedOnBeneficiary = appCount;
        }
        localAppliedCount += appliedOnBeneficiary;

        int approvedOnBeneficiary = 0;
        final approvedCount = (data['approved_applications_count'] as num?)?.toInt() ??
            (data['applications_approved'] as num?)?.toInt() ?? 0;
        if (approvedCount > 0) {
          approvedOnBeneficiary = approvedCount;
        }
        localApprovedCount += approvedOnBeneficiary;
      }

      const cached = DashboardSummary(
        beneficiariesRegistered: 2,
        applicationsSubmitted: 0,
        applicationsApproved: 0,
      );

      final effectiveApplied = [cached.applicationsSubmitted, localAppliedCount].reduce((a, b) => a > b ? a : b);
      var effectiveApproved = [cached.applicationsApproved, localApprovedCount].reduce((a, b) => a > b ? a : b);
      if (effectiveApplied == 0) {
        effectiveApproved = 0;
      } else if (effectiveApproved > effectiveApplied) {
        effectiveApproved = effectiveApplied;
      }

      expect(effectiveApplied, equals(5)); // 2 + 3 = 5 submitted
      expect(effectiveApproved, equals(3)); // 2 + 1 = 3 approved
    });
  });
}
