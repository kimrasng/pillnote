import 'package:flutter/material.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';

class Pushalarm extends StatefulWidget {
  const Pushalarm({super.key});

  @override
  State<Pushalarm> createState() => _PushalarmState();
}

class _PushalarmState extends State<Pushalarm> {
  List<Map<String, dynamic>> _guardians = [];
  List<Map<String, dynamic>> _invitations = [];
  bool _isLoading = true;
  bool _isRegisteringDevice = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!SessionStore.instance.isLoggedIn) {
      setState(() {
        _isLoading = false;
        _error = '로그인이 필요합니다.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.guardians(),
        ApiClient.instance.guardianInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _guardians = results[0];
        _invitations = results[1];
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '서버에 연결할 수 없습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerDevice() async {
    setState(() => _isRegisteringDevice = true);
    final registered = await PushNotificationService.instance
        .registerCurrentDevice();
    if (!mounted) return;
    setState(() => _isRegisteringDevice = false);
    _message(
      registered
          ? '이 기기의 Push 알림 등록을 완료했습니다.'
          : PushNotificationService.instance.lastError ??
                'Firebase 설정 또는 알림 권한을 확인해주세요.',
      error: !registered,
    );
  }

  Future<void> _inviteGuardian() async {
    var email = '';
    var name = '';
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('보호자 초대'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (value) => email = value,
                decoration: const InputDecoration(
                  labelText: '보호자 이메일',
                  hintText: 'guardian@example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                onChanged: (value) => name = value,
                decoration: const InputDecoration(labelText: '이름 (선택)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, [
              email.trim().toLowerCase(),
              name.trim(),
            ]),
            child: const Text('초대'),
          ),
        ],
      ),
    );
    if (values == null || values.first.isEmpty) return;
    try {
      await ApiClient.instance.inviteGuardian(
        email: values[0],
        name: values[1],
      );
      if (!mounted) return;
      _message('앱 내부 보호자 초대를 생성했습니다.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message, error: true);
    }
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      await ApiClient.instance.respondToGuardianInvitation(id, accept: accept);
      if (!mounted) return;
      _message(accept ? '보호자 초대를 수락했습니다.' : '보호자 초대를 거절했습니다.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message, error: true);
    }
  }

  Future<void> _toggleGuardian(
    Map<String, dynamic> guardian,
    bool enabled,
  ) async {
    try {
      await ApiClient.instance.updateGuardian(
        guardian['id'].toString(),
        enabled: enabled,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message, error: true);
    }
  }

  Future<void> _renameGuardian(Map<String, dynamic> guardian) async {
    var updatedName = guardian['name']?.toString() ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('보호자 이름 수정'),
        content: TextFormField(
          initialValue: updatedName,
          onChanged: (value) => updatedName = value,
          maxLength: 50,
          decoration: const InputDecoration(labelText: '이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, updatedName.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ApiClient.instance.updateGuardian(
        guardian['id'].toString(),
        name: name,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message, error: true);
    }
  }

  Future<void> _deleteGuardian(Map<String, dynamic> guardian) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('보호자 연결 삭제'),
        content: Text(
          '${guardian['name'] ?? guardian['email']} 보호자 연결을 삭제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.deleteGuardian(guardian['id'].toString());
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message, error: true);
    }
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('보호자 및 Push 알림'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('다시 시도')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.phone_android),
                              SizedBox(width: 10),
                              Text(
                                '이 기기 Push 알림',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            PushNotificationService.instance.isConfigured
                                ? '알림 권한을 허용하고 FCM 토큰을 서버에 등록합니다.'
                                : 'Firebase 빌드 설정이 필요합니다.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isRegisteringDevice
                                ? null
                                : _registerDevice,
                            icon: _isRegisteringDevice
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.notifications_active_outlined,
                                  ),
                            label: const Text('이 기기 등록·갱신'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _heading('내게 온 초대'),
                  if (_invitations.isEmpty)
                    const _EmptyCard(text: '대기 중인 보호자 초대가 없습니다.')
                  else
                    ..._invitations.map(
                      (invitation) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invitation['owner']?['email']?.toString() ??
                                    '사용자',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('복약 보호자로 초대했습니다.'),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _respond(
                                      invitation['id'].toString(),
                                      false,
                                    ),
                                    child: const Text('거절'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => _respond(
                                      invitation['id'].toString(),
                                      true,
                                    ),
                                    child: const Text('수락'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _heading('내 보호자'),
                      TextButton.icon(
                        onPressed: _guardians.isEmpty ? _inviteGuardian : null,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('초대'),
                      ),
                    ],
                  ),
                  if (_guardians.isEmpty)
                    const _EmptyCard(
                      text: '보호자를 초대하면 미복용 시 앱 Push 알림을 보낼 수 있습니다.',
                    )
                  else
                    ..._guardians.map((guardian) {
                      final status =
                          guardian['status']?.toString() ?? 'pending';
                      final accepted = status == 'accepted';
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            10,
                            8,
                            10,
                          ),
                          title: Text(
                            guardian['name']?.toString() ??
                                guardian['email'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${guardian['email']} · ${_statusLabel(status)}',
                          ),
                          onTap: () => _renameGuardian(guardian),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: accepted && guardian['enabled'] == true,
                                onChanged: accepted
                                    ? (value) =>
                                          _toggleGuardian(guardian, value)
                                    : null,
                              ),
                              IconButton(
                                onPressed: () => _deleteGuardian(guardian),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
    ),
  );

  String _statusLabel(String status) => switch (status) {
    'accepted' => '수락됨',
    'rejected' => '거절됨',
    _ => '수락 대기',
  };
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    ),
  );
}
