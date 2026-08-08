import 'package:flutter/material.dart';

// Change this to your server IP/URL when running on a real device.
// For Android emulator use 10.0.2.2, for iOS simulator use localhost.
// For real device on same WiFi, use your PC's IP (run ipconfig to find it).
const String baseUrl = 'https://rudratechnology.co.in/digitalcard/api';

/// Global company logo path — set after login from userData['logoPath'].
String? appLogoPath;

/// Builds an AppBar title row with the company logo on the left.
Widget appBarTitle(String title) {
  final logoUrl = (appLogoPath != null && appLogoPath!.isNotEmpty)
      ? '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$appLogoPath'
      : null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: logoUrl != null
            ? Image.network(logoUrl, width: 30, height: 30, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: 30, height: 30, fit: BoxFit.contain))
            : Image.asset('assets/logo.png', width: 30, height: 30, fit: BoxFit.contain),
      ),
      const SizedBox(width: 8),
      Flexible(child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis)),
    ],
  );
}
