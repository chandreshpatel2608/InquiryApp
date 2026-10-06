import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/api_service.dart';

/// Events published from Admin → Events for the shop the customer is browsing.
class StorefrontEventsScreen extends StatefulWidget {
  final int cardProfileId;

  const StorefrontEventsScreen({super.key, required this.cardProfileId});

  @override
  State<StorefrontEventsScreen> createState() => _StorefrontEventsScreenState();
}

class _StorefrontEventsScreenState extends State<StorefrontEventsScreen> {
  List<dynamic> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final events = await ApiService.getStorefrontEvents(widget.cardProfileId);
      if (mounted) setState(() => _events = events);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$path';
  }

  String _dateRange(Map<String, dynamic> event) {
    final start = DateTime.tryParse(event['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(event['endDate']?.toString() ?? '');
    if (start == null) return '';
    final startText = _format(start);
    return end == null ? startText : '$startText - ${_format(end)}';
  }

  String _format(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _events.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 80),
                      Icon(Icons.event_busy_outlined, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'No events scheduled right now.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final event = Map<String, dynamic>.from(
                        _events[index] as Map,
                      );
                      final image = _imageUrl(event['imagePath']?.toString());
                      final dates = _dateRange(event);
                      final link = event['linkUrl']?.toString() ?? '';
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (image.isNotEmpty)
                              Image.network(
                                image,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['title']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if ((event['subtitle'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(event['subtitle'].toString()),
                                    ),
                                  if (dates.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(dates),
                                        ],
                                      ),
                                    ),
                                  if ((event['location'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              event['location'].toString(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if ((event['description'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        event['description'].toString(),
                                      ),
                                    ),
                                  if (link.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: FilledButton.tonalIcon(
                                        onPressed: () => launchUrl(
                                          Uri.parse(link),
                                          mode: LaunchMode.externalApplication,
                                        ),
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('More details'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
