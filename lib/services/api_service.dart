import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Thrown by API calls that want to surface the server's exact error message.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  // ── Persistent HTTP client (reuses TCP connections) ──
  static final http.Client _client = http.Client();

  // ── In-memory cache for brands (rarely changes) ──
  static final Map<int, List<dynamic>> _brandsCache = {};
  static final Map<int, DateTime> _brandsCacheTime = {};
  static const _brandsCacheTTL = Duration(minutes: 10);

  // ── In-memory cache for inquiries ──
  static final Map<int, List<dynamic>> _inquiriesCache = {};
  static final Map<int, DateTime> _inquiriesCacheTime = {};
  static const _inquiriesCacheTTL = Duration(minutes: 2);
  // ── Login ──
  static Future<Map<String, dynamic>?> login(
    String mobile,
    String password,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mobile': mobile, 'password': password}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    // Surface the server's actual error message (e.g. "Invalid password.")
    // instead of silently returning null so the UI can show what went wrong.
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error']?.toString() ?? 'Login failed.');
    } on FormatException {
      throw ApiException('Login failed (server error ${res.statusCode}).');
    }
  }

  // ── Verify User (check active status + get fresh data) ──
  static Future<Map<String, dynamic>?> verifyUser(int userId) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/verify-user?userId=$userId'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── My Profile (get / update) ──
  static Future<Map<String, dynamic>?> getProfile(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/profile?userId=$userId'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return {'success': true};
    return _errBody(res, 'Failed to update profile.');
  }

  // ── Forgot Password ──
  static Future<Map<String, dynamic>> forgotPassword(
    String mobile,
    String newPassword,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mobile': mobile, 'newPassword': newPassword}),
    );
    return jsonDecode(res.body);
  }

  // ── Change Password ──
  static Future<Map<String, dynamic>> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );
    return jsonDecode(res.body);
  }

  // ═══════════════════════════════════════════════════════════════════
  // INQUIRIES
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> getInquiries(
    int userId, {
    bool forceRefresh = false,
  }) async {
    // Return cached inquiries if fresh
    if (!forceRefresh &&
        _inquiriesCache.containsKey(userId) &&
        _inquiriesCacheTime.containsKey(userId) &&
        DateTime.now().difference(_inquiriesCacheTime[userId]!) <
            _inquiriesCacheTTL) {
      return _inquiriesCache[userId]!;
    }
    final res = await _client.get(
      Uri.parse('$baseUrl/inquiries?userId=$userId'),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      _inquiriesCache[userId] = data;
      _inquiriesCacheTime[userId] = DateTime.now();
      return data;
    }
    return _inquiriesCache[userId] ?? [];
  }

  /// Clears the inquiry cache (call after create/update/delete)
  static void invalidateInquiryCache(int userId) {
    _inquiriesCache.remove(userId);
    _inquiriesCacheTime.remove(userId);
  }

  static Future<Map<String, dynamic>> createInquiry(
    Map<String, dynamic> data,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/inquiries'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      invalidateInquiryCache(data['userId'] as int);
      return {'success': true};
    }
    try {
      final body = jsonDecode(res.body);
      return {'success': false, 'error': body['error'] ?? 'Failed to save.'};
    } catch (_) {
      return {'success': false, 'error': 'Failed to save.'};
    }
  }

  static Future<bool> updateInquiry(int id, Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/inquiries/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      invalidateInquiryCache(data['userId'] as int);
      return true;
    }
    return false;
  }

  static Future<bool> deleteInquiry(int id, int userId) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/inquiries/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════
  // BRANDS (for inquiry dropdown)
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> getBrands(
    int userId, {
    bool forceRefresh = false,
  }) async {
    // Return cached brands if fresh
    if (!forceRefresh &&
        _brandsCache.containsKey(userId) &&
        _brandsCacheTime.containsKey(userId) &&
        DateTime.now().difference(_brandsCacheTime[userId]!) <
            _brandsCacheTTL) {
      return _brandsCache[userId]!;
    }
    final res = await _client.get(Uri.parse('$baseUrl/brands?userId=$userId'));
    if (res.statusCode == 200) {
      final brands = jsonDecode(res.body) as List<dynamic>;
      _brandsCache[userId] = brands;
      _brandsCacheTime[userId] = DateTime.now();
      return brands;
    }
    return _brandsCache[userId] ?? [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORIES (for inquiry dropdown)
  // ═══════════════════════════════════════════════════════════════════

  static final Map<int, List<dynamic>> _categoriesCache = {};
  static final Map<int, DateTime> _categoriesCacheTime = {};
  static const _categoriesCacheTTL = Duration(minutes: 10);

  static Future<List<dynamic>> getCategories(
    int userId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _categoriesCache.containsKey(userId) &&
        _categoriesCacheTime.containsKey(userId) &&
        DateTime.now().difference(_categoriesCacheTime[userId]!) <
            _categoriesCacheTTL) {
      return _categoriesCache[userId]!;
    }
    final res = await _client.get(
      Uri.parse('$baseUrl/categories?userId=$userId'),
    );
    if (res.statusCode == 200) {
      final categories = jsonDecode(res.body) as List<dynamic>;
      _categoriesCache[userId] = categories;
      _categoriesCacheTime[userId] = DateTime.now();
      return categories;
    }
    return _categoriesCache[userId] ?? [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // ROYALTY POINTS
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getRoyaltyPoints(
    int userId,
    String mobile,
  ) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/royalty-points?userId=$userId&mobile=$mobile'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. AI POST MAKER
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> generateAiPost(
    String category,
    String businessName,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/ai-post/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'category': category, 'businessName': businessName}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<String?> uploadPostImage(File file, int userId) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ai-post/upload-image'),
    );
    request.fields['userId'] = userId.toString();
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      return json['imagePath'];
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. AUTO STATUS SCHEDULER
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> getScheduledStatuses(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/scheduled-statuses?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<bool> createScheduledStatus(Map<String, dynamic> data) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/scheduled-statuses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  static Future<bool> deleteScheduledStatus(int id, int userId) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/scheduled-statuses/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. FESTIVAL CALENDAR
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> getFestivalTemplates({String? category}) async {
    var url = '$baseUrl/festival-templates';
    if (category != null && category.isNotEmpty) {
      url += '?category=$category';
    }
    final res = await _client.get(Uri.parse(url));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<List<dynamic>> getFestivalCategories() async {
    final res = await _client.get(Uri.parse('$baseUrl/festival-categories'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  /// Requests a branded ~60s festival video for this company + template.
  /// The server generates (and caches) it with ffmpeg, so the first call can
  /// take a while. Returns the relative video URL, or null on failure.
  static Future<String?> getFestivalVideo(
    int userId,
    int templateId, {
    String? message,
  }) async {
    var url = '$baseUrl/festival-video?userId=$userId&templateId=$templateId';
    if (message != null && message.trim().isNotEmpty) {
      url += '&message=${Uri.encodeQueryComponent(message.trim())}';
    }
    final res = await _client
        .get(Uri.parse(url))
        .timeout(
          const Duration(minutes: 5),
          onTimeout: () => http.Response('', 504),
        );
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return json['videoUrl'] as String?;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. WHATSAPP CATALOG (PRODUCTS)
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> getProducts(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/products?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  /// Add a product with an optional image. Returns the created product map,
  /// or null on failure.
  static Future<Map<String, dynamic>?> addProduct({
    required int userId,
    required String name,
    String? description,
    double? price,
    String? whatsAppMessage,
    bool isEcommerce = false,
    File? image,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/products'),
    );
    request.fields['userId'] = userId.toString();
    request.fields['name'] = name;
    if (description != null) request.fields['description'] = description;
    if (price != null) request.fields['price'] = price.toString();
    if (whatsAppMessage != null)
      request.fields['whatsAppMessage'] = whatsAppMessage;
    request.fields['isEcommerce'] = isEcommerce.toString();
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body);
    }
    try {
      final err = jsonDecode(body);
      return {
        'error': err['error'] ?? err['title'] ?? 'Failed to add product.',
      };
    } catch (_) {
      return {'error': 'Failed to add product (HTTP ${response.statusCode}).'};
    }
  }

  static Future<bool> deleteProduct(int userId, int productId) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/products/delete'),
      body: {'userId': userId.toString(), 'productId': productId.toString()},
    );
    return res.statusCode == 200;
  }

  /// Update an existing product with an optional replacement image.
  static Future<Map<String, dynamic>?> updateProduct({
    required int userId,
    required int productId,
    required String name,
    String? description,
    double? price,
    String? whatsAppMessage,
    bool isEcommerce = false,
    File? image,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/products/update'),
    );
    request.fields['userId'] = userId.toString();
    request.fields['productId'] = productId.toString();
    request.fields['name'] = name;
    if (description != null) request.fields['description'] = description;
    if (price != null) request.fields['price'] = price.toString();
    if (whatsAppMessage != null)
      request.fields['whatsAppMessage'] = whatsAppMessage;
    request.fields['isEcommerce'] = isEcommerce.toString();
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body);
    }
    try {
      final err = jsonDecode(body);
      return {
        'error': err['error'] ?? err['title'] ?? 'Failed to update product.',
      };
    } catch (_) {
      return {
        'error': 'Failed to update product (HTTP ${response.statusCode}).',
      };
    }
  }
  // ═══════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════
  // MOBILE STOREFRONT (customer auth, cart, checkout, orders)
  // ═══════════════════════════════════════════════════════════════════

  static Map<String, String> _storefrontHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Future<Map<String, dynamic>> _storefrontResponse(
    Future<http.Response> response,
    String fallback,
  ) async {
    final res = await response;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return body;
      throw ApiException(body['error']?.toString() ?? fallback);
    } on FormatException {
      throw ApiException('$fallback (HTTP ${res.statusCode}).');
    }
  }

  static Future<List<dynamic>> getStorefrontProducts(int cardProfileId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/storefront/$cardProfileId/products'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    return [];
  }

  static Future<Map<String, dynamic>> resolveStorefront(String slug) {
    return _storefrontResponse(
      _client.get(
        Uri.parse(
          '$baseUrl/storefront/resolve?slug=${Uri.encodeQueryComponent(slug)}',
        ),
      ),
      'Unable to find that store.',
    );
  }

  static Future<Map<String, dynamic>> registerStorefrontCustomer({
    required int cardProfileId,
    required String name,
    required String mobile,
    required String password,
    String? email,
    String? address,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cardProfileId': cardProfileId,
          'name': name,
          'mobile': mobile,
          'password': password,
          'email': email,
          'address': address,
        }),
      ),
      'Unable to create your customer account.',
    );
  }

  static Future<Map<String, dynamic>> loginStorefrontCustomer({
    required int cardProfileId,
    required String mobile,
    required String password,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cardProfileId': cardProfileId,
          'mobile': mobile,
          'password': password,
        }),
      ),
      'Unable to sign in.',
    );
  }

  static Future<Map<String, dynamic>> getStorefrontCart({
    required int cardProfileId,
    required String token,
  }) {
    return _storefrontResponse(
      _client.get(
        Uri.parse('$baseUrl/storefront/$cardProfileId/cart'),
        headers: _storefrontHeaders(token),
      ),
      'Unable to load your cart.',
    );
  }

  static Future<Map<String, dynamic>> updateStorefrontCart({
    required int cardProfileId,
    required String token,
    required int productId,
    required int quantity,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/$cardProfileId/cart/items'),
        headers: _storefrontHeaders(token),
        body: jsonEncode({'productId': productId, 'quantity': quantity}),
      ),
      'Unable to update your cart.',
    );
  }

  static Future<Map<String, dynamic>> checkoutStorefrontCart({
    required int cardProfileId,
    required String token,
    required String deliveryAddress,
    required String paymentMethod,
    String? name,
    String? mobile,
    String? email,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/$cardProfileId/checkout'),
        headers: _storefrontHeaders(token),
        body: jsonEncode({
          'name': name,
          'mobile': mobile,
          'email': email,
          'deliveryAddress': deliveryAddress,
          'paymentMethod': paymentMethod,
        }),
      ),
      'Checkout could not be completed.',
    );
  }

  static Future<Map<String, dynamic>> submitStorefrontUpiPayment({
    required int orderId,
    required String token,
    required String paymentReference,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/orders/$orderId/upi-submission'),
        headers: _storefrontHeaders(token),
        body: jsonEncode({'paymentReference': paymentReference}),
      ),
      'Unable to submit the UPI payment reference.',
    );
  }

  static Future<Map<String, dynamic>> submitStorefrontReview({
    required int cardProfileId,
    required String token,
    required int rating,
    String? comment,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/$cardProfileId/review'),
        headers: _storefrontHeaders(token),
        body: jsonEncode({'rating': rating, 'comment': comment}),
      ),
      'Unable to submit your review.',
    );
  }

  static Future<Map<String, dynamic>> createMobileRazorpayOrder({
    required int orderId,
    required String token,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/orders/$orderId/razorpay'),
        headers: _storefrontHeaders(token),
      ),
      'Unable to start the card payment.',
    );
  }

  static Future<Map<String, dynamic>> verifyMobileRazorpay({
    required int orderId,
    required String token,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) {
    return _storefrontResponse(
      _client.post(
        Uri.parse('$baseUrl/storefront/orders/$orderId/razorpay-verify'),
        headers: _storefrontHeaders(token),
        body: jsonEncode({
          'razorpayPaymentId': razorpayPaymentId,
          'razorpayOrderId': razorpayOrderId,
          'razorpaySignature': razorpaySignature,
        }),
      ),
      'Unable to verify the card payment.',
    );
  }

  static Future<Map<String, dynamic>> editStorefrontOrder({
    required int orderId,
    required String token,
    required String name,
    required String mobile,
    String? email,
    String? deliveryAddress,
  }) {
    return _storefrontResponse(
      _client.put(
        Uri.parse('$baseUrl/storefront/orders/$orderId'),
        headers: _storefrontHeaders(token),
        body: jsonEncode({
          'name': name,
          'mobile': mobile,
          'email': email,
          'deliveryAddress': deliveryAddress,
        }),
      ),
      'Unable to update the order.',
    );
  }

  static Future<Map<String, dynamic>> getStorefrontUpiPayment({
    required int orderId,
    required String token,
  }) {
    return _storefrontResponse(
      _client.get(
        Uri.parse('$baseUrl/storefront/orders/$orderId/upi'),
        headers: _storefrontHeaders(token),
      ),
      'Unable to start the UPI payment.',
    );
  }

  static Future<List<dynamic>> getStorefrontOrders({
    required int cardProfileId,
    required String token,
  }) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/storefront/$cardProfileId/orders'),
      headers: _storefrontHeaders(token),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error']?.toString() ?? 'Unable to load orders.');
    } on FormatException {
      throw ApiException('Unable to load orders (HTTP ${res.statusCode}).');
    }
  }

  static Map<String, dynamic> _errBody(http.Response res, String fallback) {
    try {
      final b = jsonDecode(res.body);
      return {'success': false, 'error': b['error'] ?? b['title'] ?? fallback};
    } catch (_) {
      return {'success': false, 'error': fallback};
    }
  }

  // ── Customer Master ──
  static Future<List<dynamic>> getCustomers(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/customers?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> saveCustomer(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/customers'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/customers/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200) return {'success': true};
    return _errBody(res, 'Failed to save customer.');
  }

  static Future<bool> deleteCustomer(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/customers/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  // ── Item Master ──
  static Future<List<dynamic>> getItems(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/items?userId=$userId'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> saveItem(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/items'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/items/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200) return {'success': true};
    return _errBody(res, 'Failed to save item.');
  }

  static Future<bool> deleteItem(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/items/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  static Future<List<String>> uploadItemImages(
    int userId,
    List<File> files,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/items/upload-images'),
    );
    request.fields['userId'] = userId.toString();
    for (final file in files) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) return [];
    return List<String>.from(jsonDecode(body)['imagePaths'] ?? const []);
  }

  static Future<List<dynamic>> getTransports(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/transports?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> saveTransport(
    int userId,
    String name, {
    int? id,
  }) async {
    final data = {'userId': userId, 'name': name.trim()};
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/transports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/transports/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200)
      return {'success': true, ...jsonDecode(res.body)};
    return _errBody(res, 'Unable to save transporter.');
  }

  static Future<bool> deleteTransport(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/transports/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  static Future<List<dynamic>> getPackingLists(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/packing-lists?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> savePackingList(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/packing-lists'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/packing-lists/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200)
      return {'success': true, ...jsonDecode(res.body)};
    return _errBody(res, 'Failed to save packing list.');
  }

  static Future<bool> deletePackingList(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/packing-lists/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  static Future<List<dynamic>> getOrders(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/orders?userId=$userId'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error']?.toString() ?? 'Unable to load orders.');
    } on FormatException {
      throw ApiException('Unable to load orders (HTTP ${res.statusCode}).');
    }
  }

  static Future<Map<String, dynamic>> saveOrder(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/orders'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/orders/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200) {
      return {'success': true, ...jsonDecode(res.body)};
    }
    return _errBody(res, 'Unable to save order.');
  }

  static Future<bool> deleteOrder(int userId, int id) async {
    final res = await _client.delete(Uri.parse('$baseUrl/orders/$id?userId=$userId'));
    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>> sendOrderToPackingList(
    int userId,
    int id,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/orders/$id/send-to-packing-list?userId=$userId'),
    );
    if (res.statusCode == 200) return {'success': true, ...jsonDecode(res.body)};
    return _errBody(res, 'Unable to send order to packing list.');
  }

  static Future<String?> uploadPackingItem(int userId, File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/packing-lists/upload-item'),
    );
    request.fields['userId'] = userId.toString();
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) return null;
    return jsonDecode(body)['uploadItemPath'] as String?;
  }

  static Future<List<dynamic>> getReplacements(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/replacements?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> saveReplacement(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/replacements'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/replacements/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200)
      return {'success': true, ...jsonDecode(res.body)};
    return _errBody(res, 'Failed to save replacement.');
  }

  static Future<bool> deleteReplacement(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/replacements/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  // ── Stock Entry ──
  static Future<List<dynamic>> getStockSummary(
    int userId, {
    String? search,
  }) async {
    final q = (search != null && search.isNotEmpty)
        ? '&search=${Uri.encodeQueryComponent(search)}'
        : '';
    final res = await _client.get(
      Uri.parse('$baseUrl/stock/summary?userId=$userId$q'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<List<dynamic>> getStockEntries(
    int userId, {
    String? search,
  }) async {
    final q = (search != null && search.isNotEmpty)
        ? '&search=${Uri.encodeQueryComponent(search)}'
        : '';
    final res = await _client.get(
      Uri.parse('$baseUrl/stock/entries?userId=$userId$q'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> addStock(
    Map<String, dynamic> data,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/stock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return {'success': true};
    return _errBody(res, 'Failed to add stock.');
  }

  static Future<Map<String, dynamic>> updateStock(
    int id,
    Map<String, dynamic> data,
  ) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/stock/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return {'success': true};
    return _errBody(res, 'Failed to update stock.');
  }

  static Future<bool> deleteStock(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/stock/$id?userId=$userId'),
    );
    if (res.statusCode == 200) return true;

    // Fallback for environments/clients where DELETE is blocked.
    final postRes = await _client.post(
      Uri.parse('$baseUrl/stock/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'id': id}),
    );
    return postRes.statusCode == 200;
  }

  // ── Supplier Master ──
  static Future<List<dynamic>> getSuppliers(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/suppliers?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> saveSupplier(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/suppliers'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/suppliers/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200) return {'success': true};
    return _errBody(res, 'Failed to save supplier.');
  }

  static Future<bool> deleteSupplier(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/suppliers/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  // ── Supplier Ledger ──
  static Future<double> getSupplierPartyPending(
    int userId,
    int supplierId,
  ) async {
    final res = await _client.get(
      Uri.parse(
        '$baseUrl/supplier-ledger/party-pending?userId=$userId&supplierId=$supplierId',
      ),
    );
    if (res.statusCode == 200) {
      final b = jsonDecode(res.body);
      return (b['totalPending'] ?? 0).toDouble();
    }
    return 0;
  }

  static Future<List<dynamic>> getSupplierLedger(
    int userId, {
    int? supplierId,
    String? search,
    String? fromDate,
    String? toDate,
  }) async {
    final params = <String, String>{'userId': userId.toString()};
    if (supplierId != null && supplierId > 0)
      params['supplierId'] = supplierId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (fromDate != null && fromDate.isNotEmpty) params['fromDate'] = fromDate;
    if (toDate != null && toDate.isNotEmpty) params['toDate'] = toDate;
    final uri = Uri.parse(
      '$baseUrl/supplier-ledger',
    ).replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> saveSupplierLedger(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/supplier-ledger'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/supplier-ledger/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200)
      return {'success': true, ...jsonDecode(res.body)};
    return _errBody(res, 'Failed to save supplier ledger entry.');
  }

  static Future<bool> deleteSupplierLedger(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/supplier-ledger/$id?userId=$userId'),
    );
    if (res.statusCode == 200) return true;

    // Fallback for environments/clients where DELETE is blocked.
    final postRes = await _client.post(
      Uri.parse('$baseUrl/supplier-ledger/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'id': id}),
    );
    return postRes.statusCode == 200;
  }

  // ── Sales Entry ──
  static Future<List<dynamic>> getSales(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/sales?userId=$userId'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>?> getSaleDetail(int userId, int id) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/sales/$id?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<Map<String, dynamic>> saveSale(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/sales'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/sales/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200) return {'success': true};
    return _errBody(res, 'Failed to save sale.');
  }

  static Future<bool> deleteSale(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/sales/$id?userId=$userId'),
    );
    return res.statusCode == 200;
  }

  // ── Ledger ──
  static Future<double> getPartyPending(int userId, int customerId) async {
    final res = await _client.get(
      Uri.parse(
        '$baseUrl/ledger/party-pending?userId=$userId&customerId=$customerId',
      ),
    );
    if (res.statusCode == 200) {
      final b = jsonDecode(res.body);
      return (b['totalPending'] ?? 0).toDouble();
    }
    return 0;
  }

  static Future<List<dynamic>> getLedger(
    int userId, {
    int? customerId,
    String? search,
    String? fromDate,
    String? toDate,
  }) async {
    final params = <String, String>{'userId': userId.toString()};
    if (customerId != null && customerId > 0)
      params['customerId'] = customerId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (fromDate != null && fromDate.isNotEmpty) params['fromDate'] = fromDate;
    if (toDate != null && toDate.isNotEmpty) params['toDate'] = toDate;
    final uri = Uri.parse('$baseUrl/ledger').replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<Map<String, dynamic>> saveLedger(
    Map<String, dynamic> data, {
    int? id,
  }) async {
    final res = id == null
        ? await _client.post(
            Uri.parse('$baseUrl/ledger'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
        : await _client.put(
            Uri.parse('$baseUrl/ledger/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );
    if (res.statusCode == 200)
      return {'success': true, ...jsonDecode(res.body)};
    return _errBody(res, 'Failed to save ledger entry.');
  }

  static Future<bool> deleteLedger(int userId, int id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/ledger/$id?userId=$userId'),
    );
    if (res.statusCode == 200) return true;

    // Fallback for environments/clients where DELETE is blocked.
    final postRes = await _client.post(
      Uri.parse('$baseUrl/ledger/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'id': id}),
    );
    return postRes.statusCode == 200;
  }

  static Future<List<dynamic>> getGallery(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/gallery?userId=$userId'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  /// Upload a gallery photo. Returns the created photo map, or null on failure.
  static Future<Map<String, dynamic>?> uploadGalleryPhoto({
    required int userId,
    String? caption,
    required File image,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/gallery/photo'),
    );
    request.fields['userId'] = userId.toString();
    if (caption != null) request.fields['caption'] = caption;
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body);
    }
    try {
      final err = jsonDecode(body);
      return {
        'error': err['error'] ?? err['title'] ?? 'Failed to upload photo.',
      };
    } catch (_) {
      return {'error': 'Failed to upload photo (HTTP ${response.statusCode}).'};
    }
  }

  static Future<bool> deleteGalleryPhoto(int userId, int photoId) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/gallery/delete'),
      body: {'userId': userId.toString(), 'photoId': photoId.toString()},
    );
    return res.statusCode == 200;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 5. DIGITAL VISITING CARD
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getCardProfile(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/card-profile?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. BIRTHDAY / ANNIVERSARY REMINDERS
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getBirthdayReminders(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/birthday-reminders?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<Map<String, dynamic>?> getAnniversaryReminders(
    int userId,
  ) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/anniversary-reminders?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 7. GOOGLE REVIEW REQUEST
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> generateReviewLinks(
    int userId,
    List<String> mobileNumbers,
    String? googleReviewLink,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/google-review/generate-links'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'mobileNumbers': mobileNumbers,
        'googleReviewLink': googleReviewLink,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 8. HAPPY CUSTOMER PHOTO
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getCompanyInfoForPhoto(
    int userId,
  ) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/customer-photo/company-info?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  static Future<Map<String, dynamic>?> uploadCustomerPhoto(
    int userId,
    String filePath,
    String? customerName,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/customer-photo/upload'),
    );
    request.fields['userId'] = userId.toString();
    if (customerName != null) request.fields['customerName'] = customerName;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final response = await request.send();
    if (response.statusCode == 200) {
      return jsonDecode(await response.stream.bytesToString());
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 9. REDEEM POINT MASTER
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> getRedeemGifts(int userId) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/redeem-gifts?userId=$userId'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    return [];
  }

  static Future<Map<String, dynamic>?> redeemPoints(
    int userId,
    String mobile,
    int giftId,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/redeem-points'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'mobile': mobile, 'giftId': giftId}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    try {
      final body = jsonDecode(res.body);
      return {'error': body['error'] ?? 'Failed to redeem points.'};
    } catch (_) {
      return {'error': 'Failed to redeem points.'};
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 10. REFERRAL POINT (Add points for amount)
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> addReferralPoints(
    int userId,
    String mobile,
    double amount,
    String? billNo,
    String? remarks,
  ) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/add-referral-points'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'mobile': mobile,
        'amount': amount,
        'billNo': billNo,
        'remarks': remarks,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    try {
      final body = jsonDecode(res.body);
      return {'error': body['error'] ?? 'Failed to add points.'};
    } catch (_) {
      return {'error': 'Failed to add points.'};
    }
  }

  static Future<List<dynamic>> getRoyaltyHistory(
    int userId,
    String mobile,
  ) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/royalty-history?userId=$userId&mobile=$mobile'),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // 11. FOLLOWUP MASTER
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<dynamic>> getFollowupInquiries(
    int userId, {
    String? fromDate,
    String? toDate,
    int? productId,
  }) async {
    var url = '$baseUrl/followup?userId=$userId';
    if (fromDate != null) url += '&fromDate=$fromDate';
    if (toDate != null) url += '&toDate=$toDate';
    if (productId != null) url += '&productId=$productId';
    final res = await _client.get(Uri.parse(url));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    return [];
  }
}
