import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/pages/submenu/alarmtime.dart';
import 'package:pillnote/screen/pages/submenu/pushalarm.dart';
import 'package:pillnote/screen/register/register.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';

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
      final revision = await Controller.reconcileWithServer();
      if (!mounted) return;
      _showMessage('클라우드 백업 동기화가 완료되었습니다. (revision $revision)');
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
      await Controller.deleteCloudBackup();
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
      await Controller.clearLocalData();
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('메뉴')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _isLoggedIn
                    ? Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            child: Icon(Icons.person_outline),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '로그인됨',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  session?.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
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
                            '로그인하면 기기 간 백업과 보호자 알림을 사용할 수 있습니다.',
                            style: TextStyle(height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const Register(),
                              ),
                            ).then((_) => setState(() {})),
                            child: const Text('이메일로 로그인'),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('복약 및 알림'),
            _menuTile(
              icon: Icons.schedule_outlined,
              title: '미복용 판정 시간',
              subtitle: '예정 시각 이후 보호자 알림 기준을 설정합니다.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const Alarmtime()),
              ),
            ),
            _menuTile(
              icon: Icons.family_restroom_outlined,
              title: '보호자 및 Push 알림',
              subtitle: _isLoggedIn
                  ? '보호자 초대, 받은 초대와 기기 알림을 관리합니다.'
                  : '로그인 후 사용할 수 있습니다.',
              onTap: _isLoggedIn
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const Pushalarm(),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            _sectionTitle('계정 및 데이터'),
            _menuTile(
              icon: Icons.cloud_sync_outlined,
              title: '클라우드 백업 동기화',
              subtitle: '로컬 복약 데이터를 암호화된 서버 백업과 병합합니다.',
              onTap: _isLoggedIn && !_isBusy ? _sync : null,
              trailing: _isBusy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (_isLoggedIn) ...[
              _menuTile(
                icon: Icons.cloud_off_outlined,
                title: '클라우드 백업 삭제',
                subtitle: '이 기기의 데이터는 유지하고 서버 백업만 삭제합니다.',
                onTap: _isBusy ? null : _deleteCloudBackup,
              ),
              _menuTile(
                icon: Icons.logout,
                title: '로그아웃',
                onTap: _isBusy ? null : _logout,
              ),
              _menuTile(
                icon: Icons.devices_outlined,
                title: '모든 기기에서 로그아웃',
                onTap: _isBusy ? null : _logoutAll,
              ),
              _menuTile(
                icon: Icons.delete_forever_outlined,
                title: '계정 삭제',
                titleColor: Colors.red,
                onTap: _isBusy ? null : _deleteAccount,
              ),
            ],
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'PillNote 1.0.0',
                style: TextStyle(color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black54,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? titleColor,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Icon(icon, color: titleColor ?? const Color(0xFF2563EB)),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
