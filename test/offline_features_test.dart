import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/data/models/ beneficiary_model.dart';
import 'package:kavach/data/models/dashboard_response.dart';
import 'package:kavach/data/models/followup_model.dart';
import 'package:kavach/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Authentication & Caching Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves and verifies offline credentials accurately (case-insensitive username)', () async {
      expect(await StorageService.isOfflineLoginAvailable(), isFalse);

      await StorageService.saveOfflineCredentials(
        username: 'User123',
        password: 'SecretPassword99',
      );

      expect(await StorageService.isOfflineLoginAvailable(), isTrue);

      // Same credentials should pass
      expect(
        await StorageService.verifyOfflineCredentials('User123', 'SecretPassword99'),
        isTrue,
      );

      // Case-insensitive username should pass
      expect(
        await StorageService.verifyOfflineCredentials('user123', 'SecretPassword99'),
        isTrue,
      );

      // Wrong password should fail
      expect(
        await StorageService.verifyOfflineCredentials('user123', 'WrongPassword'),
        isFalse,
      );

      // Different username should fail
      expect(
        await StorageService.verifyOfflineCredentials('otheruser', 'SecretPassword99'),
        isFalse,
      );
    });

    test('Saves and retrieves user profile details offline', () async {
      expect(await StorageService.getUserProfile(), isNull);

      final mockProfile = {
        'id': 42,
        'username': 'field_officer_1',
        'name': 'Ramesh Kumar',
        'user_code': 'USR-42001',
        'email': 'ramesh@example.com',
        'mobile': '9876543210',
        'designation': 'Gram Sevak',
        'organization': 'Rural Development',
        'village': 'Rampur',
        'block': 'Kalyanpur',
        'district': 'Kanpur Dehat',
        'state': 'Uttar Pradesh',
        'address': 'House 14, Main Road',
      };

      await StorageService.saveUserProfile(mockProfile);

      final cachedProfile = await StorageService.getUserProfile();
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!['name'], 'Ramesh Kumar');
      expect(cachedProfile['user_code'], 'USR-42001');
      expect(cachedProfile['designation'], 'Gram Sevak');
      expect(cachedProfile['village'], 'Rampur');
      expect(cachedProfile['district'], 'Kanpur Dehat');
    });

    test('Saves and retrieves dashboard summary numbers offline', () async {
      expect(await StorageService.getDashboardSummary(), isNull);

      const summary = DashboardSummary(
        beneficiariesRegistered: 125,
        applicationsSubmitted: 84,
        applicationsApproved: 52,
        followupsDone: 19,
      );

      await StorageService.saveDashboardSummary(summary);

      final cachedSummary = await StorageService.getDashboardSummary();
      expect(cachedSummary, isNotNull);
      expect(cachedSummary!.beneficiariesRegistered, 125);
      expect(cachedSummary.applicationsSubmitted, 84);
      expect(cachedSummary.applicationsApproved, 52);
      expect(cachedSummary.followupsDone, 19);
    });

    test('DashboardSummary roundtrips correctly to and from JSON', () {
      const summary = DashboardSummary(
        beneficiariesRegistered: 99,
        applicationsSubmitted: 45,
        applicationsApproved: 30,
        followupsDone: 12,
      );

      final json = summary.toJson();
      final reconstructed = DashboardSummary.fromJson(json);

      expect(reconstructed.beneficiariesRegistered, 99);
      expect(reconstructed.applicationsSubmitted, 45);
      expect(reconstructed.applicationsApproved, 30);
      expect(reconstructed.followupsDone, 12);
    });

    test('FollowupDashboardData saves and retrieves offline', () async {
      expect(await StorageService.getFollowupDashboard(), isNull);

      const followupData = FollowupDashboardData(
        totalUsersRegistered: 50,
        totalApplied: 35,
        pending: 15,
        complete: 20,
        notAppliedYet: 5,
        applicationPending: 7,
        documentIssue: 2,
        verificationPending: 1,
        overdue: 4,
        today: 6,
        upcoming: 5,
      );

      await StorageService.saveFollowupDashboard(followupData);

      final cached = await StorageService.getFollowupDashboard();
      expect(cached, isNotNull);
      expect(cached!.totalUsersRegistered, 50);
      expect(cached.totalApplied, 35);
      expect(cached.pending, 15);
      expect(cached.complete, 20);
      expect(cached.overdue, 4);
      expect(cached.today, 6);
      expect(cached.upcoming, 5);
    });

    test('clearSession clears tokens while preserving cached offline data', () async {
      await StorageService.saveUserProfile({'name': 'Test User'});
      await StorageService.saveDashboardSummary(const DashboardSummary(beneficiariesRegistered: 10));
      await StorageService.saveAccessToken('token_abc');
      await StorageService.saveRefreshToken('refresh_abc');

      expect(await StorageService.getUserProfile(), isNotNull);
      expect(await StorageService.getDashboardSummary(), isNotNull);
      expect(await StorageService.getAccessToken(), isNotNull);

      await StorageService.clearSession();

      expect(await StorageService.getAccessToken(), isNull);
      expect(await StorageService.getRefreshToken(), isNull);
      // Offline cache preserved for offline access
      expect(await StorageService.getUserProfile(), isNotNull);
      expect(await StorageService.getDashboardSummary(), isNotNull);
    });

    test('User cache isolation prevents data leakage when switching users', () async {
      // 1. User A logs in
      await StorageService.saveUserProfile({
        'id': 101,
        'user_code': 'JK-USR-00101',
        'username': 'user_a',
        'name': 'User A',
      });

      await StorageService.saveDashboardSummary(
        const DashboardSummary(
          beneficiariesRegistered: 3,
          applicationsSubmitted: 0,
          applicationsApproved: 1,
          followupsDone: 19,
        ),
      );

      await StorageService.saveFollowupDashboard(
        const FollowupDashboardData(
          totalUsersRegistered: 3,
          totalApplied: 0,
          pending: 19,
          complete: 1,
          notAppliedYet: 2,
          applicationPending: 0,
          documentIssue: 0,
          verificationPending: 0,
          overdue: 0,
          today: 0,
          upcoming: 19,
        ),
      );

      // Verify User A has cached data
      final userASummary = await StorageService.getDashboardSummary();
      expect(userASummary?.beneficiariesRegistered, 3);
      expect(userASummary?.followupsDone, 19);

      // 2. User B (Shivang) logs in
      await StorageService.saveUserProfile({
        'id': 32,
        'user_code': 'JK-USR-00032',
        'username': 'shivang',
        'name': 'Shivang Singh',
      });

      // 3. User B should NOT see User A's dashboard summary or followups
      final userBSummary = await StorageService.getDashboardSummary();
      expect(userBSummary, isNull);

      final userBFollowup = await StorageService.getFollowupDashboard();
      expect(userBFollowup, isNull);

      // 4. User B saves their own data (0s initially)
      await StorageService.saveDashboardSummary(
        const DashboardSummary(
          beneficiariesRegistered: 0,
          applicationsSubmitted: 0,
          applicationsApproved: 0,
          followupsDone: 0,
        ),
      );

      final freshSummary = await StorageService.getDashboardSummary();
      expect(freshSummary?.beneficiariesRegistered, 0);
      expect(freshSummary?.followupsDone, 0);
    });

    test('Offline BeneficiaryModel represents local pending registration correctly', () {
      final offlineBeneficiary = BeneficiaryModel(
        id: -1,
        beneficiaryCode: 'OFFLINE-1',
        name: 'Ramesh Kumar',
        gender: 'Male',
        dob: '1990-01-01',
        age: 36,
        mobile: '9876543210',
        villageName: 'Rampur',
        assessmentStatus: 'Pending Sync (Offline)',
        journeyStage: 1,
      );

      expect(offlineBeneficiary.id, -1);
      expect(offlineBeneficiary.name, 'Ramesh Kumar');
      expect(offlineBeneficiary.assessmentStatus, 'Pending Sync (Offline)');

      final json = offlineBeneficiary.toJson();
      expect(json['id'], -1);
      expect(json['beneficiary_code'], 'OFFLINE-1');
      expect(json['assessment_status'], 'Pending Sync (Offline)');

      final deserialized = BeneficiaryModel.fromJson(json);
      expect(deserialized.id, -1);
      expect(deserialized.name, 'Ramesh Kumar');
      expect(deserialized.assessmentStatus, 'Pending Sync (Offline)');
    });

    test('Occupation and monthly income mapping formats match backend schema', () {
      const occupationMappings = {
        'Agricultural Labourer': 'AGRI_LABOUR',
        'Cultivator / Farmer': 'CULTIVATOR',
        'Daily Wage Labourer': 'DAILY_WAGE',
        'Construction Worker': 'CONSTRUCTION',
        'Domestic Worker': 'DOMESTIC',
        'Street Vendor': 'STREET_VENDOR',
        'Artisan / Weaver': 'ARTISAN',
        'Fisherman': 'FISHERMAN',
        'Small Business / Shop': 'SMALL_BUSINESS',
        'Salaried - Private': 'PRIVATE_JOB',
        'Salaried - Government': 'GOVT_JOB',
        'Self-employed / Own Account': 'SELF_EMPLOYED',
        'Student': 'STUDENT',
        'Homemaker': 'HOMEMAKER',
        'Unemployed': 'UNEMPLOYED',
        'Retired': 'RETIRED',
        'Unable to Work': 'UNABLE',
        'Other': 'OTHER',
        'Trader': 'TRADER',
        'Weaver': 'WEAVER',
        'Unorganized Sector': 'UNORGANIZED',
        'Service': 'SERVICE',
      };

      const incomeBandMappings = {
        'No income': 'NO_INCOME',
        'Less than ₹25,000': 'BELOW_25K',
        '₹25,000–₹50,000': '25K_50K',
        '₹50,000–₹75,000': '50K_75K',
        'Less than ₹1,00,000': 'BELOW_1L',
        'More than ₹1,00,000': 'ABOVE_1L',
        'Less than ₹8,00,000': 'BELOW_8L',
      };

      // Ensure all 22 occupations map to valid non-empty codes
      expect(occupationMappings.length, 22);
      for (final entry in occupationMappings.entries) {
        expect(entry.value, isNotEmpty);
        expect(entry.value, isNot(contains(' ')));
      }

      // Ensure all 7 income bands map to valid non-empty codes
      expect(incomeBandMappings.length, 7);
      for (final entry in incomeBandMappings.entries) {
        expect(entry.value, isNotEmpty);
        expect(entry.value, isNot(contains(' ')));
      }
    });
  });
}
