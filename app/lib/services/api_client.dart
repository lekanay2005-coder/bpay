import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/app_user.dart';
import '../models/kyc.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The app's only HTTP client. It talks exclusively to the PayFlex
/// backend (never to BMONI directly) — see backend/src/bmoni for why.
class ApiClient {
  final String baseUrl;
  ApiClient({this.baseUrl = Env.backendBaseUrl});

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _decodeAnyOrThrow(http.Response res) {
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final message = body is Map && body['message'] != null
          ? (body['message'] is List
              ? (body['message'] as List).join('; ')
              : body['message'].toString())
          : res.body;
      throw ApiException(res.statusCode, message);
    }
    return body;
  }

  Map<String, dynamic> _decodeOrThrow(http.Response res) =>
      _decodeAnyOrThrow(res) as Map<String, dynamic>;

  List<dynamic> _decodeListOrThrow(http.Response res) =>
      _decodeAnyOrThrow(res) as List<dynamic>;

  Future<AppUser> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    final res = await http.post(
      _uri('/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber,
      }),
    );
    return AppUser.fromJson(_decodeOrThrow(res));
  }

  Future<AppUser> getUser(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId'));
    return AppUser.fromJson(_decodeOrThrow(res));
  }

  Future<AppUser> setOwnerAddress(String appUserId, String ownerAddress) async {
    final res = await http.patch(
      _uri('/users/$appUserId/owner-address'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ownerAddress': ownerAddress}),
    );
    return AppUser.fromJson(_decodeOrThrow(res));
  }

  Future<List<String>> getSupportedCurrencies() async {
    final res = await http.get(_uri('/onboarding/supported-currencies'));
    final body = _decodeOrThrow(res);
    return List<String>.from(body['currencies'] as List);
  }

  Future<({String challengeId, String message})> requestOwnerProofChallenge(
    String appUserId,
    String currency,
  ) async {
    final res = await http.post(
      _uri('/users/$appUserId/smart-wallets/owner-proof-challenges'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'currency': currency}),
    );
    final body = _decodeOrThrow(res);
    return (
      challengeId: body['challengeId'] as String,
      message: body['message'] as String,
    );
  }

  Future<SmartWallet> createSmartWallet(
    String appUserId, {
    required String currency,
    required String ownerProofChallengeId,
    required String ownerProofSignature,
  }) async {
    final res = await http.post(
      _uri('/users/$appUserId/smart-wallets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'currency': currency,
        'ownerProofChallengeId': ownerProofChallengeId,
        'ownerProofSignature': ownerProofSignature,
      }),
    );
    return SmartWallet.fromJson(_decodeOrThrow(res));
  }

  Future<Map<String, dynamic>> getOnboardingStatus(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId/onboarding/status'));
    return _decodeOrThrow(res);
  }

  // --- KYC wizard (Phase 2) ---------------------------------------------

  Future<KycOptions> getKycOptions(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId/kyc/options'));
    return KycOptions.fromJson(_decodeOrThrow(res));
  }

  Future<List<KycOccupation>> getKycOccupations(String appUserId, String search) async {
    final res = await http.get(_uri('/users/$appUserId/kyc/occupations?search=$search'));
    return _decodeListOrThrow(res)
        .map((e) => KycOccupation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// All three document endpoints share this shape on our own backend:
  /// multipart with a `file` field plus whatever text fields BMONI needs
  /// for that document type (see KycController — it maps `file` to
  /// BMONI's own inconsistent field names internally, so the app only
  /// has to remember one convention).
  Future<void> _submitDocument(
    String path,
    File file,
    Map<String, String> fields,
  ) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _decodeAnyOrThrow(res);
  }

  Future<void> submitIdentificationDocument(
    String appUserId,
    File file, {
    required String type,
    required String documentNumber,
    required String issuingCountry,
  }) => _submitDocument(
        '/users/$appUserId/kyc/documents/identification',
        file,
        {'type': type, 'documentNumber': documentNumber, 'issuingCountry': issuingCountry},
      );

  Future<void> submitProofOfAddress(String appUserId, File file, {required String type}) =>
      _submitDocument('/users/$appUserId/kyc/documents/proof-of-address', file, {'type': type});

  Future<void> submitBiometric(String appUserId, File file, {required String type}) =>
      _submitDocument('/users/$appUserId/kyc/documents/biometric', file, {'type': type});

  Future<Map<String, dynamic>> patchKyc(String appUserId, Map<String, dynamic> body) async {
    final res = await http.patch(
      _uri('/users/$appUserId/kyc'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeOrThrow(res);
  }

  Future<KycReadiness> getKycReadiness(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId/kyc/readiness'));
    return KycReadiness.fromJson(_decodeOrThrow(res));
  }

  Future<KycReadiness> getUsdReadiness(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId/kyc/usd-readiness'));
    return KycReadiness.fromJson(_decodeOrThrow(res));
  }

  /// The valid sumsubLevelName set is dynamic server-side (depends on
  /// which documents have been submitted) — a 400 here echoes BMONI's
  /// currently-valid list verbatim via ApiException.message. See
  /// backend/src/kyc/dto/kyc-activate.dto.ts.
  Future<Map<String, dynamic>> activateKyc(
    String appUserId, {
    required String currency,
    required String sumsubLevelName,
  }) async {
    final res = await http.post(
      _uri('/users/$appUserId/kyc/activate?currency=$currency'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sumsubLevelName': sumsubLevelName}),
    );
    return _decodeOrThrow(res);
  }

  // --- Rail onboarding (Phase 2: NGN + USD) -------------------------------

  Future<Map<String, dynamic>> startNigeria(
    String appUserId, {
    required String bvn,
    required int ngnWalletIndex,
  }) async {
    final res = await http.post(
      _uri('/users/$appUserId/onboarding/start-nigeria'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'bvn': bvn, 'ngnWalletIndex': ngnWalletIndex}),
    );
    return _decodeOrThrow(res);
  }

  Future<Map<String, dynamic>> startUsa(String appUserId) async {
    final res = await http.post(_uri('/users/$appUserId/onboarding/start-usa'));
    return _decodeOrThrow(res);
  }

  Future<Map<String, dynamic>> getVbaUsdStatus(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId/vba/usd'));
    return _decodeOrThrow(res);
  }

  // --- Wallet home (Phase 2: balances + history) --------------------------

  Future<List<SmartWallet>> listWallets(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId/wallets'));
    return _decodeListOrThrow(res)
        .map((e) => SmartWallet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Balance>> listBalances(String appUserId) async {
    final res = await http.get(_uri('/users/$appUserId/balances'));
    final body = _decodeOrThrow(res);
    return (body['balances'] as List)
        .map((e) => Balance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Transaction>> getTransactions(String appUserId, String smartWalletId) async {
    final res = await http.get(_uri('/users/$appUserId/wallets/$smartWalletId/transactions'));
    final body = _decodeOrThrow(res);
    return (body['transactions'] as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
