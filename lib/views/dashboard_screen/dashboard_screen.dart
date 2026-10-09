import 'package:flutter/material.dart';

import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _expireToken() async {
    await StorageService.saveAccessToken(
      "invalid_token",
    );

    print("Access Token changed to invalid_token");
  }

  Future<void> _testProtectedApi() async {
    try {
      final response = await ApiService().dio.get(
        "/dashboard", // Replace with your actual protected API
      );

      print("API Success");
      print(response.data);
    } catch (e) {
      print("API Failed");
      print(e);
    }
  }

  Future<void> _showStoredTokens() async {
    final accessToken =
    await StorageService.getAccessToken();

    final refreshToken =
    await StorageService.getRefreshToken();

    print("=========== TOKENS ===========");
    print("Access Token:");
    print(accessToken);

    print("Refresh Token:");
    print(refreshToken);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [

              const Text(
                "Dashboard",
                style: TextStyle(
                  fontSize: 24,
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _showStoredTokens,
                child: const Text(
                  "Show Tokens",
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _expireToken,
                child: const Text(
                  "Expire Access Token",
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _testProtectedApi,
                child: const Text(
                  "Test Protected API",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}