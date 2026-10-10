import 'package:flutter/material.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/widgets/app_ui.dart';

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
      await PushNotificationService.instance.refreshPermissionStatus();
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
          ? '이 기기에서 알림을 받을 수 있어요.'
          : PushNotificationService.instance.lastError ??
                '알림 등록에 실패했습니다. 다시 시도해주세요.',
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
        scrollable: true,
        content: Column(
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
      _message('초대했어요. 보호자가 앱에서 수락하면 연결됩니다.');
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
        scrollable: true,
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
    final notifications = PushNotificationService.instance;
    final connected = _guardians
        .where((g) => g['status'] == 'accepted' && g['enabled'] == true)
        .length;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _isLoading || _error != null
          ? AppBar(title: const Text('보호자 연결'))
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('다시 시도')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: PageScrollView(
                title: '보호자 연결',
                compactHeading: true,
                subtitle: connected > 0
                    ? '함께 챙기는 복약 생활. 복용 기록이 없으면 연결된 보호자에게 알려요.'
                    : '혼자 챙기지 않아도 돼요. 보호자를 초대하고, 수락하면 복약 알림으로 연결돼요.',
                showBackButton: true,
                physics: const AlwaysScrollableScrollPhysics(),
                trailing: IconButton(
                  tooltip: '새로고침',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                children: [
                  const Text(
                    '서버에 동기화된 일정과 복용 기록을 기준으로, 앱이 꺼져 있어도 복용 기록을 확인해요. '
                    '설정한 시간이 지나도록 기록이 확인되지 않으면 연결된 보호자에게 알려요. '
                    '오프라인에서 기록한 복용은 동기화 전까지 반영되지 않을 수 있어요.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  SectionLabel(
                    '내 보호자',
                    trailing: Text(
                      '$connected명 연결',
                      style: const TextStyle(color: blue, fontSize: 13),
                    ),
                  ),
                  if (_guardians.isEmpty)
                    const SoftPanel(
                      child: Text(
                        '아직 연결된 보호자가 없어요.',
                        style: TextStyle(color: muted),
                      ),
                    )
                  else
                    ..._guardians.map((guardian) {
                      final status = '${guardian['status'] ?? 'pending'}';
                      final accepted = status == 'accepted';
                      final enabled = guardian['enabled'] == true;
                      final display = '${guardian['name'] ?? ''}'.isEmpty
                          ? '${guardian['email']}'
                          : '${guardian['name']}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SoftPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                display,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${guardian['email']}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                accepted
                                    ? enabled
                                          ? '연결됨 · 알림 켜짐'
                                          : '연결됨 · 알림 꺼짐'
                                    : status == 'rejected'
                                    ? '초대 거절됨'
                                    : '초대 수락 기다리는 중',
                                style: TextStyle(
                                  color: accepted && enabled ? blue : muted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (accepted)
                                SwitchListTile.adaptive(
                                  activeTrackColor: blue,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    '놓친 복용 알림 보내기',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  value: enabled,
                                  onChanged: (v) =>
                                      _toggleGuardian(guardian, v),
                                ),
                              Wrap(
                                spacing: 12,
                                children: [
                                  TextButton(
                                    onPressed: () => _renameGuardian(guardian),
                                    child: const Text('이름 수정'),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteGuardian(guardian),
                                    child: const Text('연결 삭제'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  if (_guardians.isEmpty) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _inviteGuardian,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('보호자 초대'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const SectionLabel('내게 온 초대'),
                  if (_invitations.isEmpty)
                    const Text('대기 중인 초대가 없어요.', style: TextStyle(color: muted))
                  else
                    ..._invitations.map(
                      (invitation) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SoftPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${invitation['owner']?['email'] ?? '사용자'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '복약 보호자로 초대했어요.',
                                style: TextStyle(color: muted),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _respond('${invitation['id']}', false),
                                    child: const Text('거절'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () =>
                                        _respond('${invitation['id']}', true),
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
                  const Divider(),
                  const SizedBox(height: 24),
                  const SectionLabel('이 기기 알림'),
                  Text(
                    notifications.statusMessage,
                    style: const TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  if (notifications.isConfigured)
                    OutlinedButton.icon(
                      onPressed: _isRegisteringDevice ? null : _registerDevice,
                      icon: _isRegisteringDevice
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_outlined),
                      label: Text(
                        notifications.isRegistered ? '알림 상태 갱신' : '알림 켜기',
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
