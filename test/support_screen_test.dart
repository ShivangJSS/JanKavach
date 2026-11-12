import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/core/localization/app_localizations.dart';
import 'package:kavach/views/support_screen/support_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSupportScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    rootBundle.clear();
    await tester.pumpWidget(
      MaterialApp(
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
        home: const Scaffold(
          body: SupportScreen(),
        ),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      if (tester.any(find.text(SupportScreen.demoPartnerPhone))) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'SupportScreen renders supporting partner demo contact and copies mobile number',
    (WidgetTester tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedText = args['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await pumpSupportScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Support Center'), findsOneWidget);
      expect(find.text('Supporting Partner'), findsOneWidget);
      expect(find.text(SupportScreen.demoPartnerPhone), findsOneWidget);
      expect(find.text('Call Now'), findsOneWidget);
      expect(find.text('Copy Number'), findsOneWidget);

      await tester.tap(find.text('Copy Number'));
      await tester.pumpAndSettle();

      expect(copiedText, equals(SupportScreen.demoPartnerPhone));
      expect(find.text('Support mobile number copied.'), findsOneWidget);
    },
  );
}
