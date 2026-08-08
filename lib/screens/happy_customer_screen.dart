import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';

class HappyCustomerScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HappyCustomerScreen({super.key, required this.userData});

  @override
  State<HappyCustomerScreen> createState() => _HappyCustomerScreenState();
}

class _HappyCustomerScreenState extends State<HappyCustomerScreen> {
  File? _photo;
  String _businessName = '';
  String? _tagLine;
  String? _phone;
  final _customerNameCtrl = TextEditingController();
  int _selectedTheme = 0;
  bool _loading = true;
  bool _saving = false;
  final _repaintKey = GlobalKey();

  int get _userId => widget.userData['userId'];

  static const _themes = [
    _PhotoTheme('Royal Blue',   Color(0xFF0D47A1), Color(0xFF1565C0), Colors.white,       Color(0xFFFFD600)),
    _PhotoTheme('Emerald',      Color(0xFF1B5E20), Color(0xFF2E7D32), Colors.white,       Color(0xFFFFEB3B)),
    _PhotoTheme('Royal Gold',   Color(0xFF3E2723), Color(0xFF4E342E), Color(0xFFFFD54F),  Colors.white),
    _PhotoTheme('Crimson',      Color(0xFFB71C1C), Color(0xFFC62828), Colors.white,       Color(0xFFFFD600)),
    _PhotoTheme('Purple Glam',  Color(0xFF4A148C), Color(0xFF6A1B9A), Colors.white,       Color(0xFFFF80AB)),
    _PhotoTheme('Dark Bold',    Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFFE94560),  Colors.white),
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  Future<void> _loadCompanyInfo() async {
    try {
      final info = await ApiService.getCompanyInfoForPhoto(_userId);
      if (info != null && mounted) {
        setState(() {
          _businessName = info['businessName'] ?? 'My Business';
          _tagLine = info['tagLine'];
          _phone = info['phone'];
          _loading = false;
        });
      } else if (mounted) {
        setState(() { _businessName = widget.userData['businessName'] ?? 'My Business'; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _businessName = widget.userData['businessName'] ?? 'My Business'; _loading = false; });
    }
  }

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1080, imageQuality: 90);
    if (picked != null && mounted) setState(() => _photo = File(picked.path));
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080, imageQuality: 90);
    if (picked != null && mounted) setState(() => _photo = File(picked.path));
  }

  Future<Uint8List?> _captureImage() async {
    try {
      // Ensure frame is rendered before capture
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) { return null; }
  }

  Future<void> _saveAndShare({bool whatsapp = false}) async {
    if (_photo == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureImage();
      if (bytes == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate image'))); return; }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/happy_customer_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      final text = '😊 Happy Customer at $_businessName! ⭐\n${_customerNameCtrl.text.trim().isNotEmpty ? 'Thank you ${_customerNameCtrl.text.trim()}! 🙏\n' : ''}${_phone != null ? '📞 $_phone' : ''}';
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadImage() async {
    if (_photo == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureImage();
      if (bytes == null) return;
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final fileName = 'HappyCustomer_${_businessName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $fileName'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themes[_selectedTheme];
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Happy Customer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_photo == null) ...[
                    // Capture photo card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          Icon(Icons.camera_alt, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text('Capture Customer Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Take a photo of your happy customer', style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(child: FilledButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt), label: const Text('Camera'),
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)))),
                            const SizedBox(width: 10),
                            Expanded(child: OutlinedButton.icon(onPressed: _pickFromGallery, icon: const Icon(Icons.photo_library), label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)))),
                          ]),
                        ]),
                      ),
                    ),
                  ] else ...[
                    // Customer name
                    TextField(
                      controller: _customerNameCtrl,
                      decoration: InputDecoration(labelText: 'Customer Name (optional)', prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Theme selector
                    const Text('Choose Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _themes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final t = _themes[i];
                          final sel = _selectedTheme == i;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedTheme = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [t.primary, t.secondary]),
                                borderRadius: BorderRadius.circular(25),
                                border: sel ? Border.all(color: Colors.white, width: 2) : null,
                                boxShadow: sel ? [BoxShadow(color: t.primary.withAlpha(120), blurRadius: 8, offset: const Offset(0, 2))] : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(t.name, style: TextStyle(color: t.textColor, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // FRAMED IMAGE — branding outside the photo, not on face
                    RepaintBoundary(
                      key: _repaintKey,
                      child: _buildFramedImage(theme),
                    ),
                    const SizedBox(height: 12),

                    // Change photo buttons
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Retake', style: TextStyle(fontSize: 13)))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: _pickFromGallery, icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Gallery', style: TextStyle(fontSize: 13)))),
                    ]),
                    const SizedBox(height: 16),

                    // Share buttons
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: _saving ? null : () => _saveAndShare(whatsapp: true),
                      icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.message),
                      label: const Text('Share via WhatsApp'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    )),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: FilledButton.icon(onPressed: _saving ? null : () => _saveAndShare(),
                        icon: const Icon(Icons.share, size: 18), label: const Text('Share', style: TextStyle(fontSize: 13)),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : _downloadImage,
                        icon: const Icon(Icons.download, size: 18), label: const Text('Download', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)))),
                    ]),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }

  /// Frame layout: TOP BANNER → PHOTO (untouched) → BOTTOM BANNER
  /// Nothing overlaps the photo/person's face
  Widget _buildFramedImage(_PhotoTheme theme) {
    final customerName = _customerNameCtrl.text.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: theme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══ TOP BANNER — Company name + Happy Customer ═══
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primary, theme.secondary]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company name
                  Text(
                    _businessName.toUpperCase(),
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Happy Customer + customer name row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '😊 Happy Customer!',
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      if (customerName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customerName,
                            style: TextStyle(
                              color: theme.textColor.withAlpha(220),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.accent.withAlpha(180),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'THANK YOU\nFOR TRUSTING US',
                          style: TextStyle(color: theme.primary, fontSize: 7, fontWeight: FontWeight.w800, height: 1.2),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ═══ PHOTO — completely untouched, no overlays ═══
            AspectRatio(
              aspectRatio: 1.0,
              child: Image.file(_photo!, fit: BoxFit.cover, width: double.infinity),
            ),

            // ═══ BOTTOM BANNER — Branding + Contact ═══
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.secondary, theme.primary]),
              ),
              child: Row(
                children: [
                  // Left: tagline + phone
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_tagLine != null && _tagLine!.isNotEmpty)
                          Text(_tagLine!, style: TextStyle(color: theme.textColor.withAlpha(200), fontSize: 10),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (_phone != null)
                          Row(children: [
                            Icon(Icons.verified, size: 12, color: theme.accent),
                            const SizedBox(width: 4),
                            Text('📞 $_phone', style: TextStyle(color: theme.textColor.withAlpha(200), fontSize: 11)),
                          ]),
                      ],
                    ),
                  ),
                  // Right: company name badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '📍 ${_businessName.toUpperCase()}',
                      style: TextStyle(color: theme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final Color textColor;
  final Color accent;
  const _PhotoTheme(this.name, this.primary, this.secondary, this.textColor, this.accent);
}
