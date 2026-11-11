import 'dart:convert';

import 'package:http/http.dart' as http;

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

class Item {
  final int id;
  final String name;
  final String description;
  final num pricePerDay;
  final num depositAmount;
  final String condition;
  final String status;
  final int categoryId;
  final String categoryName;
  final String ownerName;

  Item.fromJson(Map<String, dynamic> j)
      : id = j['itemId'] as int,
        name = (j['itemName'] ?? '') as String,
        description = (j['description'] ?? '') as String,
        pricePerDay = (j['pricePerDay'] ?? 0) as num,
        depositAmount = (j['depositAmount'] ?? 0) as num,
        condition = (j['condition'] ?? '') as String,
        status = (j['status'] ?? '') as String,
        categoryId = j['categoryId'] as int,
        categoryName = (j['categoryName'] ?? '') as String,
        ownerName = (j['ownerName'] ?? '') as String;
}

class ItemService {
  Future<List<Item>> getItems() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Items'));
    if (res.statusCode != 200) throw Exception('Không tải được danh sách đồ (${res.statusCode})');
    return (jsonDecode(res.body) as List)
        .map((e) => Item.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Category>> getCategories() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Categories'));
    if (res.statusCode != 200) throw Exception('Không tải được danh mục (${res.statusCode})');
    return (jsonDecode(res.body) as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// 250000 -> "250.000 đ"
String formatVnd(num value) {
  final s = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$buf đ';
}

const conditionLabels = {
  'New': 'Mới',
  'LikeNew': 'Như mới',
  'Good': 'Tốt',
  'Fair': 'Khá',
  'Poor': 'Cũ',
};
