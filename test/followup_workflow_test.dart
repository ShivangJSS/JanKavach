import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kavach/core/localization/app_localizations.dart';
import 'package:kavach/data/models/followup_model.dart';
import 'package:kavach/data/repository/followup_repository.dart';
import 'package:kavach/views/followup/beneficiary_followup_screen.dart';
import 'package:kavach/views/followup/followup_hub_screen.dart';
import 'package:kavach/views/followup/record_followup_sheet.dart';
import 'package:kavach/data/services/storage_service.dart';

class _FakeFollowupRepository extends FollowupRepository {
  final List<RecordFollowupPayload> recordedPayloads = [];
  String scheme2Status = 'Applied';

  @override
  Future<FollowupDashboardData> getDashboardMetrics() async {
    return const FollowupDashboardData(
      totalUsersRegistered: 1,
      totalApplied: 1,
      pending: 1,
      complete: 1,
      notAppliedYet: 1,
      applicationPending: 0,
      documentIssue: 0,
      verificationPending: 0,
      overdue: 0,
      today: 0,
      upcoming: 1,
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
          followupId: 101,
          beneficiaryId: 1,
          beneficiaryCode: 'JK-001',
          beneficiaryName: 'Sita Devi',
          schemeId: 10,
          schemeCode: 'SCH-010',
          schemeName: 'Completed Pension Scheme',
          status: 'Complete',
          benefitReceivedDate: '2026-11-10',
        ),
        FollowupRegisterItem(
          followupId: 102,
          beneficiaryId: 1,
          beneficiaryCode: 'JK-001',
          beneficiaryName: 'Sita Devi',
          schemeId: 11,
          schemeCode: 'SCH-011',
          schemeName: 'Applied Housing Scheme',
          status: 'Applied',
          submissionDate: '2026-11-05',
        ),
      ],
      currentPage: 1,
      totalItems: 2,
      totalPages: 1,
    );
  }

  @override
  Future<BeneficiaryFollowupProfile> getBeneficiaryFollowup(
    int beneficiaryId,
  ) async {
    return BeneficiaryFollowupProfile(
      id: beneficiaryId,
      beneficiaryCode: 'JK-001',
      fullName: 'Sita Devi',
      eligibleSchemes: [
        const BeneficiaryEligibleSchemeFollowup(
          schemeId: 10,
          schemeCode: 'SCH-010',
          schemeName: 'Completed Pension Scheme',
          requiredDocuments: [],
          followup: SchemeFollowupDetail(
            id: 101,
            status: 'Complete',
            benefitReceivedDate: '2026-11-10',
          ),
        ),
        BeneficiaryEligibleSchemeFollowup(
          schemeId: 11,
          schemeCode: 'SCH-011',
          schemeName: 'Applied Housing Scheme',
          requiredDocuments: const [],
          followup: SchemeFollowupDetail(
            id: 102,
            status: scheme2Status,
            submissionDate: '2026-11-05',
          ),
        ),
        const BeneficiaryEligibleSchemeFollowup(
          schemeId: 12,
          schemeCode: 'SCH-012',
          schemeName: 'Pending Scholarship Scheme',
          requiredDocuments: [],
          followup: SchemeFollowupDetail(
            id: 103,
            status: 'Pending',
            pendingReason: 'Not applied yet',
          ),
        ),
      ],
    );
  }

  @override
  Future<List<FollowupDocumentType>> getDocumentTypes() async {
    return const [
      FollowupDocumentType(
        id: 1,
        documentName: 'Aadhaar Card',
        documentCode: 'DOC_AADHAAR',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> recordFollowup(
    RecordFollowupPayload payload,
  ) async {
    recordedPayloads.add(payload);
    if (payload.schemeId == 11) {
      scheme2Status = payload.status;
    }
    return {'status': payload.status};
  }
}

class _PreloadedLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  final AppLocalizations localizations;
  const _PreloadedLocalizationsDelegate(this.localizations);

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(localizations);

  @override
  bool shouldReload(_PreloadedLocalizationsDelegate old) => false;
}

late AppLocalizations _enLocalizations;

Widget _wrapTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('hi'), Locale('as')],
    localizationsDelegates: [
      _PreloadedLocalizationsDelegate(_enLocalizations),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _enLocalizations = AppLocalizations(const Locale('en'));
    await _enLocalizations.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Follow-up status transition guards', () {
    testWidgets(
      'Pending follow-up allows selecting all 3 options and saving Yes, Applied',
      (tester) async {
        final fakeRepo = _FakeFollowupRepository();

        await tester.pumpWidget(
          _wrapTestApp(
            Scaffold(
              body: RecordFollowupSheet(
                beneficiaryId: 1,
                beneficiaryName: 'Sita Devi',
                schemeId: 12,
                schemeName: 'Pending Scholarship Scheme',
                existingFollowup: const SchemeFollowupDetail(
                  id: 103,
                  status: 'Pending',
                  pendingReason: 'Not applied yet',
                ),
                repository: fakeRepo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Starts in Pending
        expect(find.text('Reason for Delay / Not Applied'), findsOneWidget);

        // Tap Yes, Applied -> switches to Applied form
        await tester.tap(find.text('Yes, Applied'));
        await tester.pumpAndSettle();
        expect(find.text('Application Submission Details'), findsOneWidget);
        expect(find.text('Save & Mark as Applied'), findsOneWidget);

        // Tap Save & Mark as Applied
        await tester.ensureVisible(find.text('Save & Mark as Applied'));
        await tester.tap(find.text('Save & Mark as Applied'));
        await tester.pumpAndSettle();

        expect(fakeRepo.recordedPayloads.length, 1);
        expect(fakeRepo.recordedPayloads.single.status, 'Applied');
      },
    );

    testWidgets(
      'Applied (second follow-up) disables Yes, Applied and Not Applied and only enables Complete',
      (tester) async {
        final fakeRepo = _FakeFollowupRepository();

        await tester.pumpWidget(
          _wrapTestApp(
            Scaffold(
              body: RecordFollowupSheet(
                beneficiaryId: 1,
                beneficiaryName: 'Sita Devi',
                schemeId: 11,
                schemeName: 'Applied Housing Scheme',
                existingFollowup: const SchemeFollowupDetail(
                  id: 102,
                  status: 'Applied',
                  submissionDate: '2026-11-05',
                ),
                repository: fakeRepo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pre-selects Complete with Benefit Disbursement section
        expect(find.text('Benefit Disbursement Confirmation'), findsOneWidget);
        expect(find.text('Mark Scheme as Complete'), findsOneWidget);

        // Tapping Not Applied or Yes, Applied must NOT switch away from Complete
        await tester.tap(find.text('Not Applied'));
        await tester.pumpAndSettle();
        expect(find.text('Reason for Delay / Not Applied'), findsNothing);
        expect(find.text('Benefit Disbursement Confirmation'), findsOneWidget);

        await tester.tap(find.text('Yes, Applied'));
        await tester.pumpAndSettle();
        expect(find.text('Application Submission Details'), findsNothing);
        expect(find.text('Benefit Disbursement Confirmation'), findsOneWidget);

        // Tapping Mark Scheme as Complete saves Complete with preserved submissionDate
        await tester.ensureVisible(find.text('Mark Scheme as Complete'));
        await tester.tap(find.text('Mark Scheme as Complete'));
        await tester.pumpAndSettle();

        expect(fakeRepo.recordedPayloads.length, 1);
        expect(fakeRepo.recordedPayloads.single.status, 'Complete');
        expect(fakeRepo.recordedPayloads.single.submissionDate, '2026-11-05');
      },
    );

    testWidgets(
      'RecordFollowupSheet Complete status renders without overflow on 320px narrow width',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeFollowupRepository();

        await tester.pumpWidget(
          _wrapTestApp(
            Scaffold(
              body: RecordFollowupSheet(
                beneficiaryId: 1,
                beneficiaryName: 'af',
                schemeId: 10,
                schemeName: 'Pradhan Mantri Suraksha Bima Yojana (PMSBY)',
                existingFollowup: const SchemeFollowupDetail(
                  id: 102,
                  status: 'Applied',
                  submissionDate: '2026-11-05',
                ),
                repository: fakeRepo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Benefit Disbursement Confirmation'), findsOneWidget);
        expect(find.textContaining('Benefit Received Date:'), findsOneWidget);
        expect(find.text('Mark Scheme as Complete'), findsOneWidget);
      },
    );

    testWidgets(
      'BeneficiaryFollowupScreen disables Completed scheme button and blocks reopening follow-up',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeFollowupRepository();

        await tester.pumpWidget(
          _wrapTestApp(
            BeneficiaryFollowupScreen(
              beneficiaryId: 1,
              beneficiaryName: 'Sita Devi',
              repository: fakeRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Complete scheme shows 'Completed' and its button has onPressed == null
        expect(find.text('Completed'), findsOneWidget);
        final completedButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Completed'),
            matching: find.byWidgetPredicate((w) => w is ElevatedButton),
          ),
        );
        expect(completedButton.onPressed, isNull);

        // Tapping Completed text must NOT open RecordFollowupSheet
        await tester.tap(find.text('Completed'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(
          find.text('Has the beneficiary applied for this scheme?'),
          findsNothing,
        );

        // Tapping Track Benefit / Update on Applied scheme DOES open sheet with Complete-only
        await tester.tap(find.text('Track Benefit / Update'));
        await tester.pumpAndSettle();
        expect(
          find.text('Has the beneficiary applied for this scheme?'),
          findsOneWidget,
        );
        expect(find.text('Benefit Disbursement Confirmation'), findsOneWidget);

        await tester.tap(find.text('Not Applied'));
        await tester.pumpAndSettle();
        expect(find.text('Reason for Delay / Not Applied'), findsNothing);
      },
    );

    testWidgets(
      'FollowupHubScreen disables Complete register card follow-up button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakeFollowupRepository();

        await tester.pumpWidget(
          _wrapTestApp(FollowupHubScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        // Complete card shows disabled 'Completed' button and tapping it does not open RecordFollowupSheet
        final hubCompletedBtn = find.ancestor(
          of: find.text('Completed'),
          matching: find.byWidgetPredicate((w) => w is ElevatedButton),
        );
        expect(hubCompletedBtn, findsOneWidget);
        expect(
          tester.widget<ElevatedButton>(hubCompletedBtn).onPressed,
          isNull,
        );
        await tester.tap(hubCompletedBtn, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(BeneficiaryFollowupScreen), findsNothing);
        expect(
          find.text('Has the beneficiary applied for this scheme?'),
          findsNothing,
        );

        // Applied card still shows Take Follow-up and opens RecordFollowupSheet in Complete-only mode
        await tester.scrollUntilVisible(
          find.text('Take Follow-up'),
          250,
          scrollable: find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ).first,
        );
        expect(find.text('Take Follow-up'), findsOneWidget);
        await tester.tap(find.text('Take Follow-up'));
        await tester.pumpAndSettle();
        expect(
          find.text('Has the beneficiary applied for this scheme?'),
          findsOneWidget,
        );
        expect(find.text('Benefit Disbursement Confirmation'), findsOneWidget);
      },
    );

    test('Follow-up register excludes schemes marked as already applied in survey and adjusts pending count', () async {
      SharedPreferences.setMockInitialValues({});

      const beneficiaryId = 222;
      const beneficiaryCode = 'JK-UP-2026-000222';

      // Initially user marks 2 schemes as already applied in the survey
      await StorageService.saveAppliedSchemeCodes(
        beneficiaryId,
        {'JK-SCH-0016', 'JK-SCH-0010'},
        beneficiaryCode,
      );

      final excludedKeys = await StorageService.getGlobalExcludedFollowupKeys();
      expect(excludedKeys, contains('JK-UP-2026-000222_JK-SCH-0016'));
      expect(excludedKeys, contains('JK-UP-2026-000222_JK-SCH-0010'));

      final unsyncedCount = await StorageService.getUnsyncedPendingExclusionCount();
      expect(unsyncedCount, 2);

      // Create a mock register with 4 schemes for abcdef (like in the user's scenario)
      final allRegisterItems = [
        const FollowupRegisterItem(
          followupId: 1,
          beneficiaryId: beneficiaryId,
          beneficiaryCode: beneficiaryCode,
          beneficiaryName: 'abcdef',
          schemeId: 8,
          schemeCode: 'JK-SCH-0008',
          schemeName: 'Women Helpline Number 181 scheme',
          status: 'Pending',
        ),
        const FollowupRegisterItem(
          followupId: 2,
          beneficiaryId: beneficiaryId,
          beneficiaryCode: beneficiaryCode,
          beneficiaryName: 'abcdef',
          schemeId: 16,
          schemeCode: 'JK-SCH-0016',
          schemeName: "NALSA's Compensation Scheme",
          status: 'Pending',
        ),
        const FollowupRegisterItem(
          followupId: 3,
          beneficiaryId: beneficiaryId,
          beneficiaryCode: beneficiaryCode,
          beneficiaryName: 'abcdef',
          schemeId: 10,
          schemeCode: 'JK-SCH-0010',
          schemeName: 'Ayushman Bharat',
          status: 'Pending',
        ),
        const FollowupRegisterItem(
          followupId: 4,
          beneficiaryId: beneficiaryId,
          beneficiaryCode: beneficiaryCode,
          beneficiaryName: 'abcdef',
          schemeId: 46,
          schemeCode: 'JK-SCH-0046',
          schemeName: 'Swadhar Greh',
          status: 'Pending',
        ),
      ];

      // Filtering with StorageService:
      final filteredItems = allRegisterItems
          .where((it) => !StorageService.isFollowupItemExcluded(it, excludedKeys))
          .toList();

      // Only the 2 schemes that the user did not mark as applied are kept for follow-up tracking!
      expect(filteredItems.length, 2);
      expect(filteredItems.map((e) => e.schemeCode), containsAll(['JK-SCH-0008', 'JK-SCH-0046']));
      expect(filteredItems.map((e) => e.schemeCode), isNot(contains('JK-SCH-0016')));
      expect(filteredItems.map((e) => e.schemeCode), isNot(contains('JK-SCH-0010')));

      // Pending metric calculation:
      // Server returned 86 (all 4 included). App deducts 2 unsynced applied schemes -> 84!
      const serverPending = 86;
      final adjustedPending = (serverPending - unsyncedCount).clamp(0, double.infinity).toInt();
      expect(adjustedPending, 84);
    });

    test('StorageService auto-discovers pre-existing applied schemes preferences for global exclusion', () async {
      // Simulating pre-existing storage from an earlier app session
      SharedPreferences.setMockInitialValues({
        'applied_schemes_code_JK-UP-2026-000222': ['JK-SCH-0016', 'JK-SCH-0010'],
      });

      final discoveredKeys = await StorageService.getGlobalExcludedFollowupKeys();
      expect(discoveredKeys, contains('JK-UP-2026-000222_JK-SCH-0016'));
      expect(discoveredKeys, contains('JK-UP-2026-000222_JK-SCH-0010'));

      final unsyncedCount = await StorageService.getUnsyncedPendingExclusionCount();
      expect(unsyncedCount, 2);

      // Mark 1 as synced
      await StorageService.markCanonicalFollowupSynced('JK-UP-2026-000222', 'JK-SCH-0016');
      final remainingUnsynced = await StorageService.getUnsyncedPendingExclusionCount();
      expect(remainingUnsynced, 1);
    });
  });
}
