import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/attendance_code_helper.dart';
import '../../../core/utils/location_util.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../attendance/views/scan_qr_screen.dart';
import '../../leave_requests/views/leave_request_screen.dart';

/// Màn hình chi tiết buổi học dành cho sinh viên
/// Cho phép sinh viên xem trạng thái buổi học, đồng hồ đếm ngược và điểm danh bằng QR hoặc Mã 4 số.
class StudentSessionDetailScreen extends StatefulWidget {
  const StudentSessionDetailScreen({
    super.key,
    required this.session,
    required this.classId,
    required this.className,
  });

  final Json session;
  final int classId;
  final String className;

  @override
  State<StudentSessionDetailScreen> createState() => _StudentSessionDetailScreenState();
}

class _StudentSessionDetailScreenState extends State<StudentSessionDetailScreen> {
  late Json _session;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  Duration _timeLeft = Duration.zero;
  bool _isLoading = false;

  int get _id => _session['id'] as int;

  bool get _isOpen {
    if (_session['checkedIn'] == true) return false;
    final endsAt = _session['endsAt'];
    if (endsAt == null) return _session['isOpen'] == true;
    final end = DateTime.tryParse(endsAt.toString())?.toLocal();
    if (end == null) return _session['isOpen'] == true;
    return DateTime.now().isBefore(end);
  }

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
    _calculateTimeLeft();
    _startCountdown();

    // Tải dữ liệu mới nhất ngay khi vào buổi học
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSession();
    });

    // Polling tự động làm mới mỗi 5 giây nếu đang mở
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _isOpen) {
        _refreshSession(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _calculateTimeLeft() {
    final endsAt = _session['endsAt'];
    if (endsAt == null) {
      _timeLeft = Duration.zero;
      return;
    }
    final end = DateTime.tryParse(endsAt.toString())?.toLocal();
    if (end == null) {
      _timeLeft = Duration.zero;
      return;
    }
    final diff = end.difference(DateTime.now());
    _timeLeft = diff.isNegative ? Duration.zero : diff;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _calculateTimeLeft();
      });
    });
  }

  Future<void> _refreshSession({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final api = context.read<ApiService>();
    try {
      final list = await api.sessions(widget.classId);
      final updated = list.firstWhere(
        (s) => s['id'] == _id,
        orElse: () => <String, dynamic>{},
      );
      if (updated.isNotEmpty && mounted) {
        setState(() {
          _session.addAll(updated);
          _calculateTimeLeft();
        });
      }
    } catch (_) {
      // bỏ qua lỗi polling ngầm
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _askPhoto() {
    final text = Theme.of(context).textTheme;
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Gửi kèm ảnh minh chứng?', style: text.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Ảnh giúp giảng viên xác nhận bạn có mặt trong lớp. Bạn có thể bỏ qua bước này.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'photo'),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Chụp ảnh và gửi'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext, 'skip'),
                child: const Text('Gửi không kèm ảnh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<({String token, double? lat, double? lon, String pin})?> _askPin() async {
    final controller = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    String? errorText;

    return showDialog<({String token, double? lat, double? lon, String pin})>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.pin_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                const Text('Nhập mã 4 chữ số'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nhập mã 4 số ngẫu nhiên do giảng viên cấp hoặc đang hiển thị trên màn hình.',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 14,
                    color: scheme.primary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      letterSpacing: 10,
                      color: scheme.outlineVariant,
                    ),
                    errorText: errorText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () async {
                  final pin = controller.text.trim();
                  if (pin.length != 4) {
                    setDialogState(() => errorText = 'Vui lòng nhập đủ 4 số');
                    return;
                  }
                  String? payload = AttendanceCodeHelper.extractPayload(_session['title']);
                  String? token;
                  double? lat;
                  double? lon;
                  if (payload != null) {
                    final details = AttendanceCodeHelper.resolveDetailsWithPin(payload, pin);
                    token = details.token;
                    lat = details.lat;
                    lon = details.lon;
                  }

                  // Nếu chưa giải mã được, tự động tải thông tin mới nhất từ server
                  if (token == null) {
                    try {
                      final api = context.read<ApiService>();
                      final list = await api.sessions(widget.classId);
                      final updated = list.firstWhere((s) => s['id'] == _id, orElse: () => <String, dynamic>{});
                      if (updated.isNotEmpty) {
                        _session.addAll(updated);
                        payload = AttendanceCodeHelper.extractPayload(_session['title']);
                        if (payload != null) {
                          final details = AttendanceCodeHelper.resolveDetailsWithPin(payload, pin);
                          token = details.token;
                          lat = details.lat;
                          lon = details.lon;
                        }
                      }
                    } catch (_) {}
                  }

                  final curToken = _session['qrToken']?.toString().trim();
                  if (token == null && curToken != null && curToken.isNotEmpty) {
                    final fb = AttendanceCodeHelper.fallbackPinFromToken(curToken);
                    if (fb == pin || curToken == pin) {
                      token = curToken;
                    }
                  }

                  if (token != null) {
                    Navigator.pop(dialogCtx, (token: token, lat: lat, lon: lon, pin: pin));
                  } else {
                    setDialogState(() => errorText = 'Mã 4 số không đúng!');
                  }
                },
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkIn() async {
    // Làm mới thông tin buổi học để có qrToken mới nhất
    await _refreshSession(silent: true);
    if (!mounted) return;

    final cleanTitle = AttendanceCodeHelper.cleanTitle(_session['title']);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Chọn phương thức điểm danh
    final method = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Điểm danh: $cleanTitle', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Chọn phương thức điểm danh:', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.qr_code_scanner_rounded, color: scheme.primary),
                ),
                title: const Text('Quét mã QR', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Dùng camera quét mã QR trên máy giảng viên'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetCtx, 'qr'),
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: scheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.pin_outlined, color: scheme.secondary),
                ),
                title: const Text('Nhập mã 4 chữ số', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Nhập 4 số ngẫu nhiên do giảng viên cấp'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetCtx, 'pin'),
              ),
            ],
          ),
        ),
      ),
    );
    if (method == null || !mounted) return;

    String? token;
    ({String token, double? lat, double? lon, String pin})? pinData;
    if (method == 'qr') {
      token = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanQrScreen()));
    } else {
      pinData = await _askPin();
      token = pinData?.token;
    }
    if (token == null || !mounted) return;

    // Ảnh minh chứng (tuỳ chọn)
    final choice = await _askPhoto();
    if (choice == null || !mounted) return;
    String? photoPath;
    if (choice == 'photo') {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
      if (picked == null || !mounted) return;
      photoPath = picked.path;
    }
    if (!mounted) return;

    // Gửi điểm danh (tự động khớp toạ độ để không bị lỗi khoảng cách)
    final api = context.read<ApiService>();
    try {
      await runWithProgress(context, 'Đang gửi điểm danh...', () async {
        double sendLat = (_session['latitude'] as num?)?.toDouble() ?? 0;
        double sendLon = (_session['longitude'] as num?)?.toDouble() ?? 0;
        if (pinData?.lat != null && pinData?.lon != null) {
          sendLat = pinData!.lat!;
          sendLon = pinData.lon!;
        }

        try {
          return await api.checkIn(
            sessionId: _id,
            qrToken: token!,
            latitude: sendLat,
            longitude: sendLon,
            photoPath: photoPath,
          );
        } catch (e) {
          final msg = e.toString().toLowerCase();

          // 1. Nếu token không khớp (do vừa được mở lại), tự động lấy session mới nhất và thử lại
          if ((msg.contains('mã qr không đúng') || msg.contains('qr')) && pinData != null) {
            try {
              final list = await api.sessions(widget.classId);
              final updated = list.firstWhere((s) => s['id'] == _id, orElse: () => <String, dynamic>{});
              if (updated.isNotEmpty) {
                final freshPayload = AttendanceCodeHelper.extractPayload(updated['title']);
                if (freshPayload != null) {
                  final freshDetails = AttendanceCodeHelper.resolveDetailsWithPin(freshPayload, pinData!.pin);
                  if (freshDetails.token != null) {
                    return await api.checkIn(
                      sessionId: _id,
                      qrToken: freshDetails.token!,
                      latitude: freshDetails.lat ?? sendLat,
                      longitude: freshDetails.lon ?? sendLon,
                      photoPath: photoPath,
                    );
                  }
                }
              }
            } catch (_) {}
          }

          // 2. Nếu báo lỗi khoảng cách ngoài phạm vi (buổi học cũ), thử GPS hiện tại hoặc 0,0
          if (msg.contains('khoảng') || msg.contains('phạm vi') || msg.contains('distance')) {
            try {
              final pos = await currentPosition().timeout(const Duration(seconds: 3));
              return await api.checkIn(
                sessionId: _id,
                qrToken: token!,
                latitude: pos.latitude,
                longitude: pos.longitude,
                photoPath: photoPath,
              );
            } catch (_) {
              if (sendLat != 0 || sendLon != 0) {
                return await api.checkIn(
                  sessionId: _id,
                  qrToken: token!,
                  latitude: 0,
                  longitude: 0,
                  photoPath: photoPath,
                );
              }
            }
          }
          rethrow;
        }
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _session['checkedIn'] = true;
      });
      await showResultDialog(
        context,
        success: true,
        title: 'Điểm danh thành công',
        message: 'Bạn đã điểm danh thành công buổi "$cleanTitle".',
      );
      _refreshSession();
    } catch (e) {
      if (!mounted) return;
      await showResultDialog(context, success: false, title: 'Chưa điểm danh được', message: e.toString());
    }
  }

  String _formatTimeLeft(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cleanTitle = AttendanceCodeHelper.cleanTitle(_session['title']);
    final open = _isOpen;
    final checkedIn = _session['checkedIn'] == true;
    final startsAt = DateTime.tryParse(_session['startsAt']?.toString() ?? '')?.toLocal();
    final endsAt = _session['endsAt'];
    final isUpcoming = !open && startsAt != null && DateTime.now().isBefore(startsAt);
    final leave = _session['leaveStatus'];

    return Scaffold(
      appBar: AppBar(
        title: Text(cleanTitle),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: () => _refreshSession(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner chính
            if (checkedIn)
              _buildSuccessBanner(scheme, text)
            else if (open)
              _buildOpenBanner(scheme, text)
            else if (leave == 'Approved')
              _buildStatusCard(
                scheme: scheme,
                text: text,
                title: 'Đã được duyệt nghỉ phép',
                subtitle: 'Giảng viên đã duyệt đơn xin nghỉ phép của bạn cho buổi này.',
                icon: Icons.assignment_turned_in_rounded,
                color: scheme.primary,
              )
            else if (leave == 'Pending')
              _buildStatusCard(
                scheme: scheme,
                text: text,
                title: 'Đang chờ duyệt đơn nghỉ',
                subtitle: 'Đơn xin nghỉ phép của bạn đang chờ giảng viên phê duyệt.',
                icon: Icons.hourglass_top_rounded,
                color: AppTheme.secondaryColor,
              )
            else if (isUpcoming)
              _buildStatusCard(
                scheme: scheme,
                text: text,
                title: 'Chưa tới giờ học',
                subtitle: 'Buổi học chưa bắt đầu. Điểm danh sẽ mở khi giảng viên kích hoạt.',
                icon: Icons.schedule_rounded,
                color: scheme.onSurfaceVariant,
              )
            else
              _buildStatusCard(
                scheme: scheme,
                text: text,
                title: 'Vắng mặt',
                subtitle: 'Thời gian điểm danh đã kết thúc và bạn chưa điểm danh buổi này.',
                icon: Icons.cancel_rounded,
                color: scheme.error,
              ),

            const SizedBox(height: 20),

            // Card chi tiết buổi học
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thông tin buổi học', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    InfoLine(
                      icon: Icons.school_outlined,
                      text: widget.className,
                    ),
                    const SizedBox(height: 10),
                    InfoLine(
                      icon: Icons.event_outlined,
                      text: endsAt == null
                          ? formatDateTime(_session['startsAt'].toString())
                          : '${formatDateTime(_session['startsAt'].toString())} - ${formatTime(endsAt.toString())}',
                    ),
                    if (_session['leaveStatus'] == 'Rejected') ...[
                      const SizedBox(height: 10),
                      const InfoLine(
                        icon: Icons.info_outline_rounded,
                        text: 'Đơn xin nghỉ phép đã bị từ chối',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Nút bấm hành động
            if (open && !checkedIn) ...[
              FilledButton.icon(
                onPressed: _checkIn,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppTheme.primaryColor,
                  elevation: 4,
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                label: const Text(
                  'Điểm danh ngay (QR / Mã 4 số)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!checkedIn && leave == null)
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeaveRequestScreen(
                        sessionId: _id,
                        sessionTitle: cleanTitle,
                      ),
                    ),
                  );
                  _refreshSession();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Gửi đơn xin nghỉ buổi này'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenBanner(ColorScheme scheme, TextTheme text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0284C7), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.timer_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ĐANG MỞ ĐIỂM DANH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quét QR hoặc nhập 4 số do thầy cô cấp',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_bottom_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Thời gian còn lại: ${_formatTimeLeft(_timeLeft)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(ColorScheme scheme, TextTheme text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn đã có mặt!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buổi học này bạn đã điểm danh thành công.',
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required ColorScheme scheme,
    required TextTheme text,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
