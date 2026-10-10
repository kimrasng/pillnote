import 'package:http/http.dart' as http;
import 'package:pillnote/services/api/api_transport.dart';
import 'package:pillnote/services/session_store.dart';

export 'package:pillnote/services/api/api_exception.dart';

/// Backend endpoints and response mappings. Request and authentication policy
/// belong to ApiTransport, shared by every endpoint on this client.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, SessionStore? sessionStore})
    : _transport = ApiTransport(
        client: client,
        baseUrl: baseUrl,
        sessionStore: sessionStore ?? SessionStore.instance,
      ),
      _sessionStore = sessionStore ?? SessionStore.instance;

  static final ApiClient instance = ApiClient();

  final ApiTransport _transport;
  final SessionStore _sessionStore;
  int emailResendCooldownSeconds = 60;

  Future<Map<String, dynamic>> health() async =>
      _asMap(await _transport.request('GET', '/health'));

  Future<String?> startEmailLogin(String email) async {
    final response = _asMap(
      await _transport.request(
        'POST',
        '/v1/auth/email/start',
        body: {'email': email},
      ),
    );
    final data = _dataMap(response);
    final cooldown = data['resendAfterSeconds'];
    emailResendCooldownSeconds =
        cooldown is num && cooldown >= 1 && cooldown <= 3600
        ? cooldown.ceil()
        : 60;
    return data['debugCode']?.toString();
  }

  Future<UserSession> verifyEmail(String email, String code) async {
    final response = _asMap(
      await _transport.request(
        'POST',
        '/v1/auth/email/verify',
        body: {'email': email, 'code': code},
      ),
    );
    final session = UserSession.fromApi(_dataMap(response));
    await _sessionStore.save(session);
    return session;
  }

  Future<Map<String, dynamic>> me() async => _dataMap(
    _asMap(await _transport.request('GET', '/v1/me', authenticated: true)),
  );

  Future<void> logout() async {
    final refreshToken = _sessionStore.session?.refreshToken;
    // Invalidate pending authenticated requests before contacting the server.
    await _sessionStore.clear();
    if (refreshToken != null) {
      await _transport.request(
        'POST',
        '/v1/auth/logout',
        body: {'refreshToken': refreshToken},
      );
    }
  }

  Future<void> logoutAll() async {
    final generation = _sessionStore.generation;
    await _transport.request(
      'POST',
      '/v1/auth/logout-all',
      authenticated: true,
    );
    await _sessionStore.clear(expectedGeneration: generation);
  }

  Future<String?> requestAccountDeletionCode() async {
    final response = _asMap(
      await _transport.request(
        'POST',
        '/v1/auth/email/start',
        authenticated: true,
        body: {'purpose': 'delete-account'},
      ),
    );
    return _dataMap(response)['debugCode']?.toString();
  }

  Future<void> deleteAccount(String verificationCode) async {
    final generation = _sessionStore.generation;
    await _transport.request(
      'DELETE',
      '/v1/me',
      authenticated: true,
      body: {'verificationCode': verificationCode},
    );
    await _sessionStore.clear(expectedGeneration: generation);
  }

  Future<List<Map<String, dynamic>>> searchDrugs(
    String name, {
    int page = 1,
    int limit = 50,
  }) async {
    final uri = _transport
        .uri('/v1/drugs/search')
        .replace(
          queryParameters: {'name': name, 'page': '$page', 'limit': '$limit'},
        );
    final response = _asMap(await _transport.requestUri('GET', uri));
    final data = response['data'] as List? ?? const [];
    return data
        .whereType<Map>()
        .map((item) => _legacyDrug(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> drugDetail(String itemSeq) async {
    final response = _asMap(
      await _transport.request(
        'GET',
        '/v1/drugs/${Uri.encodeComponent(itemSeq)}',
      ),
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
    final uri = _transport
        .uri('/v1/pharmacies/search')
        .replace(
          queryParameters: {
            'lat': '$latitude',
            'lng': '$longitude',
            'radius': '$radius',
            'limit': '$limit',
          },
        );
    return _dataList(_asMap(await _transport.requestUri('GET', uri)));
  }

  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String pushToken,
  }) async {
    await _transport.request(
      'PUT',
      '/v1/devices/${Uri.encodeComponent(deviceId)}',
      authenticated: true,
      body: {'platform': platform, 'pushToken': pushToken},
    );
  }

  Future<void> registerAppDevice({
    required String deviceId,
    required String platform,
    required bool detailsConsent,
    required Map<String, String> details,
    required int generation,
  }) async {
    if (generation != _sessionStore.generation) return;
    await _transport.requestUri(
      'PUT',
      _transport.uri('/v1/app-devices/${Uri.encodeComponent(deviceId)}'),
      authenticated: true,
      expectedGeneration: generation,
      body: {
        'platform': platform,
        'refreshToken': _sessionStore.session?.refreshToken,
        'detailsConsent': detailsConsent,
        if (detailsConsent)
          for (final key in ['model', 'osVersion', 'appVersion', 'appBuild'])
            if (details[key] != null) key: details[key],
      },
    );
  }

  Future<void> unregisterDevice(String deviceId) async {
    await _transport.request(
      'DELETE',
      '/v1/devices/${Uri.encodeComponent(deviceId)}',
      authenticated: true,
    );
  }

  Future<List<Map<String, dynamic>>> guardians() async {
    final response = _asMap(
      await _transport.request('GET', '/v1/guardians', authenticated: true),
    );
    return _dataList(response);
  }

  Future<Map<String, dynamic>> inviteGuardian({
    required String email,
    String? name,
  }) async {
    final response = _asMap(
      await _transport.request(
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
      await _transport.request(
        'PATCH',
        '/v1/guardians/${Uri.encodeComponent(id)}',
        authenticated: true,
        body: {'name': ?name, 'enabled': ?enabled},
      ),
    );
    return _dataMap(response);
  }

  Future<void> deleteGuardian(String id) async {
    await _transport.request(
      'DELETE',
      '/v1/guardians/${Uri.encodeComponent(id)}',
      authenticated: true,
    );
  }

  Future<List<Map<String, dynamic>>> guardianInvitations() async {
    final response = _asMap(
      await _transport.request(
        'GET',
        '/v1/guardian-invitations',
        authenticated: true,
      ),
    );
    return _dataList(response);
  }

  Future<void> respondToGuardianInvitation(
    String id, {
    required bool accept,
  }) async {
    await _transport.request(
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
    await _transport.request(
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

  Future<Map<String, dynamic>> fetchSnapshot() async => _dataMap(
    _asMap(await _transport.request('GET', '/v1/sync', authenticated: true)),
  );

  Future<Map<String, dynamic>> saveSnapshot({
    required int baseRevision,
    required Map<String, dynamic> snapshot,
  }) async => _dataMap(
    _asMap(
      await _transport.request(
        'PUT',
        '/v1/sync',
        authenticated: true,
        body: {'baseRevision': baseRevision, 'snapshot': snapshot},
      ),
    ),
  );

  Future<void> deleteSnapshot(int baseRevision) async {
    final uri = _transport
        .uri('/v1/sync')
        .replace(queryParameters: {'baseRevision': '$baseRevision'});
    await _transport.requestUri('DELETE', uri, authenticated: true);
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
