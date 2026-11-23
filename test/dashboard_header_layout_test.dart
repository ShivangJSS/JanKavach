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
      'Dashboard dark green header starts at top edge and keeps icons below status bar',
      (WidgetTester tester) async {
    const double statusBarHeight = 36.0;
    const double navBarHeight = 24.0;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(411, 915),
          padding: EdgeInsets.only(top: statusBarHeight, bottom: navBarHeight),
        ),
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pump();

    // Find the dark green header container (decoration color 0xFF06452D)
    final headerContainerFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFF06452D),
    );
    expect(headerContainerFinder, findsOneWidget);

    final headerRect = tester.getRect(headerContainerFinder);
    // Header container starts flush at y = 0 (no white gap above it)
    expect(headerRect.top, equals(0.0));

    // Menu icon and Sync icon inside the header must remain below statusBarHeight
    final menuRect = tester.getRect(find.byIcon(Icons.menu));
    expect(menuRect.top, greaterThanOrEqualTo(statusBarHeight));

    final syncRect = tester.getRect(find.byIcon(Icons.sync_rounded));
    expect(syncRect.top, greaterThanOrEqualTo(statusBarHeight));

    // Header height preserves statusBarHeight + original header content height (78px)
    expect(headerRect.height, equals(statusBarHeight + 78.0));

    // Dashboard tab IndexedStack must have top SafeArea padding stripped (top == 0)
    final dashboardStackFinder = find
        .descendant(
          of: find.byType(DashboardScreen),
          matching: find.byType(IndexedStack),
        )
        .first;
    final indexedStackContext = tester.element(dashboardStackFinder);
    expect(MediaQuery.paddingOf(indexedStackContext).top, equals(0.0));

    // Wait briefly for initial async timers to settle cleanly if any
    await tester.pump(const Duration(milliseconds: 50));
  });
}
