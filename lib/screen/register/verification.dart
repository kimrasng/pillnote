import 'package:flutter/material.dart';
import '../../controller/controller.dart';
import '../../services/api_client.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/custom_text_field.dart';
import '../main.dart';

class Verification extends StatefulWidget {
  const Verification({super.key, required this.email, this.debugCode});

  final String email;
  final String? debugCode;

  @override
  State<Verification> createState() => _VerificationState();
}

class _VerificationState extends State<Verification> {
  final codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  Future<void> _handleVerify() async {
    final code = codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('6자리 인증번호를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.verifyEmail(widget.email, code);
      await Controller.setOnboardingCompleted(true);
      await Controller.reconcileWithServer();
      await PushNotificationService.instance.registerCurrentDevice();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (context) => const Main()),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 처리 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      final debugCode = await ApiClient.instance.startEmailLogin(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            debugCode == null ? '인증번호를 다시 발송했습니다.' : '개발용 인증번호: $debugCode',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.04),
              Text(
                "인증번호 입력",
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: screenWidth * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.email}로 발송된 6자리 번호를 입력하세요',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: screenHeight * 0.06),
              CustomTextField(
                label: '인증번호',
                hint: '000000',
                keyboardType: TextInputType.number,
                controller: codeController,
              ),
              if (widget.debugCode != null) ...[
                const SizedBox(height: 12),
                Text(
                  '개발 환경 인증번호: ${widget.debugCode}',
                  style: const TextStyle(color: Color(0xFF2563EB)),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: Text(_isResending ? '발송 중…' : '인증번호 다시 받기'),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.07,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  child: _isLoading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          '인증 완료',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: screenHeight * 0.08),
            ],
          ),
        ),
      ),
    );
  }
}
