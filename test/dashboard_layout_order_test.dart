import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/core/localization/app_localizations.dart';
import 'package:kavach/views/dashboard_screen/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactorySqflitePlugin;

    const sqfliteChannel = MethodChannel('com.tekartik.sqflite');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sqfliteChannel, (MethodCall call) async {
      switch (call.method) {
        case 'getDatabasesPath':
          return '.';
        case 'openDatabase':
          return <String, Object?>{'id': 1};
        case 'query':
          return <String, Object?>{
            'columns': ['count'],
            'rows': [
              [0]
            ],
          };
        case 'execute':
        case 'update':
        case 'insert':
        case 'delete':
        case 'closeDatabase':
          return 0;
        case 'options':
          return null;
        default:
          return null;
      }
    });

    const connectivityChannel =
        MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (MethodCall call) async {
      if (call.method == 'check') {
        return ['none'];
      }
      return null;
    });
  });

  testWidgets(
      'Dashboard layout displays Overview first (4 cards), Total Amount Distributed second (1 card), and Quick Actions third (3 cards)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: DashboardScreen(),
      ),
    );

    await tester.pump();

    // Verify User Profile Card is rendered
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Verify Section Finders
    final overviewHeadingFinder = find.text('Overview');
    final totalAmountTitleFinder = find.text('Total Amount Distributed');
    final quickActionsHeadingFinder = find.text('Quick Actions');

    expect(overviewHeadingFinder, findsOneWidget);
    expect(totalAmountTitleFinder, findsOneWidget);
    expect(quickActionsHeadingFinder, findsOneWidget);

    // 1. Verify exact Section Order: Overview FIRST, Total Amount SECOND, Quick Actions THIRD
    final overviewTop = tester.getTopLeft(overviewHeadingFinder).dy;
    final totalAmountTop = tester.getTopLeft(totalAmountTitleFinder).dy;
    final quickActionsTop = tester.getTopLeft(quickActionsHeadingFinder).dy;

    expect(
      overviewTop,
      lessThan(totalAmountTop),
      reason: 'Overview section must appear before Total Amount Distributed card',
    );
    expect(
      totalAmountTop,
      lessThan(quickActionsTop),
      reason: 'Total Amount Distributed card must appear before Quick Actions section',
    );

    // 2. Verify all four Overview cards are present in Overview section
    expect(find.text('Application\nSubmitted'), findsOneWidget);
    expect(find.text('Application\nApproved'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);

    // 3. Verify new Total Amount Distributed card details
    expect(find.text('₹12,50,000'), findsOneWidget);
    expect(
      find.text('Total financial benefits received by beneficiaries.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.currency_rupee_rounded), findsOneWidget);

    // 4. Verify all three Quick Action cards are present in Quick Actions section
    expect(find.text('Register Beneficiary'), findsOneWidget);
    expect(find.text('Check Eligibility'), findsOneWidget);
    expect(find.text('Beneficiary Follow-ups'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
  });
}
