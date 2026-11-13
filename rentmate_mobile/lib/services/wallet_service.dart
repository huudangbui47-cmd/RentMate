import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class WalletSummary {
  final num balance;
  final num availableBalance;
  final num pendingWithdrawAmount;
  final bool hasBankInfo;
  final String? bankName;
  final String? bankAccountName;
  final String? maskedAccountNumber;

  WalletSummary.fromJson(Map<String, dynamic> j)
      : balance = (j['balance'] ?? 0) as num,
        availableBalance = (j['availableBalance'] ?? 0) as num,
        pendingWithdrawAmount = (j['pendingWithdrawAmount'] ?? 0) as num,
        hasBankInfo = (j['hasBankInfo'] ?? false) as bool,
        bankName = j['bankName'] as String?,
        bankAccountName = j['bankAccountName'] as String?,
        maskedAccountNumber = j['maskedAccountNumber'] as String?;
}

class WalletTransaction {
  final int id;
  final num amount; // dương: tiền vào, âm: tiền ra
  final String type;
  final String status;
  final String? code;
  final int? rentalId;
  final String? note;
  final DateTime createdAt;

  WalletTransaction.fromJson(Map<String, dynamic> j)
      : id = j['transactionId'] as int,
        amount = (j['amount'] ?? 0) as num,
        type = (j['type'] ?? '') as String,
        status = (j['status'] ?? '') as String,
        code = j['code'] as String?,
        rentalId = j['rentalId'] as int?,
        note = j['note'] as String?,
        createdAt = DateTime.parse(j['createdAt'] as String);
}

class DepositRequest {
  final int id;
  final String code;
  final num amount;
  final String? receiverBankName;
  final String? receiverAccountNumber;
  final String? receiverAccountName;
  final String? qrImageUrl;

  DepositRequest.fromJson(Map<String, dynamic> j)
      : id = j['transactionId'] as int,
        code = (j['code'] ?? '') as String,
        amount = (j['amount'] ?? 0) as num,
        receiverBankName = j['receiverBankName'] as String?,
        receiverAccountNumber = j['receiverAccountNumber'] as String?,
        receiverAccountName = j['receiverAccountName'] as String?,
        qrImageUrl = j['qrImageUrl'] as String?;
}

// Theo WalletTransactionType / WalletTransactionStatus trong RentMate.Core.
const walletTypeLabels = {
  'Deposit': 'Nạp tiền',
  'Withdraw': 'Rút tiền',
  'RentalPayment': 'Thanh toán đơn thuê',
  'RentalIncome': 'Tiền cho thuê',
  'DepositRefund': 'Hoàn tiền cọc',
  'Compensation': 'Tiền bồi thường',
  'Refund': 'Hoàn tiền đơn hủy',
};

const walletStatusLabels = {
  'Pending': 'Đang chờ duyệt',
  'Completed': 'Thành công',
  'Rejected': 'Bị từ chối',
};

class WalletService {
  Uri _url(String path) => Uri.parse('$apiBaseUrl/api/Wallet$path');

  Future<WalletSummary> getSummary() async {
    final res = await http.get(_url(''), headers: await AuthService().authHeaders());
    checkResponse(res);
    return WalletSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<WalletTransaction>> getHistory() async {
    final res = await http.get(_url('/transactions'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List)
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DepositRequest> createDeposit(num amount) async {
    final res = await http.post(
      _url('/deposits'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'amount': amount}),
    );
    checkResponse(res);
    return DepositRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<DepositRequest> getDeposit(int id) async {
    final res = await http.get(_url('/deposits/$id'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return DepositRequest.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> updateBankInfo({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final res = await http.put(
      _url('/bank-info'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({
        'bankName': bankName,
        'bankAccountNumber': accountNumber,
        'bankAccountName': accountName,
      }),
    );
    checkResponse(res);
  }

  Future<void> createWithdraw(num amount) async {
    final res = await http.post(
      _url('/withdrawals'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'amount': amount}),
    );
    checkResponse(res);
  }
}
