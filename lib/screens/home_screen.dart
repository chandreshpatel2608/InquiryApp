import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'inquiry_list_screen.dart';
import 'ai_post_maker_screen.dart';
import 'auto_status_scheduler_screen.dart';
import 'festival_calendar_screen.dart';
import 'digital_card_screen.dart';
import 'manage_catalog_screen.dart';
import 'birthday_anniversary_screen.dart';
import 'google_review_screen.dart';
import 'happy_customer_screen.dart';
import 'redeem_point_screen.dart';
import 'referral_point_screen.dart';
import 'followup_master_screen.dart';
import 'customer_master_screen.dart';
import 'supplier_master_screen.dart';
import 'item_master_screen.dart';
import 'stock_entry_screen.dart';
import 'sales_entry_screen.dart';
import 'ledger_screen.dart';
import 'supplier_ledger_screen.dart';
import '../config.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int get _userId => widget.userData['userId'];
  String get _userName => widget.userData['fullName'] ?? 'User';
  String get _businessName => widget.userData['businessName'] ?? 'My Business';
  String? get _logoPath => widget.userData['logoPath'] as String?;

  Widget _buildLogo({double size = 44}) {
    if (_logoPath != null && _logoPath!.isNotEmpty) {
      final logoUrl = '${baseUrl.replaceAll('/digitalcard/api', '').replaceAll('/api', '')}$_logoPath';
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(logoUrl, width: size, height: size, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.contain)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.contain),
    );
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  _buildLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _businessName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withAlpha(200),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // INQUIRY MASTER (top priority)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          _drawerItem(Icons.people, 'Inquiry Master', () {
            Navigator.pop(context);
            _navigateTo(InquiryListScreen(
              userId: _userId,
              userName: _userName,
            ));
          }),
          _drawerItem(Icons.phone_callback, 'Followup Master', () {
            Navigator.pop(context);
            _navigateTo(FollowupMasterScreen(userId: _userId));
          }),
          _drawerItem(Icons.card_giftcard, 'Referral Point', () {
            Navigator.pop(context);
            _navigateTo(ReferralPointScreen(userId: _userId));
          }),

          const Divider(height: 1),
          // MODULE 1: MARKETING
          _sectionHeader('MARKETING'),
          _drawerItem(Icons.auto_awesome, 'AI Post Maker', () {
            Navigator.pop(context);
            _navigateTo(AiPostMakerScreen(userData: widget.userData));
          }),
          _drawerItem(Icons.schedule_send, 'Auto Status Scheduler', () {
            Navigator.pop(context);
            _navigateTo(AutoStatusSchedulerScreen(userData: widget.userData));
          }),
          _drawerItem(Icons.celebration, 'Festival Calendar', () {
            Navigator.pop(context);
            _navigateTo(FestivalCalendarScreen(userData: widget.userData));
          }),

          const Divider(height: 1),
          // MODULE 2: SALES + ORDERING
          _sectionHeader('SALES + ORDERING'),
          _drawerItem(Icons.badge, 'Digital Visiting Card', () {
            Navigator.pop(context);
            _navigateTo(DigitalCardScreen(userData: widget.userData));
          }),
          _drawerItem(Icons.inventory_2, 'Products & Gallery', () {
            Navigator.pop(context);
            _navigateTo(ManageCatalogScreen(userData: widget.userData));
          }),
          _drawerItem(Icons.camera_enhance, 'Happy Customer Photo', () {
            Navigator.pop(context);
            _navigateTo(HappyCustomerScreen(userData: widget.userData));
          }),

          const Divider(height: 1),
          // MODULE 3: CUSTOMER RETENTION
          _sectionHeader('CUSTOMER RETENTION'),
          _drawerItem(Icons.cake, 'Birthday / Anniversary', () {
            Navigator.pop(context);
            _navigateTo(BirthdayAnniversaryScreen(userData: widget.userData));
          }),
          _drawerItem(Icons.star, 'Google Review Request', () {
            Navigator.pop(context);
            _navigateTo(GoogleReviewScreen(userData: widget.userData));
          }),
          _drawerItem(Icons.redeem, 'Redeem Point Master', () {
            Navigator.pop(context);
            _navigateTo(RedeemPointScreen(userId: _userId));
          }),

          const Divider(height: 1),
          // MODULE 4: BILLING / INVENTORY
          _sectionHeader('BILLING / INVENTORY'),
          _drawerItem(Icons.people_alt, 'Customer Master', () {
            Navigator.pop(context);
            _navigateTo(CustomerMasterScreen(userId: _userId));
          }),
          _drawerItem(Icons.inventory_2, 'Item Master', () {
            Navigator.pop(context);
            _navigateTo(ItemMasterScreen(userId: _userId));
          }),
          _drawerItem(Icons.warehouse, 'Stock Entry', () {
            Navigator.pop(context);
            _navigateTo(StockEntryScreen(userId: _userId));
          }),
          _drawerItem(Icons.receipt_long, 'Sales Entry', () {
            Navigator.pop(context);
            _navigateTo(SalesEntryScreen(userData: widget.userData));
          }),
          _drawerItem(Icons.account_balance_wallet, 'Ledger', () {
            Navigator.pop(context);
            _navigateTo(LedgerScreen(userData: widget.userData));
          }),
              ],
            ),
          ),
          const Divider(height: 1),
          _drawerItem(Icons.logout, 'Logout', _logout,
              color: Colors.red[400]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 1.2)),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 22, color: color),
      title: Text(title,
          style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: appBarTitle(_businessName),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline, size: 22),
            tooltip: 'Change Password',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChangePasswordScreen(userId: _userId)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome
            Card(
              elevation: 0,
              color: cs.primaryContainer.withAlpha(80),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _buildLogo(size: 50),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome, $_userName!',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(_businessName,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // MODULE 1
            _moduleTitle('Marketing'),
            _featureGrid([
              _FeatureItem(Icons.auto_awesome, 'AI Post\nMaker',
                  Colors.purple, () => _navigateTo(AiPostMakerScreen(userData: widget.userData))),
              _FeatureItem(Icons.schedule_send, 'Auto Status\nScheduler',
                  Colors.blue, () => _navigateTo(AutoStatusSchedulerScreen(userData: widget.userData))),
              _FeatureItem(Icons.celebration, 'Festival\nCalendar',
                  Colors.orange, () => _navigateTo(FestivalCalendarScreen(userData: widget.userData))),
            ]),
            const SizedBox(height: 20),

            // INQUIRY MASTER (top priority)
            _moduleTitle('Inquiry Master'),
            _featureGrid([
              _FeatureItem(Icons.people, 'Inquiry\nMaster',
                  Colors.teal, () => _navigateTo(InquiryListScreen(userId: _userId, userName: _userName))),
              _FeatureItem(Icons.phone_callback, 'Followup\nMaster',
                  Colors.indigo, () => _navigateTo(FollowupMasterScreen(userId: _userId))),
              _FeatureItem(Icons.card_giftcard, 'Referral\nPoint',
                  Colors.deepPurple, () => _navigateTo(ReferralPointScreen(userId: _userId))),
            ]),
            const SizedBox(height: 20),

            // MODULE 2
            _moduleTitle('Sales + Ordering'),
            _featureGrid([
              _FeatureItem(Icons.badge, 'Digital\nCard',
                  Colors.indigo, () => _navigateTo(DigitalCardScreen(userData: widget.userData))),
              _FeatureItem(Icons.inventory_2, 'Products\n& Gallery',
                  Colors.teal, () => _navigateTo(ManageCatalogScreen(userData: widget.userData))),
              _FeatureItem(Icons.camera_enhance, 'Happy\nCustomer',
                  Colors.deepOrange, () => _navigateTo(HappyCustomerScreen(userData: widget.userData))),
            ]),
            const SizedBox(height: 20),

            // MODULE 3
            _moduleTitle('Customer Retention'),
            _featureGrid([
              _FeatureItem(Icons.cake, 'Birthday /\nAnniversary',
                  Colors.pink, () => _navigateTo(BirthdayAnniversaryScreen(userData: widget.userData))),
              _FeatureItem(Icons.star, 'Google Review\nRequest',
                  Colors.amber[700]!, () => _navigateTo(GoogleReviewScreen(userData: widget.userData))),
              _FeatureItem(Icons.redeem, 'Redeem\nPoints',
                  Colors.green, () => _navigateTo(RedeemPointScreen(userId: _userId))),
            ]),
            const SizedBox(height: 20),

            // MODULE 4
            _moduleTitle('Billing / Inventory'),
            _featureGrid([
              _FeatureItem(Icons.people_alt, 'Customer\nMaster',
                  Colors.teal, () => _navigateTo(CustomerMasterScreen(userId: _userId))),
              _FeatureItem(Icons.business, 'Supplier\nMaster',
                Colors.indigo, () => _navigateTo(SupplierMasterScreen(userId: _userId))),
              _FeatureItem(Icons.inventory_2, 'Item\nMaster',
                  Colors.deepPurple, () => _navigateTo(ItemMasterScreen(userId: _userId))),
              _FeatureItem(Icons.warehouse, 'Stock\nEntry',
                  Colors.brown, () => _navigateTo(StockEntryScreen(userId: _userId))),
              _FeatureItem(Icons.receipt_long, 'Sales\nEntry',
                  Colors.indigo, () => _navigateTo(SalesEntryScreen(userData: widget.userData))),
              _FeatureItem(Icons.account_balance_wallet, 'Ledger',
                  Colors.green, () => _navigateTo(LedgerScreen(userData: widget.userData))),
              _FeatureItem(Icons.request_quote, 'Supplier\nLedger',
                Colors.orange, () => _navigateTo(SupplierLedgerScreen(
                userId: _userId,
                businessName: _businessName,
                ))),
            ]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _moduleTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _featureGrid(List<_FeatureItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 3;
        const spacing = 10.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: tileWidth,
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.color.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Icon(item.icon, color: item.color, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(item.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _FeatureItem(this.icon, this.label, this.color, this.onTap);
}
