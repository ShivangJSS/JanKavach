import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/core/localization/app_localizations.dart';
import 'package:kavach/views/widgets/app_bottom_navigation_bar.dart';

Widget _wrapWithLocale(Widget child) {
  return MaterialApp(
    key: UniqueKey(),
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('hi'), Locale('as')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

Future<void> _pumpLocalizedWidget(WidgetTester tester, Widget child) async {
  rootBundle.clear();
  await tester.pumpWidget(_wrapWithLocale(child));
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppBottomNavigationBar renders 4 tabs and invokes callbacks', (tester) async {
    int? tappedIndex;

    await _pumpLocalizedWidget(
      tester,
      Scaffold(
        body: const SizedBox(),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: 1,
          onTabSelected: (index) {
            tappedIndex = index;
          },
        ),
      ),
    );

    // Verify icons exist
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);
    expect(find.byIcon(Icons.support_agent_rounded), findsOneWidget);

    // Tap Home tab (index 0)
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(tappedIndex, equals(0));
  });

  testWidgets('AppNavigationController.navigateToTab updates activeTab and pops child routes', (tester) async {
    AppNavigationController.activeTab.value = 1;

    await _pumpLocalizedWidget(
      tester,
      Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: Text('Child Screen Content'),
                        bottomNavigationBar: AppBottomNavigationBar(currentIndex: 1),
                      ),
                    ),
                  );
                },
                child: const Text('Open Child'),
              ),
            ),
            bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: AppNavigationController.activeTab,
              builder: (_, current, __) => AppBottomNavigationBar(currentIndex: current),
            ),
          );
        },
      ),
    );

    expect(find.text('Open Child'), findsOneWidget);

    // Open child screen
    await tester.tap(find.text('Open Child'));
    await tester.pumpAndSettle();

    expect(find.text('Child Screen Content'), findsOneWidget);

    // Tap Home icon on child screen's bottom nav bar
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    // Child screen popped back to root
    expect(find.text('Child Screen Content'), findsNothing);
    expect(find.text('Open Child'), findsOneWidget);
    expect(AppNavigationController.activeTab.value, equals(0));
  });
}
