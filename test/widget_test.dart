import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kavach/main.dart';
import 'package:kavach/viewModels/login_viewmodel.dart';
import 'package:kavach/viewModels/welcome_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App initializes and renders welcome screen smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => WelcomeViewModel()),
          ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ],
        child: const MyApp(isLoggedIn: false),
      ),
    );

    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
