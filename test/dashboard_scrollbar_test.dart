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
      'Dashboard home hides visible scrollbar while keeping vertical scrolling active',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(411, 540)),
        child: MaterialApp(
          // Use a desktop target platform where MaterialScrollBehavior
          // normally inserts a visible Scrollbar by default.
          theme: ThemeData(platform: TargetPlatform.windows),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pump();

    final scrollViewFinder = find.descendant(
      of: find.byType(DashboardScreen),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollViewFinder, findsOneWidget);

    // Confirm neither Scrollbar nor RawScrollbar is built on Dashboard home.
    expect(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(Scrollbar),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(RawScrollbar),
      ),
      findsNothing,
    );

    // Confirm scrolling still works normally when content overflows viewport.
    final scrollableFinder = find
        .descendant(
          of: scrollViewFinder,
          matching: find.byType(Scrollable),
        )
        .first;
    final scrollableState = tester.state<ScrollableState>(scrollableFinder);
    expect(scrollableState.position.maxScrollExtent, greaterThan(0.0));
    expect(scrollableState.position.pixels, equals(0.0));

    await tester.drag(scrollViewFinder, const Offset(0, -180));
    await tester.pump();

    expect(scrollableState.position.pixels, greaterThan(0.0));

    await tester.pump(const Duration(milliseconds: 50));
  });
}
