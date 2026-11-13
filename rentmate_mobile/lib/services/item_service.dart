import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

class Category {
  final int id;
  final String name;
  final int? parentId;

  Category.fromJson(Map<String, dynamic> j)
      : id = j['categoryId'] as int,
        name = (j['categoryName'] ?? '') as String,
        parentId = j['parentCategoryId'] as int?;
}

/// Api trả đường dẫn tương đối (/uploads/items/...), ghép với địa chỉ Api để hiển thị.
String imageFullUrl(String path) => path.startsWith('http') ? path : '$apiBaseUrl$path';

/// Mỗi món đồ tối đa 8 ảnh (theo ItemService.MaxImagesPerItem).
const maxItemImages = 8;

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
  final int categoryId;
  final String categoryName;
  final String ownerId;
  final String ownerName;
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
        categoryId = j['categoryId'] as int,
        categoryName = (j['categoryName'] ?? '') as String,
        ownerId = (j['ownerId'] ?? '') as String,
        ownerName = (j['ownerName'] ?? '') as String,
        createdAt = DateTime.parse(j['createdAt'] as String),
        imageUrl = j['imageUrl'] == null ? null : imageFullUrl(j['imageUrl'] as String),
        images = ((j['images'] ?? []) as List)
            .map((e) => ItemImage.fromJson(e as Map<String, dynamic>))
            .toList();
}

class ItemService {
  /// Đồ đã được duyệt (trang chủ).
  Future<List<Item>> getItems() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Items'));
    if (res.statusCode != 200) throw Exception('Không tải được danh sách đồ (${res.statusCode})');
    return _parseList(res.body);
  }

  /// Đồ của tôi, mọi trạng thái (kể cả chờ duyệt / bị từ chối).
  Future<List<Item>> getMyItems() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Items/my'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
    return _parseList(res.body);
  }

  Future<Item> getItem(int id) async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Items/$id'),
      headers: await AuthService().optionalAuthHeaders(),
    );
    if (res.statusCode == 404) throw Exception('Đồ này không còn trên RentMate');
    if (res.statusCode != 200) throw Exception('Không tải được thông tin đồ (${res.statusCode})');
    return Item.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Danh mục đang hoạt động, mỗi danh mục cha đứng trước các danh mục con của nó.
  Future<List<Category>> getCategories() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Categories'));
    if (res.statusCode != 200) throw Exception('Không tải được danh mục (${res.statusCode})');
    return (jsonDecode(res.body) as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// id == null: đăng đồ mới (POST); có id: sửa đồ (PUT). Cả hai đều phải chờ duyệt lại.
  /// Trả về id của món đồ (để tải ảnh lên sau đó).
  Future<int> saveItem({
    int? id,
    required String name,
    required String description,
    required num pricePerDay,
    required num depositAmount,
    required int categoryId,
    required String condition,
  }) async {
    final body = jsonEncode({
      'itemName': name,
      'description': description,
      'pricePerDay': pricePerDay,
      'depositAmount': depositAmount,
      'categoryId': categoryId,
      'condition': conditionValues[condition],
    });
    final headers = await AuthService().authHeaders();
    final res = id == null
        ? await http.post(Uri.parse('$apiBaseUrl/api/Items'), headers: headers, body: body)
        : await http.put(Uri.parse('$apiBaseUrl/api/Items/$id'), headers: headers, body: body);
    checkResponse(res);
    return id ?? (jsonDecode(res.body) as Map<String, dynamic>)['itemId'] as int;
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
    final res = await http.delete(
      Uri.parse('$apiBaseUrl/api/Items/$id'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }

  List<Item> _parseList(String body) => (jsonDecode(body) as List)
      .map((e) => Item.fromJson(e as Map<String, dynamic>))
      .toList();
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
  return '${negative ? '-' : ''}$buf đ';
}

const conditionLabels = {
  'New': 'Mới',
  'LikeNew': 'Như mới',
  'Good': 'Tốt',
  'Fair': 'Khá',
  'Damaged': 'Hư hỏng',
};

// API nhận condition dạng số, theo enum ItemCondition trong RentMate.Core.
const conditionValues = {'New': 1, 'LikeNew': 2, 'Good': 3, 'Fair': 4, 'Damaged': 5};

// Theo enum ItemStatus trong RentMate.Core.
const itemStatusLabels = {
  'Available': 'Đang cho thuê',
  'Rented': 'Có người đang thuê',
  'Unavailable': 'Bị tạm ngưng',
  'Hidden': 'Đã xóa',
  'PendingApproval': 'Chờ duyệt',
  'Rejected': 'Bị từ chối',
};
