import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/ui_helpers.dart';
import 'face_scan_view.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final username = _username.text.trim();
    try {
      await context.read<ApiService>().login(username, _password.text);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(username: username, isRegister: false),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      // Không dùng AppBar - layout tự quản lý
      body: Row(
        children: [
          // ── Cột trái: minh hoạ (chỉ hiện trên tablet/landscape) ──
          if (size.width >= 700)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [scheme.primary, scheme.secondary],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.how_to_reg_rounded, size: 72, color: Colors.white),
                        const SizedBox(height: 24),
                        Text(
                          'Điểm Danh SV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Hệ thống quản lý\nđiểm danh sinh viên\nhiện đại và chuyên nghiệp.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Cột phải / toàn màn hình trên mobile: form đăng nhập ──
          Expanded(
            child: SafeArea(
              child: FadeTransition(
                opacity: _animCtrl,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        // Logo nhỏ ở trên (chỉ hiện trên mobile)
                        if (size.width < 700)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 28),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.how_to_reg_rounded,
                                    color: scheme.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Điểm Danh SV',
                                        style: text.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: scheme.primary,
                                        )),
                                    Text('Quản lý điểm danh sinh viên',
                                        style: text.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // Tiêu đề form
                        Text('Chào mừng\ntrở lại! 👋',
                            style: text.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              letterSpacing: -1,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          'Đăng nhập để quản lý lớp học và điểm danh.',
                          style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 36),

                        // ── Form ──
                        AutofillGroup(
                          child: Form(
                            key: _form,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Label bên ngoài field
                                Text('Tên đăng nhập',
                                    style: text.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _username,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(
                                    hintText: 'Nhập tên đăng nhập...',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Vui lòng nhập tên đăng nhập'
                                          : null,
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Mật khẩu',
                                        style: text.labelLarge?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ForgotPasswordScreen(
                                            initialAccount: _username.text.trim(),
                                          ),
                                        ),
                                      ),
                                      child: Text('Quên mật khẩu?',
                                          style: text.labelMedium?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _password,
                                  obscureText: !_showPassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      icon: Icon(_showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined),
                                      onPressed: () => setState(
                                          () => _showPassword = !_showPassword),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? 'Vui lòng nhập mật khẩu'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                // OTP notice
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 15,
                                        color: scheme.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Sau đây, mã OTP xác thực sẽ được gửi đến email của bạn.',
                                        style: text.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                // Nút đăng nhập
                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    child: _busy
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('Đăng nhập',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  )),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded,
                                                  size: 18),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    side: BorderSide(
                                      color: scheme.primary.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FaceScanView(
                                        mode: FaceScanMode.login,
                                      ),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.face_retouching_natural_rounded,
                                    color: scheme.primary,
                                  ),
                                  label: Text(
                                    'Đăng nhập bằng khuôn mặt',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        // Divider
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: scheme.outlineVariant)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('hoặc',
                                  style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                            ),
                            Expanded(
                                child: Divider(
                                    color: scheme.outlineVariant)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Nút đăng ký
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            ),
                            child: const Text('Tạo tài khoản mới',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
