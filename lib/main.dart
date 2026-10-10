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
    const brandColor = Color(0xFF914B36);
    const pageColor = Color(0xFFFFF9F6);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: Brightness.light,
      surface: pageColor,
    );

    return MaterialApp(
      title: 'Rudra Technology',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: pageColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: pageColor,
          foregroundColor: Color(0xFF241E1C),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: pageColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: brandColor, width: 1.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: pageColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brandColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brandColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brandColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF914B36),
          contentTextStyle: TextStyle(color: Colors.white),
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
