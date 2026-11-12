import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'item_service.dart';

class ConditionReport {
  final String reportType; // "BeforeRental" | "AfterRental"
  final String condition;
  final String description;
  final List<String> imageUrls;
  final DateTime createdAt;

  ConditionReport.fromJson(Map<String, dynamic> j)
      : reportType = (j['reportType'] ?? '') as String,
        condition = (j['condition'] ?? '') as String,
        description = (j['description'] ?? '') as String,
        imageUrls = ((j['imageUrls'] ?? []) as List).cast<String>(),
        createdAt = DateTime.parse(j['createdAt'] as String);
}

// Theo enum ConditionReportType trong RentMate.Core.
const reportTypeValues = {'BeforeRental': 1, 'AfterRental': 2};
const reportTypeLabels = {
  'BeforeRental': 'Biên bản trước khi giao',
  'AfterRental': 'Biên bản sau khi trả',
};

class ConditionReportService {
  Uri _url(int rentalId) => Uri.parse('$apiBaseUrl/api/rentals/$rentalId/condition-reports');

  Future<List<ConditionReport>> getReports(int rentalId) async {
    final res = await http.get(_url(rentalId), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List)
        .map((e) => ConditionReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required int rentalId,
    required String reportType,
    required String condition,
    required String description,
    required List<String> imageUrls,
  }) async {
    final res = await http.post(
      _url(rentalId),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({
        'reportType': reportTypeValues[reportType],
        'condition': conditionValues[condition],
        'description': description,
        'imageUrls': imageUrls,
      }),
    );
    checkResponse(res);
  }
}
