import 'package:flutter/material.dart';
import 'package:pillnote/services/app_device_service.dart';

class DevicePrivacy extends StatefulWidget {
  const DevicePrivacy({super.key});
  @override
  State<DevicePrivacy> createState() => _DevicePrivacyState();
}

class _DevicePrivacyState extends State<DevicePrivacy> {
  bool _enabled = false;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    AppDeviceService.instance.detailsConsent().then((value) {
      if (mounted) {
        setState(() {
          _enabled = value;
          _busy = false;
        });
      }
    });
  }

  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    final saved = await AppDeviceService.instance.setDetailsConsent(value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? (value ? '기기 정보 제공을 켰어요.' : '서버의 상세 기기 정보를 지웠어요.')
              : '선택을 기기에 저장했어요. 서버 반영은 다음 온라인 접속 때 다시 시도합니다.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('기기 정보 제공')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '로그인 기기 관리',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          '로그인한 앱의 운영체제 종류(Android/iOS), 앱 설치별 임의 ID, 로그인 세션과 최근 서버 접속 시각을 계정과 연결해 관리합니다. 알림 권한과는 별개입니다.',
        ),
        const SizedBox(height: 24),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('상세 기기 정보 제공 (선택)'),
          value: _enabled,
          onChanged: _busy ? null : _change,
        ),
        const Text(
          '앱 호환성 문제 확인을 위해 기종 코드, OS 버전, 앱 버전·빌드 번호를 PillNote 운영자에게 제공합니다. 제공하지 않아도 로그인·복약 기록·알림을 이용할 수 있습니다. 기기 이름, 전화번호, 일련번호, 광고 식별자, 위치는 이 기능에서 수집하지 않습니다.',
        ),
        const SizedBox(height: 16),
        const Text(
          '상세 정보는 선택을 끄면 서버에서 삭제합니다. 기기 등록 정보는 계정 삭제 시 삭제하며, 유효한 로그인 세션이 없고 최근 접속 후 30일이 지난 기록도 정리합니다. 온라인 연결이 없으면 선택 변경은 다음 접속 시 반영됩니다.',
        ),
      ],
    ),
  );
}
