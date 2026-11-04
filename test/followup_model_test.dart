import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/followup_model.dart';
import 'package:kavach/viewModels/followup_viewmodel.dart';

void main() {
  group('Followup Module Models Test', () {
    test('FollowupDashboardData parses correctly from JSON', () {
      final json = {
        'summary_cards': {
          'total_users_registered': 12,
          'total_applied': 1,
          'pending': 17,
          'complete': 1,
        },
        'pending_breakdown': {
          'not_applied_yet': 11,
          'application_pending': 1,
          'document_issue': 2,
          'verification_pending': 3,
        },
        'followup_due': {
          'overdue': 0,
          'today': 0,
          'upcoming': 3,
        },
      };

      final data = FollowupDashboardData.fromJson(json);
      expect(data.totalUsersRegistered, 12);
      expect(data.totalApplied, 1);
      expect(data.pending, 17);
      expect(data.complete, 1);
      expect(data.documentIssue, 2);
      expect(data.upcoming, 3);
    });

    test('RecordFollowupPayload serialization generates correct API body', () {
      final payload = RecordFollowupPayload(
        beneficiaryId: 61,
        schemeId: 87,
        status: 'Pending',
        pendingReason: 'Document issue',
        documentTypeId: 4,
        issueType: 'Missing',
        documentNotes: 'Income Certificate expired',
        nextFollowupDate: '2026-10-25',
        notes: 'Advised to visit Tehsil',
      );

      final json = payload.toJson();
      expect(json['beneficiary_id'], 61);
      expect(json['scheme_id'], 87);
      expect(json['status'], 'Pending');
      expect(json['pending_reason'], 'Document issue');
      expect(json['document_type_id'], 4);
      expect(json['issue_type'], 'Missing');
      expect(json['document_notes'], 'Income Certificate expired');
      expect(json['next_followup_date'], '2026-10-25');
      expect(json['notes'], 'Advised to visit Tehsil');
    });

    test('RecordFollowupPayload serialization generates correct body for Applied status without application_number', () {
      final payload = RecordFollowupPayload(
        beneficiaryId: 61,
        schemeId: 87,
        status: 'Applied',
        submissionDate: '2026-10-29',
      );

      final json = payload.toJson();
      expect(json['beneficiary_id'], 61);
      expect(json['scheme_id'], 87);
      expect(json['status'], 'Applied');
      expect(json['submission_date'], '2026-10-29');
      expect(json.containsKey('application_number'), isFalse);
    });

    test('RecordFollowupPayload serialization generates correct body for Complete status with benefit_received_date', () {
      final payload = RecordFollowupPayload(
        beneficiaryId: 61,
        schemeId: 87,
        status: 'Complete',
        benefitReceivedDate: '2026-10-29',
        submissionDate: '2026-10-25',
      );

      final json = payload.toJson();
      expect(json['beneficiary_id'], 61);
      expect(json['scheme_id'], 87);
      expect(json['status'], 'Complete');
      expect(json['benefit_received_date'], '2026-10-29');
      expect(json['submission_date'], '2026-10-25');
    });

    test('FollowupRegisterResponse parses paginated items', () {
      final json = {
        'data': {
          'items': [
            {
              'followup_id': 101,
              'beneficiary': {
                'id': 61,
                'code': 'JK-UP-2026-000125',
                'name': 'Ramesh Kumar Sharma',
                'mobile': '9876543210',
                'village': 'Kathwara',
              },
              'scheme': {
                'id': 87,
                'code': 'NFBS',
                'name': 'National Family Benefit Scheme',
              },
              'status': 'Pending',
              'pending_reason': 'Document issue',
              'document_issue': 'Income Certificate',
              'next_followup_date': '2026-10-25',
            }
          ],
          'pagination': {
            'page': 1,
            'per_page': 20,
            'total_items': 1,
            'total_pages': 1,
          }
        }
      };

      final response = FollowupRegisterResponse.fromJson(json);
      expect(response.items.length, 1);
      expect(response.items.first.beneficiaryName, 'Ramesh Kumar Sharma');
      expect(response.items.first.schemeName, 'National Family Benefit Scheme');
      expect(response.items.first.status, 'Pending');
      expect(response.items.first.documentIssue, 'Income Certificate');
    });

    test('FollowupRegisterResponse correctly extracts meta.total from backend API structure', () {
      final backendJson = {
        'status': 'success',
        'data': {
          'items': [
            {
              'followup_id': 1,
              'beneficiary': {'id': 1, 'code': 'B1', 'name': 'User 1'},
              'scheme': {'id': 1, 'code': 'S1', 'name': 'Scheme 1'},
              'status': 'Pending',
            },
            {
              'followup_id': 2,
              'beneficiary': {'id': 2, 'code': 'B2', 'name': 'User 2'},
              'scheme': {'id': 2, 'code': 'S2', 'name': 'Scheme 2'},
              'status': 'Applied',
            }
          ],
          'meta': {
            'total': 19,
            'page': 1,
            'per_page': 20,
            'last_page': 1,
            'has_more': false,
          }
        }
      };

      final response = FollowupRegisterResponse.fromJson(backendJson);
      expect(response.totalItems, 19);
      expect(response.currentPage, 1);
      expect(response.totalPages, 1);
      expect(response.items.length, 2);
    });

    test('FollowupViewModel.matchesDueFilter correctly filters today, overdue, and upcoming', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final in3Days = now.add(const Duration(days: 3));
      final in3DaysStr = '${in3Days.year}-${in3Days.month.toString().padLeft(2, '0')}-${in3Days.day.toString().padLeft(2, '0')}';
      final in20Days = now.add(const Duration(days: 20));
      final in20DaysStr = '${in20Days.year}-${in20Days.month.toString().padLeft(2, '0')}-${in20Days.day.toString().padLeft(2, '0')}';

      // Due Today
      expect(FollowupViewModel.matchesDueFilter(todayStr, 'today', status: 'Pending'), isTrue);
      expect(FollowupViewModel.matchesDueFilter(yesterdayStr, 'today', status: 'Pending'), isFalse);
      expect(FollowupViewModel.matchesDueFilter(in3DaysStr, 'today', status: 'Pending'), isFalse);
      expect(FollowupViewModel.matchesDueFilter(todayStr, 'today', status: 'Complete'), isFalse);
      expect(FollowupViewModel.matchesDueFilter(null, 'today'), isFalse);

      // Overdue
      expect(FollowupViewModel.matchesDueFilter(yesterdayStr, 'overdue', status: 'Pending'), isTrue);
      expect(FollowupViewModel.matchesDueFilter(todayStr, 'overdue', status: 'Pending'), isFalse);
      expect(FollowupViewModel.matchesDueFilter(in3DaysStr, 'overdue', status: 'Pending'), isFalse);
      expect(FollowupViewModel.matchesDueFilter(yesterdayStr, 'overdue', status: 'Complete'), isFalse);

      // Upcoming (within 7 days)
      expect(FollowupViewModel.matchesDueFilter(in3DaysStr, 'upcoming', status: 'Pending'), isTrue);
      expect(FollowupViewModel.matchesDueFilter(todayStr, 'upcoming', status: 'Pending'), isFalse);
      expect(FollowupViewModel.matchesDueFilter(in20DaysStr, 'upcoming', status: 'Pending'), isFalse);
      expect(FollowupViewModel.matchesDueFilter(in3DaysStr, 'upcoming', status: 'Complete'), isFalse);

      // All Due
      expect(FollowupViewModel.matchesDueFilter(todayStr, 'all'), isTrue);
      expect(FollowupViewModel.matchesDueFilter(yesterdayStr, 'all'), isTrue);
      expect(FollowupViewModel.matchesDueFilter(null, 'all'), isTrue);
    });

    test('BeneficiaryFollowupProfile parses backend response with name and tracking status', () {
      final backendJson = {
        'status': 'success',
        'data': {
          'beneficiary': {
            'id': 187,
            'beneficiary_code': 'JK-UP-2026-000187',
            'name': 'rima',
            'gender': 'Female',
            'age': 25,
            'village_name': 'Harhua Para',
          },
          'eligible_schemes': [
            {
              'scheme_id': 8,
              'scheme_code': 'JK-SCH-0008',
              'scheme_name': 'Women Helpline Number 181 scheme',
              'tracking': {
                'followup_id': 10,
                'status': 'Complete',
                'benefit_received_date': '2026-10-29',
              },
              'required_documents': [],
            },
            {
              'scheme_id': 16,
              'scheme_code': 'JK-SCH-0016',
              'scheme_name': "NALSA's Compensation Scheme",
              'tracking': {
                'followup_id': 11,
                'status': 'Applied',
                'submission_date': '2026-10-29',
              },
              'required_documents': [],
            }
          ]
        }
      };

      final profile = BeneficiaryFollowupProfile.fromJson(backendJson);
      expect(profile.id, 187);
      expect(profile.beneficiaryCode, 'JK-UP-2026-000187');
      expect(profile.fullName, 'rima');
      expect(profile.age, 25);
      expect(profile.villageName, 'Harhua Para');
      expect(profile.eligibleSchemes.length, 2);

      // Verify Scheme 1 (Women Helpline 181) tracking status
      final scheme1 = profile.eligibleSchemes[0];
      expect(scheme1.schemeId, 8);
      expect(scheme1.schemeCode, 'JK-SCH-0008');
      expect(scheme1.followup, isNotNull);
      expect(scheme1.followup!.status, 'Complete');
      expect(scheme1.followup!.benefitReceivedDate, '2026-10-29');

      // Verify Scheme 2 (NALSA) tracking status
      final scheme2 = profile.eligibleSchemes[1];
      expect(scheme2.schemeId, 16);
      expect(scheme2.schemeCode, 'JK-SCH-0016');
      expect(scheme2.followup, isNotNull);
      expect(scheme2.followup!.status, 'Applied');
      expect(scheme2.followup!.submissionDate, '2026-10-29');
    });
  });
}
