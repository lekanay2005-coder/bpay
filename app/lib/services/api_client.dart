import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/app_user.dart';

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

  Map<String, dynamic> _decodeOrThrow(http.Response res) {
    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final message = body is Map && body['message'] != null
          ? (body['message'] is List
              ? (body['message'] as List).join('; ')
              : body['message'].toString())
          : res.body;
      throw ApiException(res.statusCode, message);
    }
    return body as Map<String, dynamic>;
  }

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
}
