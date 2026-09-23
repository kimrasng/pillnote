import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pillnote/config/app_config.dart';
import 'package:pillnote/services/session_store.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, SessionStore? sessionStore})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
      _sessionStore = sessionStore ?? SessionStore.instance;

  static final ApiClient instance = ApiClient();

  final http.Client _client;
  final String _baseUrl;
  final SessionStore _sessionStore;
  Future<bool>? _refreshInFlight;

  Future<Map<String, dynamic>> health() async =>
      _asMap(await _request('GET', '/health'));

  Future<String?> startEmailLogin(String email) async {
    final response = _asMap(
      await _request('POST', '/v1/auth/email/start', body: {'email': email}),
    );
    final data = _dataMap(response);
    return data['debugCode']?.toString();
  }

  Future<UserSession> verifyEmail(String email, String code) async {
    final response = _asMap(
      await _request(
        'POST',
        '/v1/auth/email/verify',
        body: {'email': email, 'code': code},
      ),
    );
    final session = UserSession.fromApi(_dataMap(response));
    await _sessionStore.save(session);
    return session;
  }

  Future<Map<String, dynamic>> me() async =>
      _dataMap(_asMap(await _request('GET', '/v1/me', authenticated: true)));

  Future<void> logout() async {
    final refreshToken = _sessionStore.session?.refreshToken;
    try {
      if (refreshToken != null) {
        await _request(
          'POST',
          '/v1/auth/logout',
          body: {'refreshToken': refreshToken},
        );
      }
    } finally {
      await _sessionStore.clear();
    }
  }

  Future<void> logoutAll() async {
    try {
      await _request('POST', '/v1/auth/logout-all', authenticated: true);
    } finally {
      await _sessionStore.clear();
    }
  }

  Future<String?> requestAccountDeletionCode() async {
    final response = _asMap(
      await _request(
        'POST',
        '/v1/auth/email/start',
        authenticated: true,
        body: {'purpose': 'delete-account'},
      ),
    );
    return _dataMap(response)['debugCode']?.toString();
  }

  Future<void> deleteAccount(String verificationCode) async {
    await _request(
      'DELETE',
      '/v1/me',
      authenticated: true,
      body: {'verificationCode': verificationCode},
    );
    await _sessionStore.clear();
  }

  Future<List<Map<String, dynamic>>> searchDrugs(
    String name, {
    int page = 1,
    int limit = 50,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/drugs/search').replace(
      queryParameters: {'name': name, 'page': '$page', 'limit': '$limit'},
    );
    final response = _asMap(await _requestUri('GET', uri));
    final data = response['data'] as List? ?? const [];
    return data
        .whereType<Map>()
        .map((item) => _legacyDrug(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> drugDetail(String itemSeq) async {
    final response = _asMap(
      await _request('GET', '/v1/drugs/${Uri.encodeComponent(itemSeq)}'),
    );
    final detail = _dataMap(response);
    final identification = Map<String, dynamic>.from(
      detail['identification'] as Map? ?? const {},
    );
    return {
      ..._legacyDrug({...identification, ...detail}),
      'consumerInfo': detail['consumerInfo'],
      'meta': detail['meta'],
    };
  }

  Future<List<Map<String, dynamic>>> searchPharmacies({
    required double latitude,
    required double longitude,
    int radius = 3000,
    int limit = 100,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/pharmacies/search').replace(
      queryParameters: {
        'lat': '$latitude',
        'lng': '$longitude',
        'radius': '$radius',
        'limit': '$limit',
      },
    );
    return _dataList(_asMap(await _requestUri('GET', uri)));
  }

  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String pushToken,
  }) async {
    await _request(
      'PUT',
      '/v1/devices/${Uri.encodeComponent(deviceId)}',
      authenticated: true,
      body: {'platform': platform, 'pushToken': pushToken},
    );
  }

  Future<void> unregisterDevice(String deviceId) async {
    await _request(
      'DELETE',
      '/v1/devices/${Uri.encodeComponent(deviceId)}',
      authenticated: true,
    );
  }

  Future<List<Map<String, dynamic>>> guardians() async {
    final response = _asMap(
      await _request('GET', '/v1/guardians', authenticated: true),
    );
    return _dataList(response);
  }

  Future<Map<String, dynamic>> inviteGuardian({
    required String email,
    String? name,
  }) async {
    final response = _asMap(
      await _request(
        'POST',
        '/v1/guardians',
        authenticated: true,
        body: {
          'email': email,
          if (name?.trim().isNotEmpty ?? false) 'name': name,
        },
      ),
    );
    return _dataMap(response);
  }

  Future<Map<String, dynamic>> updateGuardian(
    String id, {
    String? name,
    bool? enabled,
  }) async {
    final response = _asMap(
      await _request(
        'PATCH',
        '/v1/guardians/${Uri.encodeComponent(id)}',
        authenticated: true,
        body: {'name': ?name, 'enabled': ?enabled},
      ),
    );
    return _dataMap(response);
  }

  Future<void> deleteGuardian(String id) async {
    await _request(
      'DELETE',
      '/v1/guardians/${Uri.encodeComponent(id)}',
      authenticated: true,
    );
  }

  Future<List<Map<String, dynamic>>> guardianInvitations() async {
    final response = _asMap(
      await _request('GET', '/v1/guardian-invitations', authenticated: true),
    );
    return _dataList(response);
  }

  Future<void> respondToGuardianInvitation(
    String id, {
    required bool accept,
  }) async {
    await _request(
      'POST',
      '/v1/guardian-invitations/${Uri.encodeComponent(id)}/${accept ? 'accept' : 'reject'}',
      authenticated: true,
    );
  }

  Future<void> sendMissedDoseAlert({
    required String eventKey,
    required String medicationName,
    required DateTime scheduledAt,
  }) async {
    await _request(
      'POST',
      '/v1/guardian-alerts',
      authenticated: true,
      body: {
        'eventKey': eventKey,
        'kind': 'missed-dose',
        'medicationName': medicationName,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> fetchSnapshot() async =>
      _dataMap(_asMap(await _request('GET', '/v1/sync', authenticated: true)));

  Future<Map<String, dynamic>> saveSnapshot({
    required int baseRevision,
    required Map<String, dynamic> snapshot,
  }) async => _dataMap(
    _asMap(
      await _request(
        'PUT',
        '/v1/sync',
        authenticated: true,
        body: {'baseRevision': baseRevision, 'snapshot': snapshot},
      ),
    ),
  );

  Future<void> deleteSnapshot(int baseRevision) async {
    final uri = Uri.parse(
      '$_baseUrl/v1/sync',
    ).replace(queryParameters: {'baseRevision': '$baseRevision'});
    await _requestUri('DELETE', uri, authenticated: true);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    bool authenticated = false,
    Map<String, dynamic>? body,
    bool retryAfterRefresh = true,
  }) => _requestUri(
    method,
    Uri.parse('$_baseUrl$path'),
    authenticated: authenticated,
    body: body,
    retryAfterRefresh: retryAfterRefresh,
  );

  Future<dynamic> _requestUri(
    String method,
    Uri uri, {
    bool authenticated = false,
    Map<String, dynamic>? body,
    bool retryAfterRefresh = true,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (authenticated) {
      final token = _sessionStore.session?.accessToken;
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
    late http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
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
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && authenticated && retryAfterRefresh) {
      final refreshed = await _refreshSession();
      if (refreshed) {
        return _requestUri(
          method,
          uri,
          authenticated: true,
          body: body,
          retryAfterRefresh: false,
        );
      }
    }
    if (response.statusCode == 401 && authenticated && !retryAfterRefresh) {
      await _sessionStore.clear(reason: SessionChangeReason.expired);
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

  Future<bool> _refreshSession() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final future = _performRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final current = _sessionStore.session;
    if (current == null) return false;
    try {
      final response = _asMap(
        await _request(
          'POST',
          '/v1/auth/refresh',
          body: {'refreshToken': current.refreshToken},
          retryAfterRefresh: false,
        ),
      );
      await _sessionStore.save(UserSession.fromApi(_dataMap(response)));
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionStore.clear(reason: SessionChangeReason.expired);
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

  static Map<String, dynamic> _legacyDrug(Map<String, dynamic> item) => {
    ...item,
    'ITEM_SEQ': item['itemSeq']?.toString() ?? '',
    'ITEM_NAME': item['name'],
    'ENTP_NAME': item['manufacturer'],
    'ITEM_IMAGE': item['imageUrl'],
    'CLASS_NAME': item['className'],
    'DRUG_SHAPE': item['shape'],
    'COLOR_CLASS1': item['colorFront'],
    'COLOR_CLASS2': item['colorBack'],
    'PRINT_FRONT': item['printFront'],
    'PRINT_BACK': item['printBack'],
    'FORM_CODE_NAME': item['form'],
    'LINE_FRONT': item['lineFront'],
    'LINE_BACK': item['lineBack'],
  };

  static Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map? ?? const {});

  static Map<String, dynamic> _dataMap(Map<String, dynamic> response) =>
      Map<String, dynamic>.from(response['data'] as Map? ?? const {});

  static List<Map<String, dynamic>> _dataList(Map<String, dynamic> response) =>
      (response['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
}
