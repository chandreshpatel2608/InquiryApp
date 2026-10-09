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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF168CC4),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Rudra Technology',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7FA),
          foregroundColor: Color(0xFF173247),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9E3EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
