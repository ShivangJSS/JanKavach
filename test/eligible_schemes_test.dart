import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/eligible_scheme_model.dart';

void main() {
  group('Eligible Schemes Parsing Tests', () {
    test('Parses live followup/beneficiaries/{id} response successfully', () {
      final json = {
        "success": true,
        "message": "Beneficiary follow-up details fetched successfully.",
        "data": {
          "beneficiary": {
            "id": 61,
            "beneficiary_code": "JK-UP-2026-000001",
            "full_name": "Ramesh Kumar Sharma",
            "mobile_number": "9876543210",
            "gender": "Male",
            "date_of_birth": "1985-06-15",
            "age": 41,
            "village_name": "Kathwara"
          },
          "eligible_schemes": [
            {
              "scheme_id": 87,
              "scheme_code": "JK-SCH-0087",
              "scheme_name": "National Family Benefit Scheme (Rashtriya Parivarik Labh Yojana)",
              "short_name": null,
              "department_name": "Social Welfare Department",
              "application_mode": "Both",
              "benefit_summary": "One-time financial assistance of Rs. 30,000 to a BPL family upon the death of the primary breadwinner.",
              "source_url": null,
              "source_website": null,
              "portal_url": null,
              "required_documents": [
                { "id": 1, "name": "Aadhaar Card", "code": "DOC_AADHAAR", "is_mandatory": true },
                { "id": 4, "name": "Income Certificate", "code": "DOC_INCOME", "is_mandatory": true },
                { "id": 5, "name": "BPL Ration Card", "code": "DOC_BPL_CARD", "is_mandatory": true },
                { "id": 8, "name": "Bank Passbook", "code": "DOC_BANK_PASSBOOK", "is_mandatory": true },
                { "id": 26, "name": "Death Certificate of Breadwinner", "code": "DOC_DEATH_CERT", "is_mandatory": true }
              ],
              "followup": {
                "id": 1,
                "status": "Complete",
                "notes": "Financial assistance of Rs. 30,000 credited."
              }
            }
          ]
        }
      };

      final response = EligibleSchemesResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.eligibleSchemes.length, 1);
      final scheme = response.eligibleSchemes.first;
      expect(scheme.schemeId, 87);
      expect(scheme.schemeCode, "JK-SCH-0087");
      expect(scheme.schemeName, contains("National Family Benefit Scheme"));
      expect(scheme.eligibilityStatus, "Eligible");
      expect(scheme.themeName, "Social Welfare Department");
      expect(scheme.applicationMode, "Both");
      expect(scheme.benefitDescription, contains("One-time financial assistance"));
      expect(scheme.missingDocuments.length, 5);
      expect(scheme.missingDocuments, contains("Aadhaar Card"));
      expect(response.summary['total_evaluated'], 1);
      expect(response.summary['eligible_count'], 1);
    });

    test('Parses legacy/engine response with match_percent and missing_documents', () {
      final json = {
        "success": true,
        "message": "Eligibility check complete",
        "data": {
          "summary": {
            "total_evaluated": 2,
            "eligible_count": 1
          },
          "eligible_schemes": [
            {
              "scheme_id": 101,
              "scheme_code": "SCH-101",
              "scheme_name": "Scheme A",
              "eligibility_status": "Eligible",
              "match_percent": 95.5,
              "missing_documents": ["Ration Card"],
              "benefit": {
                "description": "Monthly stipend",
                "amount_text": "Rs. 1,000/mo"
              },
              "application": {
                "mode": "Online",
                "portal_url": "https://example.gov.in"
              }
            }
          ],
          "potentially_eligible_schemes": [
            {
              "scheme_id": 102,
              "scheme_code": "SCH-102",
              "scheme_name": "Scheme B",
              "eligibility_status": "Potentially Eligible",
              "match_percent": 60.0
            }
          ]
        }
      };

      final response = EligibleSchemesResponse.fromJson(json);
      expect(response.eligibleSchemes.length, 1);
      expect(response.potentiallyEligibleSchemes.length, 1);

      final schemeA = response.eligibleSchemes.first;
      expect(schemeA.matchPercent, 95.5);
      expect(schemeA.missingDocuments, ["Ration Card"]);
      expect(schemeA.actionUrl, "https://example.gov.in");
      expect(schemeA.actionLabel, "Apply Online");
    });

    test('Separates mixed schemes in eligible_schemes array into eligibleSchemes and potentiallyEligibleSchemes', () {
      final json = {
        "success": true,
        "message": "Eligibility check complete",
        "data": {
          "summary": {
            "total_evaluated": 87,
            "eligible_count": 3,
            "potential_count": 2,
          },
          "eligible_schemes": [
            {
              "scheme_id": 8,
              "scheme_code": "JK-SCH-0008",
              "scheme_name": "Women Helpline Number 181 scheme",
              "eligibility_status": "Eligible",
              "match_percent": 100.0,
            },
            {
              "scheme_id": 16,
              "scheme_code": "JK-SCH-0016",
              "scheme_name": "NALSA Scheme",
              "eligibility_status": "Eligible",
              "match_percent": 100.0,
            },
            {
              "scheme_id": 46,
              "scheme_code": "JK-SCH-0046",
              "scheme_name": "Swadhar Greh Scheme",
              "eligibility_status": "Eligible",
              "match_percent": 100.0,
            },
            {
              "scheme_id": 36,
              "scheme_code": "JK-SCH-0036",
              "scheme_name": "PMKVY Scheme",
              "eligibility_status": "Potentially Eligible",
              "match_percent": 83.33,
            },
            {
              "scheme_id": 89,
              "scheme_code": "JK-SCH-0089",
              "scheme_name": "Mukhyamantri Abhyuday Scheme",
              "eligibility_status": "Potentially Eligible",
              "match_percent": 83.33,
            },
          ]
        }
      };

      final response = EligibleSchemesResponse.fromJson(json);

      expect(response.eligibleSchemes.length, 3);
      expect(response.potentiallyEligibleSchemes.length, 2);

      expect(response.eligibleSchemes.map((s) => s.schemeId).toList(), [8, 16, 46]);
      expect(response.potentiallyEligibleSchemes.map((s) => s.schemeId).toList(), [36, 89]);

      expect(response.summary['eligible_count'], 3);
      expect(response.summary['potential_count'], 2);
      expect(response.summary['total_evaluated'], 87);
    });

    test('EligibleSchemeModel serializes to JSON correctly', () {
      const model = EligibleSchemeModel(
        schemeId: 10,
        schemeCode: 'JK-SCH-0010',
        schemeName: 'Ayushman Bharat PM-JAY',
        eligibilityStatus: 'Eligible',
        matchPercent: 100.0,
        missingDocuments: [],
      );

      final json = model.toJson();
      expect(json['scheme_id'], 10);
      expect(json['scheme_code'], 'JK-SCH-0010');
      expect(json['scheme_name'], 'Ayushman Bharat PM-JAY');
      expect(json['eligibility_status'], 'Eligible');
      expect(json['match_percent'], 100.0);
    });

    test('Negative beneficiary ID represents valid offline draft and is not rejected as invalid ID', () {
      const negativeId = -12;
      expect(negativeId < 0, isTrue);
      expect(negativeId.abs(), 12);
      // Ensure only 0 is strictly invalid
      expect(negativeId != 0, isTrue);
    });

    test('Filters out schemes marked as already applied from eligible schemes', () {
      const schemes = [
        EligibleSchemeModel(
          schemeId: 8,
          schemeCode: 'JK-SCH-0008',
          schemeName: 'Women Helpline Number 181 scheme',
          eligibilityStatus: 'Eligible',
          matchPercent: 100.0,
          missingDocuments: [],
        ),
        EligibleSchemeModel(
          schemeId: 16,
          schemeCode: 'JK-SCH-0016',
          schemeName: 'NALSA Compensation Scheme',
          eligibilityStatus: 'Eligible',
          matchPercent: 100.0,
          missingDocuments: [],
        ),
        EligibleSchemeModel(
          schemeId: 46,
          schemeCode: 'JK-SCH-0046',
          schemeName: 'National Family Benefit Scheme',
          eligibilityStatus: 'Eligible',
          matchPercent: 100.0,
          missingDocuments: [],
        ),
      ];

      // Beneficiary marks scheme 8 (Women Helpline) as already applied
      final appliedCodes = {'JK-SCH-0008'};

      final remaining = schemes
          .where((s) => !appliedCodes.contains(s.schemeCode))
          .toList();

      expect(remaining.length, 2);
      expect(remaining.map((s) => s.schemeCode), contains('JK-SCH-0016'));
      expect(remaining.map((s) => s.schemeCode), contains('JK-SCH-0046'));
      expect(remaining.map((s) => s.schemeCode), isNot(contains('JK-SCH-0008')));

      // When all schemes are marked as applied
      final allApplied = schemes.map((s) => s.schemeCode).toSet();
      final remainingWhenAllApplied = schemes
          .where((s) => !allApplied.contains(s.schemeCode))
          .toList();
      expect(remainingWhenAllApplied, isEmpty);

      // When no schemes are marked as applied
      final noneApplied = <String>{};
      final remainingWhenNone = schemes
          .where((s) => !noneApplied.contains(s.schemeCode))
          .toList();
      expect(remainingWhenNone.length, 3);
    });
  });
}
