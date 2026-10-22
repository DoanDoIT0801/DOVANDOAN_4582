import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/attendance_code_helper.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';

/// Hiển thị mã QR và mã 4 số ngẫu nhiên để sinh viên điểm danh.
/// Đếm ngược thời gian, tự động đóng điểm danh khi hết giờ (ai không điểm danh sẽ thành Vắng).
class SessionQrScreen extends StatefulWidget {
  const SessionQrScreen({
    super.key,
    required this.session,
    this.pinCode,
  });

  final Map<String, dynamic> session;
  final String? pinCode;

  @override
  State<SessionQrScreen> createState() => _SessionQrScreenState();
}

class _SessionQrScreenState extends State<SessionQrScreen> {
  Timer? _timer;
  Timer? _countTimer;
  int? _count;
  Duration? _timeLeft;
  bool _closing = false;

  int get _sessionId => widget.session['id'] as int;

  late final String _pin = widget.pinCode ??
      AttendanceCodeHelper.extractPin(widget.session['title']) ??
      AttendanceCodeHelper.fallbackPinFromToken(widget.session['qrToken']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _refreshCount();

    // Mỗi 1 giây: cập nhật đồng hồ đếm ngược, tự động đóng khi hết giờ
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });

    // Mỗi 4 giây: cập nhật số sinh viên đã điểm danh
    _countTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _refreshCount();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countTimer?.cancel();
    super.dispose();
  }

  void _updateTimeLeft() {
    final endsAtStr = widget.session['endsAt']?.toString();
    if (endsAtStr == null) return;
    final endsAt = DateTime.tryParse(endsAtStr)?.toLocal();
    if (endsAt == null) return;

    final diff = endsAt.difference(DateTime.now());
    if (diff <= Duration.zero) {
      _timer?.cancel();
      if (!_closing && mounted) {
        _autoClose();
      }
    } else {
      if (mounted) {
        setState(() => _timeLeft = diff);
      }
    }
  }

  Future<void> _autoClose() async {
    _closing = true;
    try {
      await context.read<ApiService>().closeSession(_sessionId);
    } catch (_) {}
    if (!mounted) return;
    showMessage(context, 'Hết thời gian điểm danh. Những sinh viên chưa điểm danh đã được tính là vắng.');
    Navigator.pop(context, true);
  }

  Future<void> _refreshCount() async {
    try {
      final list = await context.read<ApiService>().attendances(_sessionId);
      if (mounted) setState(() => _count = list.length);
    } catch (_) {
      // Giữ số cũ khi lỗi mạng
    }
  }

  Future<void> _close() async {
    final api = context.read<ApiService>();
    final navigator = Navigator.of(context);
    final ok = await confirmAction(
      context,
      title: 'Đóng điểm danh?',
      message: 'Sinh viên sẽ không thể quét mã hoặc nhập mã số nữa. Những ai chưa điểm danh sẽ được tính là vắng.',
      confirmLabel: 'Đóng điểm danh',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.closeSession(_sessionId);
      navigator.pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cleanTitle = AttendanceCodeHelper.cleanTitle(widget.session['title']);
    final qr = widget.session['qrToken']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(cleanTitle),
        actions: [
          if (_timeLeft != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: scheme.onErrorContainer),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_timeLeft!),
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // ── Khối 1: Mã QR ──
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Semantics(
                  label: 'Mã QR điểm danh',
                  child: QrImageView(data: qr, size: 210, backgroundColor: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cách 1: Sinh viên dùng camera quét mã QR',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // ── Khối 2: Mã 4 số ngẫu nhiên ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pin_outlined, size: 18, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Cách 2: Hoặc nhập mã số 4 chữ số',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _pin.split('').map((digit) {
                      return Container(
                        width: 52,
                        height: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          digit,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sinh viên nhập đúng 4 số này trên app để điểm danh',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Khối 3: Thống kê số lượng đã điểm danh ──
            Card(
              color: scheme.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.how_to_reg_rounded, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _count == null ? '...' : '$_count sinh viên',
                            style: text.headlineSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Đã điểm danh có mặt • Tự cập nhật',
                            style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Khi hết giờ, mã QR sẽ tự động đóng. Ai không điểm danh sẽ được tính là vắng.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Text('Đóng điểm danh ngay', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: _close,
          ),
        ),
      ),
    );
  }
}
