import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../providers/auth_provider.dart';

// Dùng cho cả xác nhận đăng ký (isRegister = true) và OTP đăng nhập (isRegister = false).
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.username,
    required this.isRegister,
    this.fullName,
    this.role,
    this.faceEnrolled = false,
  });

  final String username;
  final bool isRegister;
  final String? fullName;
  final String? role;
  final bool faceEnrolled;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.trim().length != 6) {
      showMessage(context, 'Mã OTP gồm 6 chữ số.');
      return;
    }
    final api = context.read<ApiService>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      if (widget.isRegister) {
        final res = await api.verifyRegister(widget.username, _code.text.trim());
        if (widget.faceEnrolled) {
          final storage = TokenStorage();
          await storage.saveFaceAccount(
            username: widget.username,
            token: '',
            role: widget.role ?? 'SinhVien',
            fullName: widget.fullName ?? widget.username,
          );
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Tài khoản đã tạo và liên kết khuôn mặt thành công!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(res['message'].toString())),
          );
        }
        navigator.popUntil((r) => r.isFirst);
      } else {
        final data = await api.verifyLogin(widget.username, _code.text.trim());
        await auth.saveSession(data);
        final storage = TokenStorage();
        if (await storage.isFaceLoginEnabled &&
            (await storage.faceUsername) == widget.username) {
          await storage.saveFaceAccount(
            username: widget.username,
            token: data['token'] as String,
            role: data['role'].toString(),
            fullName: data['fullName'].toString(),
          );
        }
        navigator.popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRegister ? 'Xác nhận email' : 'Xác thực đăng nhập'),
        backgroundColor: scheme.surface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Biểu tượng email lớn
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 50,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Kiểm tra email của bạn',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant),
                        children: [
                          const TextSpan(text: 'Mã 6 chữ số đã được gửi đến email của tài khoản '),
                          TextSpan(
                            text: '"${widget.username}"',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '.\nMã có hiệu lực trong '),
                          TextSpan(
                            text: '5 phút',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Label ngoài field
              Text('Nhập mã OTP',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              // Ô nhập OTP lớn, căn giữa chữ số
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 16,
                  color: scheme.primary,
                ),
                decoration: InputDecoration(
                  hintText: '––––––',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 12,
                    color: scheme.outlineVariant,
                    fontWeight: FontWeight.w300,
                  ),
                  counterText: '',
                ),
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
                onSubmitted: (_) => _verify(),
              ),
              const Spacer(),
              // Thông báo phụ
              Center(
                child: Text(
                  'Không thấy email? Kiểm tra thư mục Spam.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              // Nút xác nhận full-width
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Xác nhận mã OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          )),
                ),
              ),
              const SizedBox(height: 12),
              // Quay lại
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Gửi lại mã / Quay lại'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
