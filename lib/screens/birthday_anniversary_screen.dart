import 'package:flutter/material.dart';
import '../config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class BirthdayAnniversaryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const BirthdayAnniversaryScreen({super.key, required this.userData});

  @override
  State<BirthdayAnniversaryScreen> createState() =>
      _BirthdayAnniversaryScreenState();
}

class _BirthdayAnniversaryScreenState extends State<BirthdayAnniversaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int get _userId => widget.userData['userId'];

  bool _loading = true;

  // Birthday data
  List<dynamic> _todayBirthdays = [];
  List<dynamic> _upcomingBirthdays = [];

  // Anniversary data
  List<dynamic> _todayAnniversaries = [];
  List<dynamic> _upcomingAnniversaries = [];

  // Bulk message controllers
  final _bdayMsgCtrl = TextEditingController(
      text: 'Happy Birthday {name}! 🎂🎉 Aaje cake par 20% off! Visit us today.');
  final _annMsgCtrl = TextEditingController(
      text: 'Happy Anniversary {name}! ❤️🎉 Special offer for your celebration!');

  final Set<String> _selectedBdayMobiles = {};
  final Set<String> _selectedAnnMobiles = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _bdayMsgCtrl.dispose();
    _annMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getBirthdayReminders(_userId),
        ApiService.getAnniversaryReminders(_userId),
      ]);
      final bdayData = results[0];
      final annData = results[1];
      if (mounted) {
        setState(() {
          _todayBirthdays = bdayData?['todayBirthdays'] ?? [];
          _upcomingBirthdays = bdayData?['upcomingBirthdays'] ?? [];
          _todayAnniversaries = annData?['todayAnniversaries'] ?? [];
          _upcomingAnniversaries = annData?['upcomingAnniversaries'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendWhatsApp(String mobile, String name, String message) async {
    var cleanMobile = mobile.replaceAll('+', '').replaceAll(' ', '');
    if (!cleanMobile.startsWith('91') && cleanMobile.length == 10) {
      cleanMobile = '91$cleanMobile';
    }
    final personalMsg = message.replaceAll(RegExp(r'\{name\}', caseSensitive: false), name);
    final url = 'https://wa.me/$cleanMobile?text=${Uri.encodeComponent(personalMsg)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendBulkWhatsApp(
      Set<String> selectedMobiles, List<dynamic> people, String message) async {
    if (selectedMobiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    for (final mobile in selectedMobiles) {
      final person = people.firstWhere(
        (p) => p['mobile'] == mobile,
        orElse: () => {'personName': '', 'mobile': mobile},
      );
      await _sendWhatsApp(mobile, person['personName'] ?? '', message);
      // Small delay between opening each WhatsApp link
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: appBarTitle('Birthday / Anniversary'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              icon: const Icon(Icons.cake, size: 20),
              text: 'Birthdays (${_todayBirthdays.length})',
            ),
            Tab(
              icon: const Icon(Icons.favorite, size: 20),
              text: 'Anniversary (${_todayAnniversaries.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildBirthdayTab(),
                _buildAnniversaryTab(),
              ],
            ),
    );
  }

  Widget _buildBirthdayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Today's birthdays
          _sectionCard(
            title: "Today's Birthdays (${_todayBirthdays.length})",
            icon: Icons.cake,
            color: Colors.amber,
            child: _todayBirthdays.isEmpty
                ? const _EmptyMessage(
                    icon: Icons.cake, message: 'No birthdays today')
                : Column(
                    children: [
                      ..._todayBirthdays.map((p) => _personTile(
                            p,
                            _selectedBdayMobiles,
                            isToday: true,
                            messageCtrl: _bdayMsgCtrl,
                          )),
                      const SizedBox(height: 12),
                      // Bulk message
                      TextField(
                        controller: _bdayMsgCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Birthday Message (use {name})',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _sendBulkWhatsApp(
                            _selectedBdayMobiles,
                            _todayBirthdays,
                            _bdayMsgCtrl.text),
                        icon: const Icon(Icons.message, size: 18),
                        label: const Text('Send to Selected via WhatsApp'),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // Upcoming
          _sectionCard(
            title: 'Upcoming (Next 7 Days - ${_upcomingBirthdays.length})',
            icon: Icons.calendar_today,
            color: Colors.blue,
            child: _upcomingBirthdays.isEmpty
                ? const _EmptyMessage(
                    icon: Icons.calendar_today,
                    message: 'No upcoming birthdays')
                : Column(
                    children: _upcomingBirthdays
                        .map((p) => _upcomingTile(p))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnniversaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCard(
            title: "Today's Anniversaries (${_todayAnniversaries.length})",
            icon: Icons.favorite,
            color: Colors.red,
            child: _todayAnniversaries.isEmpty
                ? const _EmptyMessage(
                    icon: Icons.favorite, message: 'No anniversaries today')
                : Column(
                    children: [
                      ..._todayAnniversaries.map((p) => _personTile(
                            p,
                            _selectedAnnMobiles,
                            isToday: true,
                            messageCtrl: _annMsgCtrl,
                          )),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _annMsgCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Anniversary Message (use {name})',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _sendBulkWhatsApp(
                            _selectedAnnMobiles,
                            _todayAnniversaries,
                            _annMsgCtrl.text),
                        icon: const Icon(Icons.message, size: 18),
                        label: const Text('Send to Selected via WhatsApp'),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          _sectionCard(
            title:
                'Upcoming (Next 7 Days - ${_upcomingAnniversaries.length})',
            icon: Icons.calendar_today,
            color: Colors.blue,
            child: _upcomingAnniversaries.isEmpty
                ? const _EmptyMessage(
                    icon: Icons.calendar_today,
                    message: 'No upcoming anniversaries')
                : Column(
                    children: _upcomingAnniversaries
                        .map((p) => _upcomingTile(p))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
      {required String title,
      required IconData icon,
      required Color color,
      required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _personTile(
    dynamic person,
    Set<String> selectedSet, {
    bool isToday = false,
    required TextEditingController messageCtrl,
  }) {
    final mobile = person['mobile'] ?? '';
    final name = person['personName'] ?? '';
    final isSelected = selectedSet.contains(mobile);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: isSelected,
        onChanged: (v) {
          setState(() {
            if (v == true) {
              selectedSet.add(mobile);
            } else {
              selectedSet.remove(mobile);
            }
          });
        },
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(mobile, style: const TextStyle(fontSize: 12)),
      trailing: isToday
          ? FilledButton.tonalIcon(
              onPressed: () =>
                  _sendWhatsApp(mobile, name, messageCtrl.text),
              icon: const Icon(Icons.message, size: 16),
              label: const Text('Wish', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[100],
                foregroundColor: Colors.green[800],
              ),
            )
          : null,
    );
  }

  Widget _upcomingTile(dynamic person) {
    final daysLeft = person['daysLeft'] ?? 0;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(person['personName'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(person['mobile'] ?? '',
          style: const TextStyle(fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$daysLeft day${daysLeft > 1 ? 's' : ''}',
          style: TextStyle(
              color: Colors.blue[700],
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
