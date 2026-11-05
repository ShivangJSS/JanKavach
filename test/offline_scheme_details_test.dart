import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/scheme_model.dart';
import 'package:kavach/data/repository/scheme_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Scheme Details Resolution Tests', () {
    final repository = SchemeRepository();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getImmediateOfflineDetails produces complete map for bundled scheme', () {
      const scheme = SchemeModel(
        id: 1,
        code: 'JK-SCH-0001',
        name: 'Pradhan Mantri Matru Vandana Yojana (PMMVY)',
        level: 'National',
        status: 'Active',
        activeEnrollment: true,
      );

      final details = repository.getImmediateOfflineDetails(scheme);

      expect(details['id'], equals(1));
      expect(details['code'], equals('JK-SCH-0001'));
      expect(details['name'], contains('Pradhan Mantri Matru Vandana Yojana'));

      // Check classification structure
      expect(details['classification'], isA<Map>());
      expect(details['classification']['level'], equals('National'));
      expect(details['classification']['status'], equals('Active'));
      expect(details['classification']['active_enrollment'], isTrue);

      // Check benefits structure
      expect(details['benefits'], isA<List>());
      expect((details['benefits'] as List).isNotEmpty, isTrue);

      // Check application structure
      expect(details['application'], isA<Map>());
      expect(details['application']['mode'], isNotNull);

      // Check eligibility and rules
      expect(details['eligibility_summary'], isNotNull);
      expect(details['eligibility_rules'], isA<List>());
      expect((details['eligibility_rules'] as List).isNotEmpty, isTrue);
    });

    test('normalizeSchemeDetails handles a custom/newly added scheme with fallbackScheme', () {
      const newScheme = SchemeModel(
        id: 9999,
        code: 'JK-SCH-9999',
        name: 'New Future Welfare Scheme',
        shortName: 'NFWS',
        description: 'A brand new scheme added to backend',
        level: 'National',
        status: 'Active',
        activeEnrollment: true,
        benefitType: 'Cash Transfer',
        benefitDescription: 'Direct benefit of Rs 5000',
        benefitAmount: 5000,
        applicationMode: 'Online',
        portalUrl: 'https://newscheme.gov.in',
        targetGroupSummary: 'Eligible families in need',
        eligibilitySummary: '1. Aadhaar Card. 2. Income Certificate.',
      );

      final rawFromList = newScheme.toJson();
      final normalized = repository.normalizeSchemeDetails(
        rawFromList,
        fallbackScheme: newScheme,
      );

      expect(normalized['id'], equals(9999));
      expect(normalized['name'], equals('New Future Welfare Scheme'));
      expect(normalized['classification']['level'], equals('National'));
      expect(normalized['classification']['status'], equals('Active'));
      expect(normalized['benefits'], isA<List>());
      expect((normalized['benefits'] as List).first['type'], equals('Cash Transfer'));
      expect((normalized['benefits'] as List).first['amount'], equals(5000));
      expect(normalized['application']['mode'], equals('Online'));
      expect(normalized['application']['portal_url'], equals('https://newscheme.gov.in'));
      expect(normalized['documents'], isA<List>());
      expect((normalized['documents'] as List).isNotEmpty, isTrue);
    });

    test('getSchemeDetails resolves offline without throwing error', () async {
      const scheme = SchemeModel(
        id: 21,
        code: 'JK-SCH-0021',
        name: 'Pradhan Mantri Jeevan Jyoti Yojana (PMJJBY)',
        level: 'National',
        status: 'Active',
        activeEnrollment: true,
      );

      // In unit test without mock HTTP server, network will fail and fallback will execute
      final details = await repository.getSchemeDetails(
        21,
        fallbackScheme: scheme,
      );

      expect(details, isNotNull);
      expect(details['id'], equals(21));
      expect(details['name'], contains('Pradhan Mantri Jeevan Jyoti Yojana'));
      expect(details['benefits'], isA<List>());
      expect(details['application'], isA<Map>());
    });

    test('normalizes both source_url and application_url correctly for online schemes', () {
      final raw = {
        'id': 9998,
        'scheme_code': 'JK-SCH-9998',
        'name': 'Online Digital Portal Scheme',
        'application_mode': 'Online',
        'application_url': 'https://apply.scheme.gov.in/form',
        'source_url': 'https://scheme.gov.in',
      };

      final normalized = repository.normalizeSchemeDetails(raw);
      expect(normalized['application']['mode'], equals('Online'));
      expect(normalized['application']['application_url'], equals('https://apply.scheme.gov.in/form'));
      expect(normalized['application']['portal_url'], equals('https://apply.scheme.gov.in/form'));
      expect(normalized['source']['url'], equals('https://scheme.gov.in'));
    });
  });
}
