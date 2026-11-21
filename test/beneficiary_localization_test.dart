import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/core/localization/app_localizations.dart';
import 'package:kavach/core/localization/localized_value_helper.dart';
import 'package:kavach/data/models/%20beneficiary_model.dart';
import 'package:kavach/data/models/followup_model.dart';
import 'package:kavach/data/repository/followup_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/views/beneficiary_detail_screen/beneficiary_detail_screen.dart';
import 'package:kavach/views/followup/followup_hub_screen.dart';

Widget _wrapWithLocale(Locale locale, Widget child) {
  return MaterialApp(
    key: UniqueKey(),
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

Future<void> _pumpLocalizedWidget(
  WidgetTester tester,
  Locale locale,
  Widget child,
) async {
  rootBundle.clear();
  await tester.pumpWidget(_wrapWithLocale(locale, child));
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }
  await tester.pumpAndSettle();
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
    'has_bank_account': '1',
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
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

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
      await _pumpLocalizedWidget(
        tester,
        const Locale('en'),
        BeneficiaryDetailScreen(
          beneficiary: _sampleBeneficiary(),
          detailsLoader: (_) async => _sampleDetails(),
        ),
      );

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

      // Available Documents section & items in English
      expect(find.text('Available Documents'), findsOneWidget);
      expect(find.text('Aadhaar Card'), findsOneWidget);
      expect(find.text('Bank Account Details'), findsOneWidget);
      expect(find.text('Available'), findsNWidgets(2));
    });

    testWidgets(
      'translates DB English values, headers, statuses, booleans and age to Hindi',
      (tester) async {
        useTallPhoneViewport(tester);
        await _pumpLocalizedWidget(
          tester,
          const Locale('hi'),
          BeneficiaryDetailScreen(
            beneficiary: _sampleBeneficiary(),
            detailsLoader: (_) async => _sampleDetails(),
          ),
        );

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

        // Available Documents section & items in Hindi
        expect(find.text('उपलब्ध दस्तावेज़'), findsOneWidget);
        expect(find.text('आधार कार्ड'), findsOneWidget);
        expect(find.text('बैंक खाता विवरण'), findsOneWidget);
        expect(find.text('उपलब्ध'), findsNWidgets(2));
        expect(find.text('Available Documents'), findsNothing);
        expect(find.text('Existing Documents'), findsNothing);

        // Date formatting should not stay English 'Nov'
        expect(find.textContaining('Nov'), findsNothing);

        // Also verify offline / sync-failed / partial-match / single-letter gender / null age / numeric guard in Hindi
        await _pumpLocalizedWidget(
          tester,
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
        );

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
      'translates DB English values, statuses, age, headers and available documents to Assamese',
      (tester) async {
        useTallPhoneViewport(tester);
        await _pumpLocalizedWidget(
          tester,
          const Locale('as'),
          BeneficiaryDetailScreen(
            beneficiary: _sampleBeneficiary(),
            detailsLoader: (_) async => _sampleDetails(),
          ),
        );

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

        // Available Documents section & items in Assamese
        expect(find.text('উপলব্ধ নথিপত্ৰ'), findsOneWidget);
        expect(find.text('আধাৰ কাৰ্ড'), findsOneWidget);
        expect(find.text('বেংক একাউণ্টৰ বিৱৰণ'), findsOneWidget);
        expect(find.text('উপলব্ধ'), findsNWidgets(2));
        expect(find.text('Available Documents'), findsNothing);
        expect(find.text('Existing Documents'), findsNothing);
      },
    );

    testWidgets('renders empty documents state cleanly in all 3 languages', (
      tester,
    ) async {
      useTallPhoneViewport(tester);
      final emptyDocsDetails = Map<String, dynamic>.from(_sampleDetails())
        ..['has_aadhaar'] = '0'
        ..['has_bank_account'] = '0'
        ..['aadhaar_last4'] = null
        ..['aadhaar_number'] = null;

      // English empty state
      await _pumpLocalizedWidget(
        tester,
        const Locale('en'),
        BeneficiaryDetailScreen(
          beneficiary: _sampleBeneficiary(),
          detailsLoader: (_) async => emptyDocsDetails,
        ),
      );
      expect(find.text('No Documents Available'), findsOneWidget);
      expect(
        find.text('No documents available for this beneficiary yet.'),
        findsOneWidget,
      );

      // Hindi empty state
      await _pumpLocalizedWidget(
        tester,
        const Locale('hi'),
        BeneficiaryDetailScreen(
          key: const ValueKey('empty-hi'),
          beneficiary: _sampleBeneficiary(),
          detailsLoader: (_) async => emptyDocsDetails,
          availableDocsLoader: (_) async => [],
        ),
      );
      expect(find.text('कोई दस्तावेज़ उपलब्ध नहीं है'), findsOneWidget);
      expect(
        find.text('इस लाभार्थी के लिए अभी तक कोई दस्तावेज़ उपलब्ध नहीं है।'),
        findsOneWidget,
      );

      // Assamese empty state
      await _pumpLocalizedWidget(
        tester,
        const Locale('as'),
        BeneficiaryDetailScreen(
          key: const ValueKey('empty-as'),
          beneficiary: _sampleBeneficiary(),
          detailsLoader: (_) async => emptyDocsDetails,
          availableDocsLoader: (_) async => [],
        ),
      );
      expect(find.text('কোনো নথিপত্ৰ উপলব্ধ নহয়'), findsOneWidget);
      expect(
        find.text('এই হিতাধিকাৰীৰ বাবে এতিয়ালৈকে কোনো নথিপত্ৰ উপলব্ধ হোৱা নাই।'),
        findsOneWidget,
      );
    });

    testWidgets('LocalizedValueHelper.translateDocumentName translates all known docs', (
      tester,
    ) async {
      late BuildContext testContext;
      await _pumpLocalizedWidget(
        tester,
        const Locale('hi'),
        Builder(
          builder: (ctx) {
            testContext = ctx;
            return const SizedBox();
          },
        ),
      );

      expect(
        LocalizedValueHelper.translateDocumentName(testContext, 'Aadhaar Card'),
        'आधार कार्ड',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(
          testContext,
          'Bank Account Details',
        ),
        'बैंक खाता विवरण',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(testContext, 'PAN Card'),
        'पैन कार्ड',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(testContext, 'Ration Card'),
        'राशन कार्ड',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(
          testContext,
          'Caste Certificate',
        ),
        'जाति प्रमाण पत्र',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(
          testContext,
          'Disability Certificate',
        ),
        'दिव्यांगता प्रमाण पत्र / UDID',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(
          testContext,
          'Residence Certificate',
        ),
        'निवास / अधिवास प्रमाण पत्र',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(
          testContext,
          'Medical Certificate',
        ),
        'चिकित्सा रिकॉर्ड',
      );
      expect(
        LocalizedValueHelper.translateDocumentName(testContext, 'FIR Copy'),
        'एफआईआर / पुलिस रिपोर्ट प्रति',
      );
    });

    testWidgets('BeneficiaryRegistration draft status row does not overflow on 360px width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpLocalizedWidget(
        tester,
        const Locale('en'),
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, size: 14, color: Color(0xFF087443)),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Draft saved locally: 19 Nov 2026, 11:29:43 am',
                          style: TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'Reload saved draft',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Draft saved locally:'), findsOneWidget);
      expect(find.text('Reload saved draft'), findsOneWidget);
    });

    testWidgets('Dashboard cards and Followup cards translate correctly in English, Hindi, and Assamese', (
      tester,
    ) async {
      // 1. English
      await _pumpLocalizedWidget(
        tester,
        const Locale('en'),
        Builder(
          builder: (context) {
            expect(context.tr('dashboard.applications_submitted'), 'Application\nSubmitted');
            expect(context.tr('dashboard.applications_approved'), 'Application\nApproved');
            expect(context.tr('followup.registered_beneficiaries'), 'Registered\nBeneficiaries');
            expect(context.tr('followup.total_applied_submitted'), 'Total Applied\nSubmitted');
            expect(context.tr('followup.pending_followups'), 'Pending\nFollow-ups');
            expect(context.tr('followup.benefit_completed'), 'Benefit\nCompleted');
            expect(context.tr('followup.all_schemes'), 'All Schemes');
            expect(context.tr('followup.take_followup_btn'), 'Take Follow-up');
            return const SizedBox();
          },
        ),
      );

      // 2. Hindi
      await _pumpLocalizedWidget(
        tester,
        const Locale('hi'),
        Builder(
          builder: (context) {
            expect(context.tr('dashboard.applications_submitted'), 'जमा किए गए\nआवेदन');
            expect(context.tr('dashboard.applications_approved'), 'स्वीकृत\nआवेदन');
            expect(context.tr('Application Submitted'), 'जमा किए गए आवेदन');
            expect(context.tr('Application Approved'), 'स्वीकृत आवेदन');
            expect(context.tr('followup.registered_beneficiaries'), 'पंजीकृत\nलाभार्थी');
            expect(context.tr('followup.total_applied_submitted'), 'कुल आवेदन\nजमा किए गए');
            expect(context.tr('followup.pending_followups'), 'लंबित\nफ़ॉलो-अप');
            expect(context.tr('followup.benefit_completed'), 'लाभ वितरण\nपूर्ण');
            expect(context.tr('followup.all_schemes'), 'सभी योजनाएं');
            expect(context.tr('followup.take_followup_btn'), 'फ़ॉलो-अप लें');
            return const SizedBox();
          },
        ),
      );

      // 3. Assamese
      await _pumpLocalizedWidget(
        tester,
        const Locale('as'),
        Builder(
          builder: (context) {
            expect(context.tr('dashboard.applications_submitted'), 'দাখিল কৰা\nআবেদন');
            expect(context.tr('dashboard.applications_approved'), 'অনুমোদিত\nআবেদন');
            expect(context.tr('Application Submitted'), 'দাখিল কৰা আবেদন');
            expect(context.tr('Application Approved'), 'অনুমোদিত আবেদন');
            expect(context.tr('followup.registered_beneficiaries'), 'পঞ্জীভুক্ত\nহিতাধিকাৰী');
            expect(context.tr('followup.total_applied_submitted'), 'মুঠ দাখিল কৰা\nআবেদন');
            expect(context.tr('followup.pending_followups'), 'বাকী থকা\nফ\'ল\'-আপ');
            expect(context.tr('followup.benefit_completed'), 'লাভ বিতৰণ\nসম্পূৰ্ণ');
            expect(context.tr('followup.all_schemes'), 'সকলো আঁচনি');
            expect(context.tr('followup.take_followup_btn'), 'ফ\'ল\'-আপ লওক');
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('FollowupHubScreen renders cards and metrics in Hindi and Assamese without pixel overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = _TestFollowupRepo();

      // Test Hindi UI
      await _pumpLocalizedWidget(
        tester,
        const Locale('hi'),
        FollowupHubScreen(repository: fakeRepo),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('पंजीकृत\nलाभार्थी'), findsOneWidget);
      expect(find.text('कुल आवेदन\nजमा किए गए'), findsOneWidget);
      expect(find.text('लंबित\nफ़ॉलो-अप'), findsOneWidget);
      expect(find.text('लाभ वितरण\nपूर्ण'), findsOneWidget);
      expect(find.text('सभी योजनाएं'), findsOneWidget);

      // Test Assamese UI
      await _pumpLocalizedWidget(
        tester,
        const Locale('as'),
        FollowupHubScreen(repository: fakeRepo),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('পঞ্জীভুক্ত\nহিতাধিকাৰী'), findsOneWidget);
      expect(find.text('মুঠ দাখিল কৰা\nআবেদন'), findsOneWidget);
      expect(find.text('বাকী থকা\nফ\'ল\'-আপ'), findsOneWidget);
      expect(find.text('লাভ বিতৰণ\nসম্পূৰ্ণ'), findsOneWidget);
      expect(find.text('সকলো আঁচনি'), findsOneWidget);
    });
  });
}

class _TestFollowupRepo extends FollowupRepository {
  @override
  Future<FollowupDashboardData> getDashboardMetrics() async {
    return const FollowupDashboardData(
      totalUsersRegistered: 12,
      totalApplied: 8,
      pending: 4,
      complete: 6,
      notAppliedYet: 2,
      applicationPending: 1,
      documentIssue: 1,
      verificationPending: 0,
      overdue: 0,
      today: 1,
      upcoming: 2,
    );
  }

  @override
  Future<FollowupRegisterResponse> getRegister({
    int page = 1,
    int perPage = 20,
    String status = 'all',
    String? search,
    String? pendingReason,
    String dueFilter = 'all',
  }) async {
    return const FollowupRegisterResponse(
      items: [
        FollowupRegisterItem(
          followupId: 201,
          beneficiaryId: 1,
          beneficiaryCode: 'JK-001',
          beneficiaryName: 'Sita Devi',
          schemeId: 10,
          schemeCode: 'SCH-010',
          schemeName: 'Old Age Pension',
          status: 'Applied',
          applicationNumber: 'APP-9988',
        ),
      ],
      currentPage: 1,
      totalItems: 1,
      totalPages: 1,
    );
  }
}
