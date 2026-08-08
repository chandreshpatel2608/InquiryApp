import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/api_service.dart';
import '../config.dart';

class DigitalCardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DigitalCardScreen({super.key, required this.userData});

  @override
  State<DigitalCardScreen> createState() => _DigitalCardScreenState();
}

class _DigitalCardScreenState extends State<DigitalCardScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  final _customMsgCtrl = TextEditingController();

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _speechLocale = 'gu_IN'; // Default Gujarati

  int get _userId => widget.userData['userId'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _customMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _customMsgCtrl.text = result.recognizedWords;
              _customMsgCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _customMsgCtrl.text.length),
              );
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(partialResults: true, localeId: _speechLocale),
      );
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await ApiService.getCardProfile(_userId);
      if (mounted) setState(() { _profile = profile; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String get _siteBase => baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '');

  String get _cardUrl {
    final slug = _profile?['slug'] ?? '';
    if (slug.isEmpty) return '';
    return '$_siteBase/card/$slug';
  }

  Future<void> _openInBrowser() async {
    if (_cardUrl.isEmpty) return;
    final uri = Uri.parse(_cardUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _buildShareText() {
    final businessName = _profile?['businessName'] ?? 'My Business';
    final custom = _customMsgCtrl.text.trim();
    final parts = <String>[
      if (custom.isNotEmpty) custom,
      'Check out $businessName\'s Digital Visiting Card:',
      _cardUrl,
    ];
    return parts.join('\n');
  }

  /// Download logo and share it as image attachment with text
  Future<File?> _downloadLogo() async {
    final logoPath = _profile?['logoPath'] as String?;
    if (logoPath == null || logoPath.isEmpty) return null;
    try {
      final url = '$_siteBase$logoPath';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final ext = logoPath.contains('.png') ? '.png' : '.jpg';
        final file = File('${dir.path}/logo_share$ext');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _shareWithLogo({bool whatsappOnly = false}) async {
    if (_cardUrl.isEmpty) return;
    final text = _buildShareText();
    final logo = await _downloadLogo();

    if (logo != null) {
      // Share with logo image
      await SharePlus.instance.share(ShareParams(files: [XFile(logo.path)], text: text));
    } else if (whatsappOnly) {
      final url = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } else {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  Future<void> _shareViaWhatsApp() async => _shareWithLogo(whatsappOnly: true);
  Future<void> _shareToFacebook() async => _shareWithLogo();
  Future<void> _shareToInstagram() async => _shareWithLogo();
  Future<void> _shareGeneral() async => _shareWithLogo();

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$_siteBase$path';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Digital Visiting Card'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(
                  child: Text('Card profile not found',
                      style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Preview
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            // Banner
                            if (_profile!['bannerPath'] != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: _getImageUrl(_profile!['bannerPath']),
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [cs.primary, cs.primaryContainer],
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [cs.primary, cs.primaryContainer],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                ),
                              ),
                            // Logo & Business Info
                            Transform.translate(
                              offset: const Offset(0, -30),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                    ),
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundColor: cs.primaryContainer,
                                      backgroundImage:
                                          _profile!['logoPath'] != null
                                              ? NetworkImage(_getImageUrl(
                                                  _profile!['logoPath']))
                                              : null,
                                      child: _profile!['logoPath'] == null
                                          ? Icon(Icons.business,
                                              color: cs.primary, size: 30)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _profile!['businessName'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_profile!['tagLine'] != null)
                                    Text(_profile!['tagLine'],
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13),
                                        textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                            // Contact info
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: [
                                  if (_profile!['phone'] != null)
                                    _infoRow(Icons.phone, _profile!['phone']),
                                  if (_profile!['email'] != null)
                                    _infoRow(Icons.email, _profile!['email']),
                                  if (_profile!['address'] != null)
                                    _infoRow(Icons.location_on,
                                        _profile!['address']),
                                  if (_profile!['website'] != null)
                                    _infoRow(Icons.language,
                                        _profile!['website']),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Card URL
                      if (_cardUrl.isNotEmpty)
                        Card(
                          elevation: 0,
                          color: cs.primaryContainer.withAlpha(60),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: _openInBrowser,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_cardUrl,
                                        style: TextStyle(
                                            color: cs.primary,
                                            fontSize: 13,
                                            decoration:
                                                TextDecoration.underline)),
                                  ),
                                  const Icon(Icons.open_in_new, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Custom message
                      const Text('Your Message (optional)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Language: ', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('ગુજરાતી', style: TextStyle(fontSize: 11)),
                            selected: _speechLocale == 'gu_IN',
                            onSelected: (_) => setState(() => _speechLocale = 'gu_IN'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('English', style: TextStyle(fontSize: 11)),
                            selected: _speechLocale == 'en_IN',
                            onSelected: (_) => setState(() => _speechLocale = 'en_IN'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('हिन्दी', style: TextStyle(fontSize: 11)),
                            selected: _speechLocale == 'hi_IN',
                            onSelected: (_) => setState(() => _speechLocale = 'hi_IN'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customMsgCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Listening...' : 'Type or speak your message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: _isListening
                                ? const BorderSide(color: Colors.red, width: 2)
                                : const BorderSide(),
                          ),
                          prefixIcon: const Icon(Icons.message_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? Colors.red : null,
                            ),
                            onPressed: _toggleListening,
                            tooltip: _isListening ? 'Stop listening' : 'Speak',
                          ),
                        ),
                      ),
                      if (_isListening)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[400]),
                              ),
                              const SizedBox(width: 6),
                              Text('Listening... speak now',
                                  style: TextStyle(fontSize: 11, color: Colors.red[400])),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Share buttons
                      const Text('Share Your Card',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),

                      // WhatsApp
                      _shareButton(
                        icon: Icons.message,
                        label: 'Share via WhatsApp',
                        color: Colors.green,
                        onTap: _shareViaWhatsApp,
                      ),
                      const SizedBox(height: 8),
                      // Facebook
                      _shareButton(
                        icon: Icons.facebook,
                        label: 'Share to Facebook',
                        color: Colors.blue[800]!,
                        onTap: _shareToFacebook,
                      ),
                      const SizedBox(height: 8),
                      // Instagram
                      _shareButton(
                        icon: Icons.camera_alt,
                        label: 'Share to Instagram',
                        color: Colors.purple,
                        onTap: _shareToInstagram,
                      ),
                      const SizedBox(height: 8),
                      // General share
                      _shareButton(
                        icon: Icons.share,
                        label: 'Share via...',
                        color: Colors.grey[700]!,
                        onTap: _shareGeneral,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
        ],
      ),
    );
  }

  Widget _shareButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: color.withAlpha(100)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
