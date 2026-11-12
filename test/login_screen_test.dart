import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/core/localization/app_localizations.dart';
import 'package:kavach/data/providers/language_provider.dart';
import 'package:kavach/viewModels/login_viewmodel.dart';
import 'package:kavach/viewModels/welcome_viewmodel.dart';
import 'package:kavach/views/login_screen/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({Locale locale = const Locale('en')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => WelcomeViewModel()),
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
      ],
      child: MaterialApp(
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
        home: const LoginScreen(),
      ),
    );
  }

  Future<void> pumpLoadedApp(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    rootBundle.clear();
    await tester.pumpWidget(buildTestApp(locale: locale));
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      if (tester.any(find.byType(LoginScreen))) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  Finder findFooterText(String target) => find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            ((widget.data ?? widget.textSpan?.toPlainText())?.contains(target) ??
                false),
      );

  for (final size in const [Size(360, 640), Size(360, 800)]) {
    testWidgets(
      'LoginScreen fits without scrolling at ${size.width.toInt()}x${size.height.toInt()} and shows footer tag & version',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await pumpLoadedApp(tester);

        expect(tester.takeException(), isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(findFooterText('Powered by Indev Consultancy'), findsOneWidget);
        expect(find.text('Version 1.0.0'), findsOneWidget);

        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.maxScrollExtent, equals(0.0));
      },
    );
  }

  testWidgets(
    'LoginScreen renders cleanly in Hindi without overflow or vertical scroll',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'app_language': 'hi'});
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpLoadedApp(tester, locale: const Locale('hi'));

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(findFooterText('Powered by Indev Consultancy'), findsOneWidget);
      expect(find.text('संस्करण 1.0.0'), findsOneWidget);

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, equals(0.0));
    },
  );
}
