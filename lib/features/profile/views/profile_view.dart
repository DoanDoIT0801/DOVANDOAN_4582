import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/views/face_scan_view.dart';

// Tab "Tài khoản" dùng chung cho sinh viên, giảng viên và quản trị viên.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TokenStorage _storage = TokenStorage();
  bool _isFaceEnabled = false;
  String? _faceUsername;
  String? _faceImagePath;

  @override
  void initState() {
    super.initState();
    _loadFaceLoginStatus();
  }

  Future<void> _loadFaceLoginStatus() async {
    final enabled = await _storage.isFaceLoginEnabled;
    final user = await _storage.faceUsername;
    final img = await _storage.faceImagePath;
    if (mounted) {
      setState(() {
        _isFaceEnabled = enabled;
        _faceUsername = user;
        _faceImagePath = img;
      });
    }
  }

  Future<void> _toggleFaceLogin(bool enable) async {
    final auth = context.read<AuthProvider>();
    if (enable) {
      final token = await _storage.token;
      if (token == null) {
        if (mounted) showError(context, 'Phiên đăng nhập không hợp lệ.');
        return;
      }

      if (!mounted) return;
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FaceScanView(
            mode: FaceScanMode.enroll,
            username: _faceUsername ?? auth.fullName ?? 'user',
            token: token,
            role: auth.role ?? '',
            fullName: auth.fullName ?? '',
          ),
        ),
      );

      if (success == true) {
        await _loadFaceLoginStatus();
        if (mounted) {
          showMessage(context, 'Đã kích hoạt Đăng nhập bằng khuôn mặt thành công!');
        }
      }
    } else {
      final ok = await confirmAction(
        context,
        title: 'Tắt đăng nhập khuôn mặt?',
        message: 'Bạn sẽ cần mật khẩu và OTP cho các lần đăng nhập tiếp theo.',
        confirmLabel: 'Tắt tính năng',
        destructive: true,
      );
      if (ok) {
        await _storage.disableFaceLogin();
        await _loadFaceLoginStatus();
        if (mounted) {
          showMessage(context, 'Đã tắt tính năng đăng nhập bằng khuôn mặt.');
        }
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await confirmAction(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần mật khẩu hoặc khuôn mặt để đăng nhập lại.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (ok) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = auth.fullName ?? '';
    final role = auth.role ?? '';
    final roleInfo = _roleInfo(role);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // Profile hero card with gradient
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                  : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(roleInfo.$2, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      roleInfo.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Bảo mật & Đăng nhập ──
        _SectionCard(
          title: 'Bảo mật & Đăng nhập',
          icon: Icons.shield_outlined,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isFaceEnabled
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isFaceEnabled
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (_isFaceEnabled &&
                            _faceImagePath != null &&
                            File(_faceImagePath!).existsSync())
                        ? Image.file(
                            File(_faceImagePath!),
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 24,
                            color: _isFaceEnabled
                                ? const Color(0xFF10B981)
                                : scheme.onPrimaryContainer,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đăng nhập bằng khuôn mặt',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isFaceEnabled
                              ? 'Đã kích hoạt cho $name'
                              : 'Chưa kích hoạt trên máy này',
                          style: text.bodySmall?.copyWith(
                            color: _isFaceEnabled
                                ? const Color(0xFF10B981)
                                : scheme.onSurfaceVariant,
                            fontWeight:
                                _isFaceEnabled ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isFaceEnabled,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) => _toggleFaceLogin(val),
                  ),
                ],
              ),
            ),
            if (_isFaceEnabled) ...[
              const Divider(height: 1),
              InkWell(
                onTap: () => _toggleFaceLogin(true),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Quét lại khuôn mặt',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // App info card
        _SectionCard(
          title: 'Thông tin ứng dụng',
          icon: Icons.info_outline_rounded,
          children: [
            _InfoTile(
              icon: Icons.dns_outlined,
              label: 'Máy chủ API',
              value: Config_URL.baseUrl,
              scheme: scheme,
              text: text,
            ),
            const Divider(height: 1),
            _InfoTile(
              icon: Icons.verified_outlined,
              label: 'Phiên bản',
              value: '1.0.0',
              scheme: scheme,
              text: text,
            ),
            const Divider(height: 1),
            _InfoTile(
              icon: Icons.school_outlined,
              label: 'Hệ thống',
              value: 'Điểm Danh SV - Quản lý điểm danh sinh viên',
              scheme: scheme,
              text: text,
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Logout button
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.7), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),

        const SizedBox(height: 16),
        Text(
          '© 2025 Điểm Danh SV — Hệ thống quản lý điểm danh sinh viên',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.last.characters.first.toUpperCase();
  }

  (String, IconData) _roleInfo(String role) {
    switch (role) {
      case 'Admin':
        return ('Quản trị viên', Icons.admin_panel_settings_rounded);
      case 'GiangVien':
        return ('Giảng viên', Icons.co_present_rounded);
      default:
        return ('Sinh viên', Icons.school_rounded);
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: text.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
