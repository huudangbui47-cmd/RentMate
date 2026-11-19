import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'item_service.dart';

class ConditionReport {
  final String reportType; // "BeforeRental" | "AfterRental"
  final String condition;
  final String description;
  final List<String> imageUrls;
  final DateTime createdAt;

  // AI nhận xét (null khi chưa bật AI hoặc AI lỗi)
  final String? aiSummary;
  final List<String> aiDamages;
  final String? aiSuggestedCondition;
  final bool? aiNewDamageFound;
  final num? aiSuggestedDeduction;

  ConditionReport.fromJson(Map<String, dynamic> j)
      : reportType = (j['reportType'] ?? '') as String,
        condition = (j['condition'] ?? '') as String,
        description = (j['description'] ?? '') as String,
        imageUrls = ((j['imageUrls'] ?? []) as List).cast<String>(),
        createdAt = DateTime.parse(j['createdAt'] as String),
        aiSummary = j['aiSummary'] as String?,
        aiDamages = ((j['aiDamages'] ?? []) as List).cast<String>(),
        aiSuggestedCondition = j['aiSuggestedCondition'] as String?,
        aiNewDamageFound = j['aiNewDamageFound'] as bool?,
        aiSuggestedDeduction = j['aiSuggestedDeduction'] as num?;

  bool get hasAi => aiSummary != null && aiSummary!.isNotEmpty;
}

// Theo enum ConditionReportType trong RentMate.Core.
const reportTypeValues = {'BeforeRental': 1, 'AfterRental': 2};
const reportTypeLabels = {
  'BeforeRental': 'Biên bản lúc giao',
  'AfterRental': 'Biên bản lúc nhận lại',
};

/// Khớp ConditionReportService.MaxImages trên Api.
const maxReportImages = 6;

class ConditionReportService {
  Uri _url(int rentalId) => Uri.parse('$apiBaseUrl/api/rentals/$rentalId/condition-reports');

  Future<List<ConditionReport>> getReports(int rentalId) async {
    final res = await http.get(_url(rentalId), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List)
        .map((e) => ConditionReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Gửi ảnh thật (multipart). AI xem ảnh nên có thể mất 10-30 giây.
  Future<ConditionReport> create({
    required int rentalId,
    required String reportType,
    required String condition,
    required String description,
    required List<XFile> images,
  }) async {
    final headers = await AuthService().authHeaders();
    headers.remove('Content-Type'); // MultipartRequest tự đặt Content-Type
    final req = http.MultipartRequest('POST', _url(rentalId))
      ..headers.addAll(headers)
      ..fields['reportType'] = '${reportTypeValues[reportType]}'
      ..fields['condition'] = '${conditionValues[condition]}'
      ..fields['description'] = description;
    for (final f in images) {
      req.files.add(await http.MultipartFile.fromPath('files', f.path, filename: f.name));
    }
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 90)));
    checkResponse(res);
    return ConditionReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
