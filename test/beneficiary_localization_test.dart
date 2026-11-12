import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/core/localization/app_localizations.dart';
import 'package:kavach/core/localization/localized_value_helper.dart';
import 'package:kavach/data/models/%20beneficiary_model.dart';
import 'package:kavach/views/beneficiary_detail_screen/beneficiary_detail_screen.dart';

Widget _wrapWithLocale(Locale locale, Widget child) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [
      Locale('en'),
      Locale('hi'),
      Locale('as'),
    ],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

BeneficiaryModel _sampleBeneficiary() {
  return const BeneficiaryModel(
    id: 42,
    beneficiaryCode: 'JK-UP-2026-000215',
    name: 'Asha Devi',
    gender: 'Female',
    dob: '2001-11-15',
    age: 24,
    mobile: '9876543210',
    villageName: 'Rampur',
    recordStatus: 'Matched',
    assessmentStatus: 'Completed',
    registrationDate: '2026-11-11',
    applicationCount: 0,
  );
}

Map<String, dynamic> _sampleDetails() {
  return {
    'id': 42,
    'beneficiary_code': 'JK-UP-2026-000215',
    'name': 'Asha Devi',
    'gender': 'Female',
    'dob': '2001-11-15',
    'age': 24,
    'registration_date': '2026-11-11',
    'relation_type': 'Father',
    'relation_name': 'Ramesh Kumar',
    'father_name': null,
    'mother_name': '',
    'spouse_name': null,
    'mobile': '9876543210',
    'alt_mobile': null,
    'has_aadhaar': '1',
    'aadhaar_last4': '1234',
    'village_name': 'Rampur',
    'post_office': 'Harhua',
    'address_line': 'Ward 4',
    'pincode': '221105',
    'area_type': 'Rural',
    'state_id': 9,
    'district_id': 120,
    'block_id': 45,
    'gram_panchayat_id': 310,
    'village_id': 901,
    'consent_given': '1',
    'privacy_consent': '0',
    'consent_date': '2026-11-11',
    'remarks': null,
    'last_assessed_at': '2026-11-11',
    'last_matched_at': null,
    'record_status': 'Matched',
    'assessment_status': 'Completed',
  };
}

void main() {
  group('LocalizedValueHelper & BeneficiaryDetailScreen localization', () {
    void useTallPhoneViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('renders English headers and canonical values cleanly', (
      tester,
    ) async {
      useTallPhoneViewport(tester);
      await tester.pumpWidget(
        _wrapWithLocale(
          const Locale('en'),
          BeneficiaryDetailScreen(
            beneficiary: _sampleBeneficiary(),
            detailsLoader: (_) async => _sampleDetails(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Beneficiary Details'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Matched'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Father'), findsOneWidget);
      expect(find.text('Rural'), findsOneWidget);
      expect(find.text('24 years'), findsOneWidget);
      expect(find.text('Yes'), findsNWidgets(2));
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Not provided'), findsWidgets);
    });

    testWidgets(
      'translates DB English values, headers, statuses, booleans and age to Hindi',
      (tester) async {
        useTallPhoneViewport(tester);
        await tester.pumpWidget(
          _wrapWithLocale(
            const Locale('hi'),
            BeneficiaryDetailScreen(
              beneficiary: _sampleBeneficiary(),
              detailsLoader: (_) async => _sampleDetails(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // AppBar & section titles
        expect(find.text('लाभार्थी विवरण'), findsOneWidget);
        expect(find.text('व्यक्तिगत जानकारी'), findsOneWidget);
        expect(find.text('पारिवारिक विवरण'), findsOneWidget);
        expect(find.text('संपर्क विवरण'), findsOneWidget);
        expect(find.text('पता विवरण'), findsOneWidget);
        expect(find.text('सहमति और टिप्पणियाँ'), findsOneWidget);

        // Status pills & canonical DB values translated on-device
        expect(find.text('मिलान पूर्ण'), findsOneWidget);
        expect(find.text('पूर्ण'), findsOneWidget);
        expect(find.text('महिला'), findsOneWidget);
        expect(find.text('पिता'), findsOneWidget);
        expect(find.text('ग्रामीण'), findsOneWidget);
        expect(find.text('24 वर्ष'), findsOneWidget);
        expect(find.text('हाँ'), findsNWidgets(2));
        expect(find.text('नहीं'), findsOneWidget);
        expect(find.text('प्रदान नहीं किया गया'), findsWidgets);

        // User-entered names/villages stay intact without corruption
        expect(find.text('Asha Devi'), findsOneWidget);
        expect(find.text('Ramesh Kumar'), findsOneWidget);
        expect(find.text('Rampur'), findsOneWidget);

        // Ensure English labels do not leak into Hindi UI
        expect(find.text('Personal Information'), findsNothing);
        expect(find.text('Female'), findsNothing);
        expect(find.text('Father'), findsNothing);
        expect(find.text('Not provided'), findsNothing);

        // Date formatting should not stay English 'Nov'
        expect(find.textContaining('Nov'), findsNothing);

        // Also verify offline / sync-failed / partial-match / single-letter gender / null age / numeric guard in Hindi
        await tester.pumpWidget(
          _wrapWithLocale(
            const Locale('hi'),
            BeneficiaryDetailScreen(
              key: const ValueKey('offline-sync-failed'),
              beneficiary: const BeneficiaryModel(
                id: -7,
                beneficiaryCode: 'LOCAL-0007',
                name: '1',
                gender: 'F',
                age: null,
                dob: '2001-11-15',
                recordStatus: 'Sync Failed (422)',
                assessmentStatus: 'pending_sync',
              ),
              detailsLoader: (_) async => {
                'id': -7,
                'beneficiary_code': 'LOCAL-0007',
                'name': '1',
                'gender': 'F',
                'age': null,
                'dob': '2001-11-15',
                'record_status': 'Sync Failed (422)',
                'assessment_status': 'pending_sync',
                'relation_type': null,
                'area_type': null,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('सिंक विफल रहा'), findsOneWidget);
        expect(find.text('सिंक लंबित'), findsOneWidget);
        expect(find.text('महिला'), findsOneWidget);
        expect(find.text('प्रदान नहीं किया गया'), findsWidgets);
        expect(find.text('1'), findsOneWidget);

        final screenContext = tester.element(find.text('सिंक लंबित'));
        expect(
          LocalizedValueHelper.translateOption(screenContext, '1'),
          '1',
        );
        expect(
          LocalizedValueHelper.formatAge(screenContext, null),
          'आयु उपलब्ध नहीं',
        );
        final formattedDate = LocalizedValueHelper.formatDate(
          screenContext,
          '2001-11-15',
        );
        expect(formattedDate, contains('2001'));
        expect(formattedDate, isNot(contains('Nov')));
      },
    );

    testWidgets(
      'translates DB English values, statuses, age and headers to Assamese',
      (tester) async {
        useTallPhoneViewport(tester);
        await tester.pumpWidget(
          _wrapWithLocale(
            const Locale('as'),
            BeneficiaryDetailScreen(
              beneficiary: _sampleBeneficiary(),
              detailsLoader: (_) async => _sampleDetails(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('হিতাধিকাৰীৰ বিৱৰণ'), findsOneWidget);
        expect(find.text('ব্যক্তিগত তথ্য'), findsOneWidget);
        expect(find.text('মিল সম্পূৰ্ণ'), findsOneWidget);
        expect(find.text('সম্পূৰ্ণ'), findsOneWidget);
        expect(find.text('মহিলা'), findsOneWidget);
        expect(find.text('পিতৃ'), findsOneWidget);
        expect(find.text('গ্ৰাম্য'), findsOneWidget);
        expect(find.text('24 বছৰ'), findsOneWidget);
        expect(find.text('হয়'), findsNWidgets(2));
        expect(find.text('নহয়'), findsOneWidget);
        expect(find.text('Personal Information'), findsNothing);
        expect(find.text('Not provided'), findsNothing);
        expect(find.textContaining('Nov'), findsNothing);
      },
    );
  });
}
