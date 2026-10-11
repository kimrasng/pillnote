import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import '../../services/api_client.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/auth_step_route.dart';
import '../../widgets/home_entry_route.dart';
import '../../widgets/verification_code_field.dart';
import '../main.dart';

class Verification extends StatefulWidget {
  const Verification({
    super.key,
    required this.email,
    this.debugCode,
    this.apiClient,
    this.onReturn,
    this.resendCooldownSeconds = 60,
  }) : onDeleteAccount = null;

  const Verification.accountDeletion({
    super.key,
    required this.email,
    required Future<void> Function(String code) this.onDeleteAccount,
    this.debugCode,
    this.apiClient,
    this.resendCooldownSeconds = 60,
  }) : onReturn = null;

  final String email;
  final String? debugCode;
  final ApiClient? apiClient;
  final VoidCallback? onReturn;
  final int resendCooldownSeconds;
  final Future<void> Function(String code)? onDeleteAccount;

  @override
  State<Verification> createState() => _VerificationState();
}

class _VerificationState extends State<Verification>
    with SingleTickerProviderStateMixin {
  final codeController = TextEditingController();
  late final _returnVisibility = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 180),
  );
  bool _isReturning = false;
  bool _isLoading = false;
  bool _isResending = false;
  int _cooldown = 60;
  Timer? _resendTimer;
  int _arrivalSequence = 0;
  String? _debugCode;

  ApiClient get _api => widget.apiClient ?? ApiClient.instance;
  bool get _isDeletingAccount => widget.onDeleteAccount != null;

  @override
  void initState() {
    super.initState();
    _debugCode = widget.debugCode;
    _startCooldown(widget.resendCooldownSeconds);
  }

  void _startCooldown(int seconds) {
    _resendTimer?.cancel();
    _cooldown = seconds;
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _handleVerify() async {
    if (_isReturning || _isLoading || _isResending) return;
    final code = codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('6자리 인증번호를 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final deleteAccount = widget.onDeleteAccount;
      if (deleteAccount != null) {
        await deleteAccount(code);
        return;
      }
      await _api.verifyEmail(widget.email, code);
      await AppServices.instance.setOnboardingCompleted(true);
      try {
        await AppServices.instance.sync.reconcileWithServer();
      } catch (_) {
        // A successful login remains usable when backup is temporarily unavailable.
      }
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.pushAndRemoveUntil(
        context,
        HomeEntryRoute(
          animate: !MediaQuery.disableAnimationsOf(context),
          builder: (context) => const Main(),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isDeletingAccount
                  ? '계정 삭제 중 오류가 발생했습니다. 다시 시도해주세요.'
                  : '로그인 처리 중 오류가 발생했습니다.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_isReturning || _isLoading || _isResending || _cooldown > 0) return;
    setState(() => _isResending = true);
    try {
      final debugCode = await (_isDeletingAccount
          ? _api.requestAccountDeletionCode()
          : _api.startEmailLogin(widget.email));
      if (!mounted) return;
      _startCooldown(_api.emailResendCooldownSeconds);
      codeController.clear();
      setState(() {
        _arrivalSequence++;
        _debugCode = debugCode;
      });
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증번호를 보내지 못했어요. 다시 시도하세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _returnToPrevious() async {
    if (_isReturning || _isLoading || !Navigator.canPop(context)) return;
    setState(() => _isReturning = true);
    FocusScope.of(context).unfocus();
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _returnVisibility.reverse().orCancel;
      }
      if (mounted) Navigator.pop(context);
    } on TickerCanceled {
      // The user can also dismiss this step through the system back action.
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    codeController.dispose();
    _returnVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isDeletingAccount || !_isLoading,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) widget.onReturn?.call();
    },
    child: HomeDepthTransition(
      animation:
          ModalRoute.of(context)?.secondaryAnimation ??
          kAlwaysDismissedAnimation,
      outgoing: true,
      child: AuthLayout(
        contentAnimation: _isReturning ? _returnVisibility : null,
        title: _isDeletingAccount ? '계정 삭제 인증' : '인증번호 입력',
        description: '${widget.email}로 인증번호를 보냈어요.\n6자리 번호를 입력해주세요.',
        fields: [
          AutofillGroup(
            child: VerificationCodeField(
              controller: codeController,
              enabled: !_isLoading && !_isReturning && !_isResending,
              arrivalSequence: _arrivalSequence,
              arrivalDelay:
                  _arrivalSequence == 0 &&
                      ModalRoute.of(context) is AuthStepRoute
                  ? const Duration(milliseconds: 360)
                  : const Duration(milliseconds: 180),
              onCompleted: _isDeletingAccount ? null : (_) => _handleVerify(),
              onSubmitted: _isDeletingAccount ? null : (_) => _handleVerify(),
            ),
          ),
          if (_debugCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '개발 환경 인증번호: $_debugCode',
                style: const TextStyle(color: Color(0xFF2563EB)),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  _isResending || _cooldown > 0 || _isLoading || _isReturning
                  ? null
                  : _resend,
              child: Text(
                _isResending
                    ? '발송 중…'
                    : _cooldown > 0
                    ? '$_cooldown초 후 다시 받기'
                    : '인증번호 다시 받기',
              ),
            ),
          ),
          if (_isDeletingAccount)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '계정을 삭제하면 모든 서버 백업과 이 기기의 복약 데이터가 삭제돼요.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
        actions: [
          FilledButton(
            style: _isDeletingAccount
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: _isLoading || _isResending || _isReturning
                ? null
                : _handleVerify,
            child: _isLoading
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isDeletingAccount ? '계정 삭제' : '인증 완료'),
          ),
          if (Navigator.canPop(context)) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading || _isReturning ? null : _returnToPrevious,
              child: Text(_isDeletingAccount ? '취소' : '이메일 다시 입력'),
            ),
          ],
        ],
      ),
    ),
  );
}
