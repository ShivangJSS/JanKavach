import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/data/models/eligible_scheme_model.dart';
import 'package:kavach/views/eligible_schemes_screen/scheme_details_screen.dart';

void main() {
  group('EligibleSchemeModel scheme document lists', () {
    test('parses documents.available_documents and documents.missing_documents independently from legacy missingDocuments', () {
      final json = {
        'scheme_id': 12,
        'scheme_code': 'JK-SCH-0012',
        'scheme_name': 'Emergency Medical Assistance Scheme',
        'eligibility_status': 'Potentially Eligible',
        'match_percent': 85,
        'required_documents': [
          {'id': 26, 'name': 'Death Certificate', 'is_mandatory': true},
          {'id': 27, 'name': 'Medical Records', 'is_mandatory': true},
          {'id': 28, 'name': 'FIR / Police Report Copy', 'is_mandatory': false},
        ],
        'documents': {
          'available_documents': [
            {
              'document_type_id': 1,
              'code': 'DOC_AADHAAR',
              'document_name': 'Aadhaar Card',
              'is_mandatory': true,
              'is_available': true,
            },
            {
              'document_type_id': 2,
              'code': 'DOC_VOTER_ID',
              'document_name': 'Voter ID (EPIC)',
              'is_mandatory': false,
              'is_available': true,
            },
          ],
          'missing_documents': [
            {
              'document_type_id': 6,
              'code': 'DOC_DOMICILE',
              'document_name': 'Residence / Domicile Certificate',
              'is_mandatory': true,
              'is_available': false,
            },
          ],
        },
      };

      final scheme = EligibleSchemeModel.fromJson(json);

      // Legacy Documents to check list remains untouched.
      expect(
        scheme.missingDocuments,
        equals([
          'Death Certificate',
          'Medical Records',
          'FIR / Police Report Copy',
        ]),
      );

      expect(scheme.availableDocuments.length, 2);
      expect(scheme.availableDocuments[0].documentName, 'Aadhaar Card');
      expect(scheme.availableDocuments[0].isMandatory, isTrue);
      expect(scheme.availableDocuments[0].isAvailable, isTrue);
      expect(scheme.availableDocuments[1].documentName, 'Voter ID (EPIC)');
      expect(scheme.availableDocuments[1].isMandatory, isFalse);

      expect(scheme.missingDocumentItems.length, 1);
      expect(
        scheme.missingDocumentItems[0].documentName,
        'Residence / Domicile Certificate',
      );
      expect(scheme.missingDocumentItems[0].isMandatory, isTrue);
      expect(scheme.missingDocumentItems[0].isAvailable, isFalse);

      // Verify cache serialization preserves all three lists independently.
      final roundTrip = EligibleSchemeModel.fromJson(scheme.toJson());
      expect(roundTrip.missingDocuments, equals(scheme.missingDocuments));
      expect(roundTrip.availableDocuments.length, 2);
      expect(roundTrip.availableDocuments.first.documentName, 'Aadhaar Card');
      expect(roundTrip.missingDocumentItems.length, 1);
      expect(
        roundTrip.missingDocumentItems.first.documentName,
        'Residence / Domicile Certificate',
      );
    });

    test('handles null, missing, and malformed documents payloads safely', () {
      final schemeWithNullDocs = EligibleSchemeModel.fromJson({
        'scheme_code': 'JK-NULL',
        'scheme_name': 'Null Docs Scheme',
        'documents': null,
      });
      expect(schemeWithNullDocs.availableDocuments, isEmpty);
      expect(schemeWithNullDocs.missingDocumentItems, isEmpty);

      final schemeWithListDocs = EligibleSchemeModel.fromJson({
        'scheme_code': 'JK-LIST',
        'scheme_name': 'Legacy List Docs Scheme',
        'documents': ['Legacy Item'],
      });
      expect(schemeWithListDocs.availableDocuments, isEmpty);
      expect(schemeWithListDocs.missingDocumentItems, isEmpty);

      final schemeWithEmptyArrays = EligibleSchemeModel.fromJson({
        'scheme_code': 'JK-EMPTY',
        'scheme_name': 'Empty Arrays Scheme',
        'documents': {
          'available_documents': [],
          'missing_documents': [
            {'document_name': '  '},
          ],
        },
      });
      expect(schemeWithEmptyArrays.availableDocuments, isEmpty);
      expect(schemeWithEmptyArrays.missingDocumentItems, isEmpty);
    });
  });

  group('SchemeDetailsScreen document cards layout', () {
    testWidgets('displays Documents to check, Available Documents, and Missing Documents in exact order above How to apply', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const scheme = EligibleSchemeModel(
        schemeId: 42,
        schemeCode: 'JK-SCH-0042',
        schemeName: 'Family Security Assistance',
        eligibilityStatus: 'Eligible',
        matchPercent: 95,
        missingDocuments: [
          'Death Certificate',
          'FIR / Police Report Copy',
        ],
        availableDocuments: [
          SchemeDocumentItem(
            documentTypeId: 1,
            code: 'DOC_AADHAAR',
            documentName: 'Aadhaar Card',
            isMandatory: true,
            isAvailable: true,
          ),
          SchemeDocumentItem(
            documentTypeId: 4,
            code: 'DOC_INCOME',
            documentName: 'Income Certificate',
            isMandatory: false,
            isAvailable: true,
          ),
        ],
        missingDocumentItems: [
          SchemeDocumentItem(
            documentTypeId: 6,
            code: 'DOC_DOMICILE',
            documentName: 'Residence / Domicile Certificate',
            isMandatory: true,
            isAvailable: false,
          ),
        ],
        application: {
          'mode': 'Online',
          'instructions': 'Submit the application at the block office.',
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SchemeDetailsScreen(scheme: scheme),
        ),
      );
      await tester.pumpAndSettle();

      final docToCheckFinder = find.text('Documents to check');
      final availableFinder = find.text('Available Documents');
      final missingFinder = find.text('Missing Documents');
      final howToApplyFinder = find.text('How to apply');

      expect(docToCheckFinder, findsOneWidget);
      expect(availableFinder, findsOneWidget);
      expect(missingFinder, findsOneWidget);
      expect(howToApplyFinder, findsOneWidget);

      // Verify exact top-to-bottom section ordering.
      final yDocToCheck = tester.getTopLeft(docToCheckFinder).dy;
      final yAvailable = tester.getTopLeft(availableFinder).dy;
      final yMissing = tester.getTopLeft(missingFinder).dy;
      final yHowToApply = tester.getTopLeft(howToApplyFinder).dy;

      expect(yDocToCheck, lessThan(yAvailable));
      expect(yAvailable, lessThan(yMissing));
      expect(yMissing, lessThan(yHowToApply));

      // Verify items and count badges.
      expect(find.text('Death Certificate'), findsOneWidget);
      expect(find.text('FIR / Police Report Copy'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Available count badge
      expect(find.text('1'), findsOneWidget); // Missing count badge
    });

    testWidgets('shows clean empty states when available or missing document lists are empty', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const scheme = EligibleSchemeModel(
        schemeId: 43,
        schemeCode: 'JK-SCH-0043',
        schemeName: 'Clean Empty State Scheme',
        eligibilityStatus: 'Eligible',
        matchPercent: 100,
        missingDocuments: [],
        availableDocuments: [],
        missingDocumentItems: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SchemeDetailsScreen(scheme: scheme),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No missing documents were reported.'), findsOneWidget);
      expect(
        find.text('No available documents found for this scheme.'),
        findsOneWidget,
      );
      expect(
        find.text('No missing documents found for this scheme.'),
        findsOneWidget,
      );
      expect(find.text('0'), findsNWidgets(2));
    });
  });
}
