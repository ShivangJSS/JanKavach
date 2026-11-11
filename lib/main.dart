import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization/app_localizations.dart';
import 'data/providers/language_provider.dart';
import 'data/services/connectivity_sync_service.dart';
import 'data/services/storage_service.dart';

import 'viewModels/login_viewmodel.dart';
import 'viewModels/welcome_viewmodel.dart';

import 'views/dashboard_screen/dashboard_screen.dart';
import 'views/welcome_screen/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConnectivitySyncService.instance.start();

  final bool isLoggedIn = await StorageService.isLoggedIn();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WelcomeViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => LoginViewModel(),
        ),
      ],
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({
    super.key,
    this.isLoggedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      title: 'Jan Kavach',
      debugShowCheckedModeBanner: false,

      // Active locale from provider (en, hi, as)
      locale: languageProvider.currentLocale,

      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi (हिन्दी)
        Locale('as'), // Assamese (অসমীয়া)
      ],

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: true,
      ),

      home: isLoggedIn ? const DashboardScreen() : const WelcomeScreen(),
    );
  }
}
