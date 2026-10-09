import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'viewModels/login_viewmodel.dart';
import 'viewModels/welcome_viewmodel.dart';

import 'views/welcome_screen/welcome_screen.dart';

void main() {
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
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jan Kavach',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
      ),

      home: const WelcomeScreen(),
    );
  }
}