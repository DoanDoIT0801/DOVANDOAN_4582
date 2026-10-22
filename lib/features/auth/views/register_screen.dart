import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import 'face_scan_view.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = 'SinhVien';
  bool _busy = false;
  bool _showPassword = false;
  bool _hasFaceEnrolled = false;

  @override
  void dispose() {
    for (final c in [_username, _email, _fullName, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openFaceRegistration() async {
    final fullName = _fullName.text.trim();
    final username = _username.text.trim();

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceScanView(
          mode: FaceScanMode.enroll,
          fullName: fullName.isNotEmpty ? fullName : 'Người dùng mới',
          username: username.isNotEmpty ? username : 'user',
          role: _role,
        ),
      ),
    );

    if (result == true) {
      setState(() => _hasFaceEnrolled = true);
      if (mounted) {
        showMessage(context, 'Đã ghi nhận dữ liệu khuôn mặt thành công!');
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final username = _username.text.trim();
    try {
      await context.read<ApiService>().register(
            username: username,
            email: _email.text.trim(),
            password: _password.text,
            fullName: _fullName.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            username: username,
            isRegister: true,
            fullName: _fullName.text.trim(),
            role: _role,
            faceEnrolled: _hasFaceEnrolled,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v, String field) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập $field' : null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Bạn là', style: text.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'SinhVien', label: Text('Sinh viên'), icon: Icon(Icons.school_outlined)),
                        ButtonSegment(value: 'GiangVien', label: Text('Giảng viên'), icon: Icon(Icons.co_present_outlined)),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 24),
                    Text('Thông tin cá nhân', style: text.titleSmall),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
                      validator: (v) => _required(v, 'họ và tên'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        helperText: 'Mã OTP xác nhận sẽ được gửi tới email này',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Email chưa đúng định dạng, ví dụ: ten@gmail.com';
                      },
                    ),
                    const SizedBox(height: 24),
                    Text('Thông tin đăng nhập', style: text.titleSmall),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newUsername],
                      decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (v) => _required(v, 'tên đăng nhập'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
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
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu', prefixIcon: Icon(Icons.lock_reset_rounded)),
                      validator: (v) => v != _password.text ? 'Mật khẩu nhập lại không khớp' : null,
                    ),

                    // ── Phần đăng ký khuôn mặt ──
                    const SizedBox(height: 24),
                    Text('Đăng ký khuôn mặt (Face ID)', style: text.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _hasFaceEnrolled
                            ? AppTheme.successColor.withValues(alpha: 0.12)
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _hasFaceEnrolled
                              ? AppTheme.successColor
                              : scheme.outlineVariant,
                          width: _hasFaceEnrolled ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _hasFaceEnrolled
                                      ? AppTheme.successColor.withValues(alpha: 0.2)
                                      : scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _hasFaceEnrolled
                                      ? Icons.check_circle_rounded
                                      : Icons.face_retouching_natural_rounded,
                                  color: _hasFaceEnrolled
                                      ? AppTheme.successColor
                                      : scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _hasFaceEnrolled
                                          ? 'Đã quét khuôn mặt thành công'
                                          : 'Liên kết khuôn mặt với tài khoản',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _hasFaceEnrolled
                                          ? 'Sẵn sàng kích hoạt sau khi xác nhận mã OTP'
                                          : 'Đăng nhập nhanh qua camera không cần gõ mật khẩu',
                                      style: text.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _hasFaceEnrolled
                                    ? AppTheme.successColor
                                    : scheme.primary,
                                side: BorderSide(
                                  color: _hasFaceEnrolled
                                      ? AppTheme.successColor
                                      : scheme.primary,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _openFaceRegistration,
                              icon: Icon(_hasFaceEnrolled
                                  ? Icons.refresh_rounded
                                  : Icons.camera_front_rounded),
                              label: Text(_hasFaceEnrolled
                                  ? 'Quét lại khuôn mặt'
                                  : 'Quét khuôn mặt ngay'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Đăng ký và nhận mã OTP'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tài khoản chỉ được kích hoạt sau khi bạn nhập đúng mã OTP.',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
