import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    return MaterialApp(
      title: 'Jan Kavach',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
      ),

      home: isLoggedIn ? const DashboardScreen() : const WelcomeScreen(),
    );
  }
}