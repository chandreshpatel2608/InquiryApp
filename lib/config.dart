import 'package:flutter/material.dart';

// API endpoint. Override at build/run time WITHOUT editing this file:
//   flutter run   --dart-define=API_BASE_URL=https://10.0.2.2:7076/digitalcard/api
//   flutter build --dart-define=API_BASE_URL=https://devalllp.in/digitalcard/api
// Common values:
//   Android emulator -> local PC : https://10.0.2.2:7076/digitalcard/api
//   iOS simulator    -> local    : https://localhost:7076/digitalcard/api
//   Real device (same Wi-Fi)     : https://<your-PC-IP>:7076/digitalcard/api
const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://devalllp.in/digitalcard/api',
);

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
