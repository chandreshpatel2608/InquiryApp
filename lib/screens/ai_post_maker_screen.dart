import 'package:flutter/material.dart';
import '../config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/api_service.dart';

class AiPostMakerScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AiPostMakerScreen({super.key, required this.userData});

  @override
  State<AiPostMakerScreen> createState() => _AiPostMakerScreenState();
}

class _AiPostMakerScreenState extends State<AiPostMakerScreen> {
  List<File> _selectedImages = [];
  bool _loading = true;
  List<String> _gujaratiCaptions = [];
  List<String> _englishCaptions = [];
  List<String> _hashtags = [];
  String? _selectedCaption;
  final _customMsgCtrl = TextEditingController();
  String _category = 'other';

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _speechLocale = 'gu_IN'; // Default Gujarati

  @override
  void initState() {
    super.initState();
    _category = widget.userData['businessCategory'] ?? 'other';
    _loadCaptions();
    _initSpeech();
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

  @override
  void dispose() {
    _speech.stop();
    _customMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCaptions() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.generateAiPost(
        _category,
        widget.userData['businessName'] ?? 'My Business',
      );
      if (result != null && mounted) {
        setState(() {
          _gujaratiCaptions = List<String>.from(result['gujaratiCaptions'] ?? []);
          _englishCaptions = List<String>.from(result['englishCaptions'] ?? []);
          _hashtags = List<String>.from(result['hashtags'] ?? []);
          // Add SEO keywords as hashtags
          final seoKeywords = widget.userData['seoKeywords'] as String?;
          if (seoKeywords != null && seoKeywords.isNotEmpty) {
            for (final kw in seoKeywords.split(',')) {
              final tag = '#${kw.trim().replaceAll(' ', '')}';
              if (tag.length > 1 && !_hashtags.contains(tag)) {
                _hashtags.add(tag);
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(maxWidth: 1080, imageQuality: 85);
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _selectedImages = picked.map((x) => File(x.path)).toList();
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1080, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _selectedImages.add(File(picked.path)));
    }
  }

  String _buildPostText() {
    final caption = _selectedCaption ?? '';
    final tags = _hashtags.join(' ');
    final custom = _customMsgCtrl.text.trim();
    final parts = <String>[
      if (custom.isNotEmpty) custom,
      caption,
      '',
      tags,
    ];
    return parts.join('\n');
  }

  Future<void> _shareViaWhatsApp() async {
    final text = _buildPostText();
    if (_selectedImages.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(
          files: _selectedImages.map((f) => XFile(f.path)).toList(),
          text: text,
        ),
      );
    } else {
      final url = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    }
  }

  Future<void> _shareToSocial() async {
    final text = _buildPostText();
    if (_selectedImages.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(
          files: _selectedImages.map((f) => XFile(f.path)).toList(),
          text: text,
        ),
      );
    } else {
      await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('AI Post Maker'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Upload Images (multiple)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Upload Photos',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          if (_selectedImages.isEmpty)
                            GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Tap to select photos', style: TextStyle(color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length + 1,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  if (i == _selectedImages.length) {
                                    return GestureDetector(
                                      onTap: _pickImages,
                                      child: Container(
                                        width: 100, height: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey[300]!),
                                        ),
                                        child: Icon(Icons.add, size: 32, color: Colors.grey[400]),
                                      ),
                                    );
                                  }
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(_selectedImages[i], width: 100, height: 120, fit: BoxFit.cover),
                                      ),
                                      Positioned(top: 2, right: 2, child: GestureDetector(
                                        onTap: () => setState(() => _selectedImages.removeAt(i)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      )),
                                    ],
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Gallery', style: TextStyle(fontSize: 13)),
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton.icon(
                              onPressed: _pickFromCamera,
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Camera', style: TextStyle(fontSize: 13)),
                            )),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Custom message
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Message (optional)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Gujarati captions
                  if (_gujaratiCaptions.isNotEmpty) ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gujarati Captions',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            ..._gujaratiCaptions.map((cap) => ListTile(
                              dense: true,
                              leading: Icon(
                                _selectedCaption == cap ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: _selectedCaption == cap ? Theme.of(context).colorScheme.primary : Colors.grey,
                                size: 22,
                              ),
                              title: Text(cap, style: const TextStyle(fontSize: 13)),
                              onTap: () => setState(() => _selectedCaption = cap),
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // English captions
                  if (_englishCaptions.isNotEmpty) ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('English Captions',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            ..._englishCaptions.map((cap) => ListTile(
                              dense: true,
                              leading: Icon(
                                _selectedCaption == cap ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: _selectedCaption == cap ? Theme.of(context).colorScheme.primary : Colors.grey,
                                size: 22,
                              ),
                              title: Text(cap, style: const TextStyle(fontSize: 13)),
                              onTap: () => setState(() => _selectedCaption = cap),
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Hashtags
                  if (_hashtags.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: Colors.grey[50],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hashtags (${_hashtags.length})',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4, runSpacing: 2,
                              children: _hashtags.map((tag) => Text(
                                tag,
                                style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Share buttons
                  if (_selectedCaption != null) ...[
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: _shareViaWhatsApp,
                      icon: const Icon(Icons.message, size: 20),
                      label: const Text('Send via WhatsApp'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: FilledButton.icon(
                        onPressed: _shareToSocial,
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share', style: TextStyle(fontSize: 13)),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.icon(
                        onPressed: _shareToSocial,
                        icon: const Icon(Icons.facebook, size: 18),
                        label: const Text('Facebook', style: TextStyle(fontSize: 13)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      )),
                    ]),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }
}
