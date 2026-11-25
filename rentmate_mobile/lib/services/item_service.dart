import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'config_service.dart';
import '../l10n/l10n.dart';

class Category {
  final int id;
  final String name;
  final int? parentId;

  /// Icon quản trị viên chọn trên AdminSite (smartphone, camera...); null thì đoán theo tên.
  final String? icon;

  Category.fromJson(Map<String, dynamic> j)
    : id = j['categoryId'] as int,
      name = (j['categoryName'] ?? '') as String,
      parentId = j['parentCategoryId'] as int?,
      icon = j['icon'] as String? {
    if (icon != null) categoryIconKeys[name.toLowerCase()] = icon!;
  }
}

/// Tên danh mục → icon admin chọn, ghi lại mỗi khi tải danh sách danh mục.
final Map<String, String> categoryIconKeys = {};

/// Api trả đường dẫn tương đối (/uploads/items/...), ghép với địa chỉ Api để hiển thị.
String imageFullUrl(String path) => path.startsWith('http') ? path : '$apiBaseUrl$path';

/// Số ảnh tối đa mỗi món đồ, theo cài đặt hệ thống (AdminSite > Cài đặt hệ thống).
int get maxItemImages => AppConfig.maxItemImages;

class ItemImage {
  final int id;
  final String url;
  final bool isPrimary;

  ItemImage.fromJson(Map<String, dynamic> j)
    : id = j['imageId'] as int,
      url = imageFullUrl(j['imageUrl'] as String),
      isPrimary = (j['isPrimary'] ?? false) as bool;
}

class Item {
  final int id;
  final String name;
  final String description;
  final num pricePerDay;
  final num depositAmount;
  final String condition;
  final String status;
  final String? rejectionReason;
  final String? province; // tỉnh/thành nơi nhận đồ, null với đồ đăng trước khi có tính năng này
  final String? area; // phường/xã hoặc khu vực, không bắt buộc
  final int discountPercent; // ưu đãi thuê dài ngày, 0 = không có
  final int discountMinDays; // áp dụng khi thuê từ số ngày này
  final int categoryId;
  final String categoryName;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final int rentCount; // số lần được thuê, dùng cho "Được thuê nhiều nhất"
  final DateTime createdAt;
  final String? imageUrl; // ảnh chính, null nếu chưa có ảnh
  final List<ItemImage> images; // ảnh chính đứng đầu

  Item.fromJson(Map<String, dynamic> j)
    : id = j['itemId'] as int,
      name = (j['itemName'] ?? '') as String,
      description = (j['description'] ?? '') as String,
      pricePerDay = (j['pricePerDay'] ?? 0) as num,
      depositAmount = (j['depositAmount'] ?? 0) as num,
      condition = (j['condition'] ?? '') as String,
      status = (j['status'] ?? '') as String,
      rejectionReason = j['rejectionReason'] as String?,
      province = j['province'] as String?,
      area = j['area'] as String?,
      discountPercent = (j['discountPercent'] ?? 0) as int,
      discountMinDays = (j['discountMinDays'] ?? 0) as int,
      categoryId = j['categoryId'] as int,
      categoryName = (j['categoryName'] ?? '') as String,
      ownerId = (j['ownerId'] ?? '') as String,
      ownerName = (j['ownerName'] ?? '') as String,
      ownerAvatarUrl = j['ownerAvatarUrl'] == null ? null : imageFullUrl(j['ownerAvatarUrl'] as String),
      createdAt = DateTime.parse(j['createdAt'] as String),
      rentCount = (j['rentCount'] ?? 0) as int,
      imageUrl = j['imageUrl'] == null ? null : imageFullUrl(j['imageUrl'] as String),
      images = ((j['images'] ?? []) as List).map((e) => ItemImage.fromJson(e as Map<String, dynamic>)).toList();
}

/// Ưu đãi thuê dài ngày: tính giống RentalService ở server (làm tròn tới đồng).
extension ItemDeal on Item {
  bool get hasDeal => discountPercent > 0;

  /// Số tiền được giảm khi thuê [days] ngày (0 nếu chưa đủ số ngày)
  num discountFor(int days) =>
      hasDeal && days >= discountMinDays ? (pricePerDay * days * discountPercent / 100).round() : 0;

  /// Tiền thuê [days] ngày sau ưu đãi
  num rentFor(int days) => pricePerDay * days - discountFor(days);
}

extension ItemLocation on Item {
  /// "Phường Bến Thành, TP. Hồ Chí Minh" hoặc null nếu chưa có nơi nhận đồ.
  String? get locationText => province == null ? null : ((area ?? '').isEmpty ? province : '$area, $province');
}

class ItemService {
  /// 34 tỉnh/thành (Api giữ danh sách để app và server luôn khớp nhau).
  Future<List<String>> getProvinces() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Items/provinces'));
    if (res.statusCode != 200) throw Exception(tr('Không tải được danh sách tỉnh/thành ({0})', [res.statusCode]));
    return (jsonDecode(res.body) as List).cast<String>();
  }

  /// Đồ đã được duyệt (trang chủ).
  Future<List<Item>> getItems() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Items'));
    if (res.statusCode != 200) throw Exception(tr('Không tải được danh sách đồ ({0})', [res.statusCode]));
    return _parseList(res.body);
  }

  /// Đồ của tôi, mọi trạng thái (kể cả chờ duyệt / bị từ chối).
  Future<List<Item>> getMyItems() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Items/my'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return _parseList(res.body);
  }

  Future<Item> getItem(int id) async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Items/$id'),
      headers: await AuthService().optionalAuthHeaders(),
    );
    if (res.statusCode == 404) throw Exception(tr('Đồ này không còn trên RentMate'));
    if (res.statusCode != 200) throw Exception(tr('Không tải được thông tin đồ ({0})', [res.statusCode]));
    return Item.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Danh mục đang hoạt động, mỗi danh mục cha đứng trước các danh mục con của nó.
  Future<List<Category>> getCategories() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Categories'));
    if (res.statusCode != 200) throw Exception(tr('Không tải được danh mục ({0})', [res.statusCode]));
    return (jsonDecode(res.body) as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// id == null: đăng đồ mới (POST); có id: sửa đồ (PUT). Cả hai đều phải chờ duyệt lại.
  /// Trả về món đồ sau khi lưu (có id để tải ảnh, có status để biết có phải chờ duyệt lại không).
  Future<Item> saveItem({
    int? id,
    required String name,
    required String description,
    required num pricePerDay,
    required num depositAmount,
    required int categoryId,
    required String condition,
    required String province,
    String? area,
    int discountPercent = 0,
    int discountMinDays = 0,
  }) async {
    final body = jsonEncode({
      'itemName': name,
      'description': description,
      'pricePerDay': pricePerDay,
      'depositAmount': depositAmount,
      'categoryId': categoryId,
      'condition': conditionValues[condition],
      'province': province,
      'area': area,
      'discountPercent': discountPercent,
      'discountMinDays': discountMinDays,
    });
    final headers = await AuthService().authHeaders();
    final res = id == null
        ? await http.post(Uri.parse('$apiBaseUrl/api/Items'), headers: headers, body: body)
        : await http.put(Uri.parse('$apiBaseUrl/api/Items/$id'), headers: headers, body: body);
    checkResponse(res);
    return Item.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Tải nhiều ảnh lên một lần (multipart, field "files").
  Future<void> uploadImages(int itemId, List<XFile> files) async {
    final headers = await AuthService().authHeaders();
    headers.remove('Content-Type'); // MultipartRequest tự đặt Content-Type
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/Items/$itemId/images'))
      ..headers.addAll(headers);
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath('files', f.path, filename: f.name));
    }
    final res = await http.Response.fromStream(await req.send());
    checkResponse(res);
  }

  Future<void> deleteImage(int itemId, int imageId) async {
    final res = await http.delete(
      Uri.parse('$apiBaseUrl/api/Items/$itemId/images/$imageId'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }

  Future<void> setPrimaryImage(int itemId, int imageId) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Items/$itemId/images/$imageId/primary'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }

  Future<void> deleteItem(int id) async {
    final res = await http.delete(Uri.parse('$apiBaseUrl/api/Items/$id'), headers: await AuthService().authHeaders());
    checkResponse(res);
  }

  List<Item> _parseList(String body) =>
      (jsonDecode(body) as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
}

// 250000 -> "250.000 đ"
String formatVnd(num value) {
  final negative = value < 0;
  final s = value.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return tr('{0}{1} đ', [negative ? '-' : '', buf]);
}

Map<String, String> get conditionLabels => {
  'New': tr('Mới'),
  'LikeNew': tr('Như mới'),
  'Good': tr('Tốt'),
  'Fair': tr('Khá'),
  'Damaged': tr('Hư hỏng'),
};

// API nhận condition dạng số, theo enum ItemCondition trong RentMate.Core.
const conditionValues = {'New': 1, 'LikeNew': 2, 'Good': 3, 'Fair': 4, 'Damaged': 5};

// Theo enum ItemStatus trong RentMate.Core.
Map<String, String> get itemStatusLabels => {
  'Available': tr('Đang cho thuê'),
  'Rented': tr('Có người đang thuê'),
  'Unavailable': tr('Bị tạm ngưng'),
  'Hidden': tr('Đã xóa'),
  'PendingApproval': tr('Chờ duyệt'),
  'Rejected': tr('Bị từ chối'),
};
