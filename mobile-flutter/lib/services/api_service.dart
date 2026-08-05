import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _envApiUrl = String.fromEnvironment('API_URL');

final String apiUrl = _envApiUrl.isNotEmpty
    ? _envApiUrl
    : (kIsWeb ? 'http://localhost:8000/api' : 'http://10.0.2.2:8000/api');

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    http.Client? client,
    FlutterSecureStorage? storage,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage storage;
  final Duration timeout;

  Future<Map<String, dynamic>> get(String path) async {
    final token = await _readTokenSafely();
    final response = await _client
        .get(Uri.parse('$apiUrl$path'), headers: _headers(token))
        .timeout(timeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _readTokenSafely();
    final response = await _client
        .post(
          Uri.parse('$apiUrl$path'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _readTokenSafely();
    final response = await _client
        .patch(
          Uri.parse('$apiUrl$path'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _readTokenSafely();
    final response = await _client
        .put(
          Uri.parse('$apiUrl$path'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> items(String path) async {
    final data = await get(path);
    final rawItems = data['items'];
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveToken(String token) =>
      storage.write(key: 'token', value: token);

  Future<String?> readToken() => _readTokenSafely();

  Future<String?> _readTokenSafely() async {
    try {
      return await storage.read(key: 'token');
    } catch (_) {
      // Android can restore encrypted preferences without their original key.
      // Treat that stale session as logged out instead of blocking the app.
      try {
        await storage.deleteAll();
      } catch (_) {
        // The next successful login will replace the unusable local session.
      }
      return null;
    }
  }

  Future<void> clearToken() => storage.delete(key: 'token');

  Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body.isEmpty ? '{}' : response.body);
      data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{'data': decoded};
    } on FormatException {
      throw ApiException(
        'Le serveur a renvoye une reponse invalide.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        throw ApiException(
          errors.values.join('\n'),
          statusCode: response.statusCode,
        );
      }
      throw ApiException(
        '${data['message'] ?? data['error'] ?? 'Erreur API'}',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  void close() => _client.close();
}

final api = ApiService();

String euros(dynamic value) =>
    '${(double.tryParse('$value') ?? 0).toStringAsFixed(2)} EUR';
