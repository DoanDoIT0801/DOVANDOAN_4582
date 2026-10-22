import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';

// Quên mật khẩu, 2 bước trên cùng một màn hình:
// 1. Nhập tên đăng nhập hoặc email để nhận OTP.
// 2. Nhập OTP và mật khẩu mới.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialAccount = ''});

  final String initialAccount;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  final _accountForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _account = TextEditingController(text: widget.initialAccount);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _showPassword = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_account, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  Future<void> _sendCode() async {
    if (_busy || !_accountForm.currentState!.validate()) return;
    final api = context.read<ApiService>();
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final res = await api.forgotPassword(_account.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCooldown();
      showMessage(context, res['message'].toString());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy || !_resetForm.currentState!.validate()) return;
    final api = context.read<ApiService>();
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final res = await api.resetPassword(
        account: _account.text.trim(),
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      await showResultDialog(context, success: true, title: 'Đã đổi mật khẩu', message: res['message'].toString());
      navigator.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _busyLabel(String label) => _busy
      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
      : Text(label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chỉ báo tiến trình 2 bước.
              Semantics(
                label: 'Bước ${_codeSent ? 2 : 1} trên 2',
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: (i == 0 || _codeSent) ? scheme.primary : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Bước ${_codeSent ? 2 : 1}/2', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(_codeSent ? Icons.lock_reset_rounded : Icons.key_rounded, size: 36, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _codeSent ? 'Đặt mật khẩu mới' : 'Lấy lại mật khẩu',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Nhập mã OTP vừa gửi tới email đăng ký của tài khoản và mật khẩu mới.'
                    : 'Nhập tên đăng nhập hoặc email. Chúng tôi sẽ gửi mã OTP để bạn đặt lại mật khẩu.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Form(
                key: _accountForm,
                child: TextFormField(
                  controller: _account,
                  enabled: !_codeSent,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  onFieldSubmitted: (_) => _sendCode(),
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập hoặc email',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên đăng nhập hoặc email' : null,
                ),
              ),
              if (!_codeSent) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: _busy ? null : _sendCode, child: _busyLabel('Gửi mã OTP')),
              ] else
                Form(
                  key: _resetForm,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _codeSent = false;
                            _code.clear();
                          }),
                          child: const Text('Đổi tài khoản'),
                        ),
                      ),
                      TextFormField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        decoration: const InputDecoration(labelText: 'Mã OTP (6 số)', prefixIcon: Icon(Icons.pin_outlined)),
                        validator: (v) => (v == null || v.length != 6) ? 'Mã OTP gồm 6 chữ số' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          helperText: 'Tối thiểu 6 ký tự',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu cần tối thiểu 6 ký tự' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirm,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _reset(),
                        decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới', prefixIcon: Icon(Icons.lock_reset_rounded)),
                        validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(onPressed: _busy ? null : _reset, child: _busyLabel('Đặt lại mật khẩu')),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: (_busy || _cooldown > 0) ? null : _sendCode,
                        child: Text(_cooldown > 0 ? 'Gửi lại mã sau $_cooldown giây' : 'Gửi lại mã OTP'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
