import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'screens/customer_storefront_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const DukanSmartApp());
}

class DukanSmartApp extends StatelessWidget {
  const DukanSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     title: 'Devalllp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFF6B35),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('saved_user');

    if (!mounted) return;

    if (userData != null) {
      final user = jsonDecode(userData) as Map<String, dynamic>;
      final userId = user['userId'] as int?;

      // Verify with server that user is still active + get fresh data
      if (userId != null) {
        final freshData = await ApiService.verifyUser(userId);
        if (!mounted) return;

        if (freshData == null) {
          // Keep the saved session when the API is temporarily unavailable.
          appLogoPath = user['logoPath'] as String?;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen(userData: user)),
          );
          return;
        }

        // Update saved data with fresh info (logo, businessName, etc.)
        await prefs.setString('saved_user', jsonEncode(freshData));
        appLogoPath = freshData['logoPath'] as String?;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(userData: freshData)),
        );
      } else {
        await prefs.remove('saved_user');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerStorefrontScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerStorefrontScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
