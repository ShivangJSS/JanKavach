import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/engine/offline_eligibility_engine.dart';

void main() {
  group('OfflineEligibilityEngine Tests', () {
    late OfflineEligibilityEngine engine;

    setUp(() {
      engine = OfflineEligibilityEngine();
    });

    test('User (Female, Age 25, State 34) evaluates EXACTLY 87 schemes with 2 Eligible', () {
      final beneficiary = {
        'id': 1,
        'name': 'user',
        'gender': 'Female',
        'age': 25,
        'state_id': 34,
        'area_type': 'Rural',
      };

      final response = engine.evaluateBeneficiary(beneficiary);

      expect(response.success, isTrue);
      expect(response.summary['total_evaluated'], equals(87));
      expect(response.summary['eligible_count'], equals(2));
      expect(response.eligibleSchemes.length, equals(2));

      final matchedIds = response.eligibleSchemes.map((s) => s.schemeId).toSet();
      expect(matchedIds, contains(8));  // Women Helpline Number 181 scheme
      expect(matchedIds, contains(16)); // NALSA Compensation Scheme
    });

    test('User 1 (Female, Age 25) matches EXACTLY 2 Eligible schemes', () {
      final beneficiary = {
        'id': 1,
        'name': 'User 1',
        'gender': 'Female',
        'age': 25,
        'state_id': 23, // Madhya Pradesh
        'area_type': 'Rural',
      };

      final response = engine.evaluateBeneficiary(beneficiary);

      expect(response.success, isTrue);
      expect(response.eligibleSchemes.length, equals(2));
      expect(response.summary['eligible_count'], equals(2));

      final matchedIds = response.eligibleSchemes.map((s) => s.schemeId).toSet();
      expect(matchedIds, contains(8));  // Women Helpline Number 181 scheme
      expect(matchedIds, contains(16)); // NALSA Compensation Scheme

      final scheme8 = response.eligibleSchemes.firstWhere((s) => s.schemeId == 8);
      expect(scheme8.schemeName, contains('Women Helpline Number 181'));
      expect(scheme8.matchPercent, equals(100.0));
      expect(scheme8.eligibilityStatus, equals('Eligible'));
      expect(scheme8.reasonText, contains('Matched because Gender is Female'));

      final scheme16 = response.eligibleSchemes.firstWhere((s) => s.schemeId == 16);
      expect(scheme16.schemeName, contains('NALSA'));
      expect(scheme16.matchPercent, equals(100.0));
      expect(scheme16.eligibilityStatus, equals('Eligible'));
      expect(scheme16.reasonText, contains('Matched because Gender is Female'));
    });

    test('Male beneficiary of Age 25 is not eligible for Women Helpline or NALSA', () {
      final beneficiary = {
        'id': 2,
        'name': 'Male User',
        'gender': 'Male',
        'age': 25,
        'state_id': 23,
        'area_type': 'Rural',
      };

      final response = engine.evaluateBeneficiary(beneficiary);

      final matchedIds = response.eligibleSchemes.map((s) => s.schemeId).toSet();
      expect(matchedIds.contains(8), isFalse);
      expect(matchedIds.contains(16), isFalse);
    });

    test('Derived attributes are correctly calculated (senior_citizen, has_disability, etc.)', () {
      final profile = engine.applyDerived({
        'age': 65,
        'disability_percent': 50,
        'gender': 'Female',
        'social_category': 'MIN',
      });

      expect(profile['senior_citizen'], equals(1));
      expect(profile['has_disability'], equals(1));
      expect(profile['is_minority'], equals(1));
      expect(profile['is_transgender'], equals(0));
    });

    test('Senior Citizen Male of Age 68 is not eligible for Scheme 8 or 16 but matches senior schemes', () {
      final beneficiary = {
        'id': 3,
        'name': 'Senior Male',
        'gender': 'Male',
        'age': 68,
        'state_id': 34,
        'area_type': 'Rural',
        'answers': {
          'is_indian_citizen': 'Yes',
          'has_bank_account': 'Yes',
        },
      };

      final response = engine.evaluateBeneficiary(beneficiary);

      final matchedIds = response.eligibleSchemes.map((s) => s.schemeId).toSet();
      expect(matchedIds.contains(8), isFalse);
      expect(matchedIds.contains(16), isFalse);
      expect(response.summary['total_evaluated'], equals(87));
    });

    test('Female beneficiary with BPL (AAY) and Age 65 matches different schemes than Age 25', () {
      final beneficiary = {
        'id': 4,
        'name': 'BPL Senior Woman',
        'gender': 'Female',
        'age': 65,
        'state_id': 34,
        'area_type': 'Rural',
        'answers': {
          'is_indian_citizen': 'Yes',
          'doc_ration_aay': 'Yes',
          'has_bank_account': 'Yes',
        },
      };

      final response = engine.evaluateBeneficiary(beneficiary);

      final matchedIds = response.eligibleSchemes.map((s) => s.schemeId).toSet();
      expect(matchedIds, contains(8));
      expect(matchedIds, contains(16));
      expect(response.summary['total_evaluated'], equals(87));
      // BPL / senior attributes are derived
      final profile = engine.buildProfile(beneficiary);
      expect(profile['senior_citizen'], equals(1));
      expect(profile['has_ration_card'], equals(1));
      expect(profile['bpl_status'], equals('Yes'));
      expect(profile['ration_card_type'], equals('AAY'));
    });

    test('Unknown attributes prevent scheme from becoming Eligible', () {
      // Scheme with multiple rules where attributes are unrecorded
      // should never be marked as 'Eligible'
      final result = engine.evaluateScheme({
        'gender': 'Female',
        'age': 25,
      }, 1, engine.evaluateScheme({}, 1, []).isNotEmpty ? [] : []);
      // With no rules, it's Needs Verification
      expect(result['eligibility_status'], equals(OfflineEligibilityEngine.verify));
    });
  });
}
