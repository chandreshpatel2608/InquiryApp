import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/api_service.dart';
import '../config.dart';

class FestivalCalendarScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const FestivalCalendarScreen({super.key, required this.userData});

  @override
  State<FestivalCalendarScreen> createState() => _FestivalCalendarScreenState();
}

class _FestivalCalendarScreenState extends State<FestivalCalendarScreen> {
  List<dynamic> _templates = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;

  // Voice recording for the message box
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _speechLocale = 'gu_IN';

  final _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final _categoryColors = <String, Color>{
    'diwali': Colors.amber, 'navratri': Colors.deepOrange, 'valentine': Colors.pink,
    'holi': Colors.purple, 'sankranti': Colors.cyan, 'raksha_bandhan': Colors.red,
    'janmashtami': Colors.blue, 'ganesh': Colors.orange, 'national': Colors.green,
    'new_year': Colors.indigo, 'christmas': Colors.red, 'eid': Colors.teal,
    'mothers_day': Colors.pink, 'fathers_day': Colors.blue, 'womens_day': Colors.purple,
    'rathyatra': Colors.orange, 'guru_purnima': Colors.amber, 'karva_chauth': Colors.pink,
    'onam': Colors.yellow, 'pongal': Colors.orange, 'lohri': Colors.deepOrange,
    'ugadi': Colors.green, 'gudi_padwa': Colors.orange, 'chhath': Colors.amber,
    'dussehra': Colors.red,
  };

  String get _businessName => widget.userData['businessName'] ?? 'My Business';
  int get _userId => widget.userData['userId'];
  String get _apiBase {
    final base = baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '');
    return base;
  }
  @override
  void initState() {
    super.initState();
    _loadData();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize();
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getFestivalCategories(),
        ApiService.getFestivalTemplates(category: _selectedCategory),
      ]);
      if (mounted) {
        setState(() {
          _categories = List<String>.from(results[0]);
          _templates = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final templates = await ApiService.getFestivalTemplates(category: _selectedCategory);
      if (mounted) setState(() { _templates = templates; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return '$_apiBase$path';
  }

  /// Download actual image from server and share it
  Future<void> _shareImage(String? imagePath, String text) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final url = _getImageUrl(imagePath);
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/festival_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(response.bodyBytes);
          await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
          return;
        }
      } catch (_) {}
    }
    SharePlus.instance.share(ShareParams(text: text));
  }

  /// Capture the festival preview (image + business-name overlay) as a PNG so
  /// the shared image shows the real business name instead of a placeholder.
  Future<File?> _capturePreview(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/festival_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Share the rendered preview (with the business name burned in). Falls back
  /// to the raw server image if capture fails.
  Future<void> _shareRendered(GlobalKey key, String? imagePath, String text) async {
    final file = await _capturePreview(key);
    if (file != null) {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
    } else {
      await _shareImage(imagePath, text);
    }
  }

  /// Ask the server to build (or return the cached) ~60s branded festival video,
  /// download it, then share. Returns false on failure.
  Future<bool> _shareVideo(int templateId, String text, {String? message}) async {
    try {
      final url = await ApiService.getFestivalVideo(_userId, templateId, message: message);
      if (url == null || url.isEmpty) return false;
      final response = await http.get(Uri.parse(_getImageUrl(url)));
      if (response.statusCode != 200) return false;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/festival_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle speech-to-text for the festival message box. Updates [ctrl] live and
  /// rebuilds the bottom sheet via [refresh] so the mic/indicator reflects state.
  Future<void> _toggleListening(TextEditingController ctrl, void Function(VoidCallback) refresh) async {
    if (_isListening) {
      await _speech.stop();
      refresh(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    refresh(() => _isListening = true);
    await _speech.listen(
      onResult: (result) => refresh(() {
        ctrl.text = result.recognizedWords;
        ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
      }),
      listenOptions: stt.SpeechListenOptions(partialResults: true, localeId: _speechLocale),
    );
  }

  Future<void> _downloadImage(String? imagePath, String name) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      final url = _getImageUrl(imagePath);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
        final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final file = File('${dir.path}/Festival_${safeName}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved: ${file.path.split('/').last}'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTemplateDetail(Map<String, dynamic> template) {
    final priceCtrl = TextEditingController();
    final customMsgCtrl = TextEditingController();
    final imgPath = template['imagePath'] as String?;
    final previewKey = GlobalKey();
    bool videoLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final text = (template['templateText'] ?? '').toString()
              .replaceAll('{business}', _businessName)
              .replaceAll('{price}', priceCtrl.text.isEmpty ? '' : priceCtrl.text)
              .replaceAll('{logo}', '');

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),

                  // Festival image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: RepaintBoundary(
                      key: previewKey,
                      child: Stack(
                        children: [
                          if (imgPath != null)
                            CachedNetworkImage(
                              imageUrl: _getImageUrl(imgPath),
                              height: 220, width: double.infinity, fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                              errorWidget: (_, __, ___) => _fallbackCard(template),
                            )
                          else
                            _fallbackCard(template),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withAlpha(180)],
                                ),
                              ),
                              child: Text(_businessName,
                                style: const TextStyle(color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.w800, letterSpacing: 1,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: Text(text, style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 10),

                  TextField(controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Price / Offer (optional)',
                      prefixIcon: Icon(Icons.local_offer, size: 20), isDense: true),
                    onChanged: (_) => setModalState(() {})),
                  const SizedBox(height: 8),

                  // Message box with voice recording (type or speak)
                  Row(children: [
                    const Text('Voice: ', style: TextStyle(fontSize: 12)),
                    ChoiceChip(
                      label: const Text('ગુજરાતી', style: TextStyle(fontSize: 10)),
                      selected: _speechLocale == 'gu_IN',
                      onSelected: (_) => setModalState(() => _speechLocale = 'gu_IN'),
                      visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('हिन्दी', style: TextStyle(fontSize: 10)),
                      selected: _speechLocale == 'hi_IN',
                      onSelected: (_) => setModalState(() => _speechLocale = 'hi_IN'),
                      visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('English', style: TextStyle(fontSize: 10)),
                      selected: _speechLocale == 'en_IN',
                      onSelected: (_) => setModalState(() => _speechLocale = 'en_IN'),
                      visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                  ]),
                  const SizedBox(height: 6),
                  TextField(controller: customMsgCtrl, maxLines: 2,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Your Message (type or speak)',
                      hintText: _isListening ? 'Listening… speak now' : null,
                      prefixIcon: const Icon(Icons.message_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: _isListening
                            ? const BorderSide(color: Colors.red, width: 2)
                            : const BorderSide()),
                      suffixIcon: IconButton(
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : null),
                        tooltip: _isListening ? 'Stop' : 'Speak',
                        onPressed: () => _toggleListening(customMsgCtrl, setModalState),
                      ),
                    )),
                  if (_isListening)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red[400])),
                        const SizedBox(width: 6),
                        Text('Listening… speak now',
                          style: TextStyle(fontSize: 11, color: Colors.red[400])),
                      ]),
                    ),
                  const SizedBox(height: 14),

                  // WhatsApp share
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: () {
                      final msg = customMsgCtrl.text.trim().isEmpty ? text : '${customMsgCtrl.text.trim()}\n\n$text';
                      _shareRendered(previewKey, imgPath, msg);
                    },
                    icon: const Icon(Icons.message, size: 20),
                    label: const Text('Share via WhatsApp'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                  const SizedBox(height: 8),

                  Row(children: [
                    Expanded(child: FilledButton.icon(
                      onPressed: () {
                        final msg = customMsgCtrl.text.trim().isEmpty ? text : '${customMsgCtrl.text.trim()}\n\n$text';
                        _shareRendered(previewKey, imgPath, msg);
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share', style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => _downloadImage(imgPath, template['festivalName'] ?? 'festival'),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    )),
                  ]),
                  const SizedBox(height: 8),

                  // Create & share a branded ~60s festival video
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: videoLoading ? null : () async {
                      setModalState(() => videoLoading = true);
                      final custom = customMsgCtrl.text.trim();
                      final msg = custom.isEmpty ? text : '$custom\n\n$text';
                      // The on-screen message is burned into the video too.
                      final onScreen = custom.isEmpty ? text : custom;
                      final ok = await _shareVideo(template['id'] as int, msg, message: onScreen);
                      if (ctx.mounted) setModalState(() => videoLoading = false);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not create video. Please try again.'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: videoLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.movie_creation_outlined, size: 20),
                    label: Text(videoLoading ? 'Creating video…' : 'Create 60s Video'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  )),
                  if (videoLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('First time may take up to a minute…',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _fallbackCard(Map<String, dynamic> template) {
    final color = _categoryColors[template['category'] ?? ''] ?? Colors.grey;
    return Container(
      height: 280, width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color, color.withAlpha(150)]),
      ),
      child: Center(child: Text(template['festivalName'] ?? '',
        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: appBarTitle('Festival Calendar')),
      body: Column(children: [
        SizedBox(height: 50, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
              label: const Text('All'), selected: _selectedCategory == null,
              onSelected: (v) { setState(() => _selectedCategory = null); _loadTemplates(); },
            )),
            ..._categories.map((cat) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
              label: Text(cat.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 11)),
              selected: _selectedCategory == cat,
              onSelected: (v) { setState(() => _selectedCategory = v ? cat : null); _loadTemplates(); },
            ))),
          ],
        )),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _templates.isEmpty
              ? const Center(child: Text('No templates found', style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
                  itemCount: _templates.length,
                  itemBuilder: (ctx, i) {
                    final t = _templates[i];
                    final cat = t['category'] ?? '';
                    final color = _categoryColors[cat] ?? Colors.grey;
                    final hasImage = t['imagePath'] != null;

                    return GestureDetector(
                      onTap: () => _showTemplateDetail(Map<String, dynamic>.from(t)),
                      child: Card(
                        elevation: 2, clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Stack(fit: StackFit.expand, children: [
                          if (hasImage)
                            CachedNetworkImage(imageUrl: _getImageUrl(t['imagePath']), fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                decoration: BoxDecoration(gradient: LinearGradient(
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  colors: [color, color.withAlpha(150)]))))
                          else
                            Container(decoration: BoxDecoration(gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [color, color.withAlpha(150)]))),
                          Positioned(bottom: 0, left: 0, right: 0, child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withAlpha(200)])),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text(t['festivalName'] ?? '', style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('${_monthNames[t['month'] ?? 1]} ${t['day'] > 0 ? t['day'] : ''}',
                                style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11)),
                            ]),
                          )),
                          Positioned(top: 6, right: 6, child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black.withAlpha(80), shape: BoxShape.circle),
                            child: const Icon(Icons.share, color: Colors.white, size: 16))),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
