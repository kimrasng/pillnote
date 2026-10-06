import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/screen/pages/submenu/alarmtime.dart';
import 'package:pillnote/screen/pages/submenu/pushalarm.dart';
import 'package:pillnote/screen/register/register.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  bool _isBusy = false;

  bool get _isLoggedIn => SessionStore.instance.isLoggedIn;

  Future<void> _sync() async {
    setState(() => _isBusy = true);
    try {
      await AppServices.instance.sync.reconcileWithServer();
      if (!mounted) return;
      _showMessage('복약 데이터를 백업했어요.');
      setState(() {});
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } catch (_) {
      if (mounted) _showMessage('서버에 연결할 수 없습니다.', error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isBusy = true);
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
    } catch (_) {
      // 로그아웃은 기기 등록 해제 실패와 무관하게 계속합니다.
    }
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const Register()),
      (_) => false,
    );
  }

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('모든 기기에서 로그아웃'),
        content: const Text('현재 계정으로 로그인한 모든 기기의 갱신 세션을 종료할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isBusy = true);
    try {
      try {
        await PushNotificationService.instance.unregisterCurrentDevice();
      } catch (_) {
        // 기기 등록 해제 실패가 계정 세션 종료를 막지 않도록 합니다.
      }
      await ApiClient.instance.logoutAll();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const Register()),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteCloudBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('클라우드 백업 삭제'),
        content: const Text('서버에 저장된 암호화 백업만 삭제합니다. 이 기기의 복약 데이터는 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('백업 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isBusy = true);
    try {
      await AppServices.instance.sync.deleteCloudBackup();
      if (mounted) _showMessage('클라우드 백업을 삭제했습니다.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isBusy = true);
    String? debugCode;
    try {
      debugCode = await ApiClient.instance.requestAccountDeletionCode();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
      if (mounted) setState(() => _isBusy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isBusy = false);

    final controller = TextEditingController(text: debugCode);
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('계정 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이메일로 받은 계정 삭제 인증번호를 입력하세요. 모든 서버 백업이 삭제됩니다.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '인증번호',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('계정 삭제'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _isBusy = true);
    try {
      try {
        await PushNotificationService.instance.unregisterCurrentDevice();
      } catch (_) {
        // 서버의 계정 삭제가 기기 등록 해제보다 우선입니다.
      }
      await ApiClient.instance.deleteAccount(code);
      await AppServices.instance.clearLocalData();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const Register()),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.instance.session;
    final lastSync = AppServices.instance.sync.lastSyncedAt?.toLocal();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageScrollView(
        title: '설정',
        subtitle: '내 복약 생활을 편하게 맞춰요.',
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftPanel(
                  child: _isLoggedIn
                      ? Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFE5EDFF),
                              child: Icon(Icons.person_outline, color: blue),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '내 계정',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    session?.email ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '내 기기에 저장하고 있어요',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '로그인하면 약과 기록을 백업하고 보호자를 연결할 수 있어요.',
                              style: TextStyle(color: muted, height: 1.6),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _login,
                              child: const Text('이메일로 로그인'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                const SectionLabel('복약 알림'),
                _tile(
                  Icons.schedule_outlined,
                  '놓친 복용 알림',
                  '보호자에게 알리기 전 대기 시간',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const Alarmtime()),
                  ),
                ),
                _tile(
                  Icons.family_restroom_outlined,
                  '보호자 연결',
                  _isLoggedIn ? '연결 상태와 받은 초대 확인' : '로그인 후 보호자를 연결할 수 있어요.',
                  _isLoggedIn
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const Pushalarm(),
                          ),
                        )
                      : _login,
                ),
                const SizedBox(height: 20),
                const SectionLabel('데이터 백업'),
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_outlined, color: blue),
                          const SizedBox(width: 10),
                          Text(
                            _isLoggedIn ? '클라우드 백업' : '기기에 저장됨',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        !_isLoggedIn
                            ? '다른 기기에서도 기록을 보려면 로그인하세요.'
                            : lastSync == null
                            ? '아직 백업을 완료하지 않았어요.'
                            : '최근 백업: ${lastSync.month}월 ${lastSync.day}일 ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                      if (_isLoggedIn) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isBusy ? null : _sync,
                            icon: _isBusy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync, size: 18),
                            label: const Text('지금 백업하기'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isLoggedIn) ...[
                  const SizedBox(height: 24),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text(
                      '계정 관리',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('로그아웃 · 데이터 삭제'),
                    children: [
                      _tile(
                        Icons.logout,
                        '로그아웃',
                        null,
                        _isBusy ? null : _logout,
                      ),
                      _tile(
                        Icons.devices_outlined,
                        '모든 기기에서 로그아웃',
                        null,
                        _isBusy ? null : _logoutAll,
                      ),
                      _tile(
                        Icons.cloud_off_outlined,
                        '클라우드 백업 삭제',
                        '이 기기의 기록은 유지돼요.',
                        _isBusy ? null : _deleteCloudBackup,
                      ),
                      _tile(
                        Icons.delete_forever_outlined,
                        '계정 삭제',
                        '계정과 복약 데이터를 삭제해요.',
                        _isBusy ? null : _deleteAccount,
                        destructive: true,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 36),
                const Center(
                  child: Text(
                    'PillNote 1.0.0',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _login() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const Register()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _tile(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback? onTap, {
    bool destructive = false,
  }) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        leading: Icon(icon, color: destructive ? Colors.red : muted),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: destructive ? Colors.red : ink,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 13),
              ),
        trailing: const Icon(Icons.chevron_right, color: muted, size: 20),
        onTap: onTap,
      ),
      const Divider(),
    ],
  );
}
