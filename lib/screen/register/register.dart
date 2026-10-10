import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/screen/main.dart';
import 'package:pillnote/screen/register/verification.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/widgets/custom_text_field.dart';
import 'package:pillnote/widgets/auth_layout.dart';
import 'package:pillnote/widgets/auth_step_route.dart';

class Register extends StatefulWidget {
  const Register({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  late final _contentVisibility = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 140),
  );
  bool _isLoading = false;
  bool _isLeaving = false;

  Future<void> _handleRegister() async {
    if (_isLeaving) return;
    final email = emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 이메일을 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final debugCode = await (widget.apiClient ?? ApiClient.instance)
          .startEmailLogin(email);
      if (!mounted || _isLeaving) return;
      final animate = !MediaQuery.disableAnimationsOf(context);
      if (animate) {
        await _contentVisibility.reverse().orCancel;
        if (!mounted || _isLeaving) return;
      }
      await Navigator.push(
        context,
        AuthStepRoute(
          animate: animate,
          builder: (context) => Verification(
            email: email,
            debugCode: debugCode,
            resendCooldownSeconds: (widget.apiClient ?? ApiClient.instance)
                .emailResendCooldownSeconds,
            apiClient: widget.apiClient,
            onReturn: _revealEmail,
          ),
        ),
      );
    } on TickerCanceled {
      return;
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
        ).showSnackBar(const SnackBar(content: Text('서버에 연결할 수 없습니다.')));
      }
    } finally {
      _revealEmail();
    }
  }

  void _revealEmail() {
    if (!mounted || _isLeaving) return;
    setState(() => _isLoading = false);
    if (MediaQuery.disableAnimationsOf(context)) {
      _contentVisibility.value = 1;
    } else if (_contentVisibility.value < 1 &&
        !_contentVisibility.isAnimating) {
      _contentVisibility.animateTo(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _returnToPrevious() async {
    if (_isLeaving || !Navigator.canPop(context)) return;
    setState(() => _isLeaving = true);
    FocusScope.of(context).unfocus();
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _contentVisibility
            .animateBack(
              0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInCubic,
            )
            .orCancel;
      }
      if (mounted) Navigator.pop(context);
    } on TickerCanceled {
      // The route may be dismissed by the system while its contents fade.
    }
  }

  Future<void> _startWithoutLogin() async {
    await AppServices.instance.setOnboardingCompleted(true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (context) => const Main()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    _contentVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: '뒤로',
        onPressed: _isLeaving || !Navigator.canPop(context)
            ? null
            : _returnToPrevious,
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
    ),
    title: '로그인',
    description: '이메일로 로그인하고\n복약 기록을 이어서 관리하세요.',
    contentAnimation: _contentVisibility,
    fields: [
      AutofillGroup(
        child: CustomTextField(
          label: '이메일 주소',
          hint: 'example@email.com',
          keyboardType: TextInputType.emailAddress,
          controller: emailController,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isLoading) _handleRegister();
          },
        ),
      ),
    ],
    actions: [
      FilledButton(
        onPressed: _isLoading || _isLeaving ? null : _handleRegister,
        child: _isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('인증번호 받기'),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _isLeaving || _isLoading ? null : _startWithoutLogin,
        child: const Text('로그인 없이 시작하기'),
      ),
    ],
  );
}
