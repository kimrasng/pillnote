import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pillnote/config/app_config.dart';
import 'package:pillnote/services/api/api_exception.dart';
import 'package:pillnote/services/session_store.dart';

/// JSON transport owns timeouts, API errors, and shared session refresh retries.
/// Endpoint methods share one instance so concurrent 401s rotate tokens once.
class ApiTransport {
  ApiTransport({
    required this._sessionStore,
    http.Client? client,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  final SessionStore _sessionStore;
  Future<bool>? _refreshInFlight;
  int? _refreshGeneration;

  Uri uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> request(
    String method,
    String path, {
    bool authenticated = false,
    Map<String, dynamic>? body,
    bool retryAfterRefresh = true,
  }) => requestUri(
    method,
    uri(path),
    authenticated: authenticated,
    body: body,
    retryAfterRefresh: retryAfterRefresh,
  );

  Future<dynamic> requestUri(
    String method,
    Uri uri, {
    bool authenticated = false,
    Map<String, dynamic>? body,
    bool retryAfterRefresh = true,
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? _sessionStore.generation;
    final originalSession = _sessionStore.session;
    if (authenticated && generation != _sessionStore.generation) {
      throw _sessionChanged;
    }
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (authenticated) {
      final token = originalSession?.accessToken;
      if (token == null) {
        throw const ApiException(
          statusCode: 401,
          code: 'AUTH_REQUIRED',
          message: '로그인이 필요합니다.',
        );
      }
      headers['authorization'] = 'Bearer $token';
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    late http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        code: 'NETWORK_TIMEOUT',
        message: '서버 응답 시간이 초과되었습니다.',
      );
    } on SocketException {
      throw const ApiException(
        statusCode: 0,
        code: 'NETWORK_UNAVAILABLE',
        message: '서버에 연결할 수 없습니다.',
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        code: 'NETWORK_UNAVAILABLE',
        message: '서버에 연결할 수 없습니다.',
      );
    }
    if (authenticated && generation != _sessionStore.generation) {
      throw _sessionChanged;
    }
    if (response.statusCode == 401 && authenticated && retryAfterRefresh) {
      // A late 401 may have used a token that another request already rotated.
      final refreshed =
          _sessionStore.session?.accessToken != originalSession?.accessToken
          ? _sessionStore.isLoggedIn
          : await _refreshSession(originalSession!, generation);
      if (refreshed) {
        return requestUri(
          method,
          uri,
          authenticated: true,
          body: body,
          retryAfterRefresh: false,
          expectedGeneration: generation,
        );
      }
    }
    if (response.statusCode == 401 && authenticated && !retryAfterRefresh) {
      await _sessionStore.clear(
        reason: SessionChangeReason.expired,
        expectedGeneration: generation,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'INVALID_SERVER_RESPONSE',
        message: '서버 응답을 해석할 수 없습니다.',
      );
    }
  }

  static const _sessionChanged = ApiException(
    statusCode: 401,
    code: 'SESSION_CHANGED',
    message: '로그인 상태가 변경되었습니다. 다시 시도해주세요.',
  );

  Future<bool> _refreshSession(UserSession current, int generation) {
    final inFlight = _refreshInFlight;
    if (inFlight != null && _refreshGeneration == generation) return inFlight;

    final future = _performRefresh(current, generation);
    _refreshInFlight = future;
    _refreshGeneration = generation;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh(UserSession current, int generation) async {
    try {
      final response = _asMap(
        await request(
          'POST',
          '/v1/auth/refresh',
          body: {'refreshToken': current.refreshToken},
          retryAfterRefresh: false,
        ),
      );
      final replacement = UserSession.fromApi(_dataMap(response));
      if (replacement.userId != current.userId) {
        throw const ApiException(
          statusCode: 502,
          code: 'INVALID_SERVER_RESPONSE',
          message: '서버의 로그인 응답이 올바르지 않습니다.',
        );
      }
      return await _sessionStore.replaceIfCurrent(
        current,
        replacement,
        generation,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionStore.clear(
          reason: SessionChangeReason.expired,
          expectedGeneration: generation,
        );
        return false;
      }
      rethrow;
    }
  }

  ApiException _apiException(http.Response response) {
    try {
      final payload = _asMap(jsonDecode(response.body));
      final error = Map<String, dynamic>.from(
        payload['error'] as Map? ?? const {},
      );
      return ApiException(
        statusCode: response.statusCode,
        code: error['code']?.toString() ?? 'HTTP_ERROR',
        message: error['message']?.toString() ?? '요청을 처리하지 못했습니다.',
        details: error['details'],
      );
    } catch (_) {
      return ApiException(
        statusCode: response.statusCode,
        code: 'HTTP_ERROR',
        message: '서버가 HTTP ${response.statusCode}를 반환했습니다.',
      );
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map? ?? const {});

  static Map<String, dynamic> _dataMap(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}
