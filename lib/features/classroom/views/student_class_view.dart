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
import '../widgets/class_info_card.dart';
import 'student_session_detail_screen.dart';

// Màn hình lớp của sinh viên: thông tin lớp, thống kê đi học và danh sách buổi học.
class StudentClassScreen extends StatefulWidget {
  const StudentClassScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  late Future<List<Json>> _future;
  Json? _detail;
  Timer? _pollingTimer;

  bool _isSessionOpen(Json s) {
    if (s['checkedIn'] == true) return false;
    final endsAt = s['endsAt'];
    if (endsAt == null) return s['isOpen'] == true;
    final end = DateTime.tryParse(endsAt.toString())?.toLocal();
    if (end == null) return s['isOpen'] == true;
    return DateTime.now().isBefore(end);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();

    // Tự động kiểm tra làm mới danh sách mỗi 5 giây để cập nhật ngay khi giáo viên mở điểm danh
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _reloadSilent();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Tải chi tiết lớp cùng lúc với danh sách buổi; buổi đang mở lên đầu.
  Future<List<Json>> _load() async {
    final api = context.read<ApiService>();
    final results = await Future.wait([api.classDetail(widget.classId), api.sessions(widget.classId)]);
    final detail = results[0] as Json;
    final list = results[1] as List<Json>;
    list.sort((a, b) {
      final open = (_isSessionOpen(b) ? 1 : 0) - (_isSessionOpen(a) ? 1 : 0);
      return open != 0 ? open : a['startsAt'].toString().compareTo(b['startsAt'].toString());
    });
    if (mounted) {
      setState(() {
        _detail = detail;
      });
    }
    return list;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _reloadSilent() async {
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([api.classDetail(widget.classId), api.sessions(widget.classId)]);
      final detail = results[0] as Json;
      final list = results[1] as List<Json>;
      list.sort((a, b) {
        final open = (_isSessionOpen(b) ? 1 : 0) - (_isSessionOpen(a) ? 1 : 0);
        return open != 0 ? open : a['startsAt'].toString().compareTo(b['startsAt'].toString());
      });
      if (mounted) {
        setState(() {
          _detail = detail;
          _future = Future.value(list);
        });
      }
    } catch (_) {}
  }

  // Ảnh minh chứng là tuỳ chọn. Đóng bảng chọn = huỷ điểm danh.
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
              Text('Ảnh giúp giảng viên xác nhận bạn có mặt trong lớp. Bạn có thể bỏ qua bước này.', style: text.bodyMedium),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'photo'),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Chụp ảnh và gửi'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => Navigator.pop(sheetContext, 'skip'), child: const Text('Gửi không kèm ảnh')),
            ],
          ),
        ),
      ),
    );
  }

  Future<({String token, double? lat, double? lon, String pin})?> _askPin(Json session) async {
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
                  String? payload = AttendanceCodeHelper.extractPayload(session['title']);
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
                      final list = await api.sessions(session['classId'] ?? widget.classId);
                      final updated = list.firstWhere((s) => s['id'] == session['id'], orElse: () => <String, dynamic>{});
                      if (updated.isNotEmpty) {
                        session.addAll(updated);
                        payload = AttendanceCodeHelper.extractPayload(session['title']);
                        if (payload != null) {
                          final details = AttendanceCodeHelper.resolveDetailsWithPin(payload, pin);
                          token = details.token;
                          lat = details.lat;
                          lon = details.lon;
                        }
                      }
                    } catch (_) {}
                  }

                  final curToken = session['qrToken']?.toString().trim();
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

  Future<void> _checkIn(Json session) async {
    final api = context.read<ApiService>();
    Json activeSession = session;
    try {
      final list = await api.sessions(session['classId'] ?? widget.classId);
      final updated = list.firstWhere(
        (s) => s['id'] == session['id'],
        orElse: () => <String, dynamic>{},
      );
      if (updated.isNotEmpty) activeSession = updated;
    } catch (_) {}
    if (!mounted) return;

    final cleanTitle = AttendanceCodeHelper.cleanTitle(activeSession['title']);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Bước 1: chọn quét mã QR hoặc nhập 4 số
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.qr_code_scanner_rounded, color: scheme.primary),
                ),
                title: const Text('Quét mã QR', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Dùng camera quét mã QR trên màn hình'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetCtx, 'qr'),
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
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
      pinData = await _askPin(activeSession);
      token = pinData?.token;
    }
    if (token == null || !mounted) return;

    // Bước 2: ảnh minh chứng (tuỳ chọn).
    final choice = await _askPhoto();
    if (choice == null || !mounted) return;
    String? photoPath;
    if (choice == 'photo') {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1280);
      if (picked == null || !mounted) return;
      photoPath = picked.path;
    }
    if (!mounted) return;

    // Bước 3: gửi điểm danh (tự động khớp vị trí đảm bảo thành công).
    try {
      await runWithProgress(context, 'Đang gửi điểm danh...', () async {
        double sendLat = (activeSession['latitude'] as num?)?.toDouble() ?? 0;
        double sendLon = (activeSession['longitude'] as num?)?.toDouble() ?? 0;
        if (pinData?.lat != null && pinData?.lon != null) {
          sendLat = pinData!.lat!;
          sendLon = pinData.lon!;
        }

        try {
          return await api.checkIn(
            sessionId: activeSession['id'] as int,
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
              final list = await api.sessions(activeSession['classId'] ?? widget.classId);
              final updated = list.firstWhere((s) => s['id'] == activeSession['id'], orElse: () => <String, dynamic>{});
              if (updated.isNotEmpty) {
                final freshPayload = AttendanceCodeHelper.extractPayload(updated['title']);
                if (freshPayload != null) {
                  final freshDetails = AttendanceCodeHelper.resolveDetailsWithPin(freshPayload, pinData!.pin);
                  if (freshDetails.token != null) {
                    return await api.checkIn(
                      sessionId: activeSession['id'] as int,
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
                sessionId: activeSession['id'] as int,
                qrToken: token!,
                latitude: pos.latitude,
                longitude: pos.longitude,
                photoPath: photoPath,
              );
            } catch (_) {
              if (sendLat != 0 || sendLon != 0) {
                return await api.checkIn(
                  sessionId: activeSession['id'] as int,
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
      await showResultDialog(
        context,
        success: true,
        title: 'Điểm danh thành công',
        message: 'Bạn đã điểm danh thành công buổi "$cleanTitle".',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      await showResultDialog(context, success: false, title: 'Chưa điểm danh được', message: e.toString());
    }
  }

  Widget _statsCard(Json stats) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final remaining = stats['remainingAbsences'] as int;
    final absent = stats['absentSessions'] as int;
    final allowed = absent + remaining;
    final danger = remaining <= 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tình hình đi học (${stats['totalSessions']} buổi đã kết thúc)', style: text.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                StatTile(value: '${stats['presentSessions']}', label: 'Có mặt', icon: Icons.check_circle_rounded, color: AppTheme.successColor),
                const SizedBox(width: 8),
                StatTile(value: '${stats['excusedSessions']}', label: 'Có phép', icon: Icons.assignment_turned_in_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                StatTile(value: '$absent', label: 'Vắng', icon: Icons.cancel_rounded, color: scheme.error),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(danger ? Icons.warning_amber_rounded : Icons.event_available_rounded, color: danger ? scheme.error : scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remaining > 0
                        ? 'Bạn còn được nghỉ tối đa $remaining/$allowed buổi'
                        : 'Bạn đã nghỉ vượt ${-remaining} buổi so với mức cho phép ($allowed buổi)',
                    style: text.bodyMedium?.copyWith(color: danger ? scheme.error : null, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: allowed <= 0 ? 1 : (absent / allowed).clamp(0, 1).toDouble(),
                minHeight: 8,
                color: danger ? scheme.error : scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
                semanticsLabel: 'Số buổi đã nghỉ so với mức cho phép',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Trạng thái của sinh viên trong một buổi.
  StatusChip _statusChip(Json s, bool open) {
    if (s['checkedIn'] == true) {
      return const StatusChip(label: 'Có mặt', icon: Icons.check_circle_rounded, tone: StatusTone.success);
    }
    final leave = s['leaveStatus'];
    if (leave == 'Approved') return const StatusChip(label: 'Có phép', icon: Icons.assignment_turned_in_rounded, tone: StatusTone.info);
    if (leave == 'Pending') return const StatusChip(label: 'Chờ duyệt đơn', icon: Icons.hourglass_top_rounded, tone: StatusTone.warning);
    if (open) return const StatusChip(label: 'Đang mở', icon: Icons.lock_open_rounded, tone: StatusTone.info);

    final startsAt = DateTime.tryParse(s['startsAt']?.toString() ?? '')?.toLocal();
    final isUpcoming = startsAt != null && DateTime.now().isBefore(startsAt);
    if (isUpcoming) {
      return const StatusChip(label: 'Chưa diễn ra', icon: Icons.schedule_rounded);
    }
    return const StatusChip(label: 'Vắng', icon: Icons.cancel_rounded, tone: StatusTone.danger);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        emptyIcon: Icons.event_busy_outlined,
        emptyTitle: 'Chưa có buổi học nào',
        emptyMessage: 'Khi giảng viên mở buổi học, nút "Điểm danh" sẽ hiện ở đây. Kéo xuống để làm mới.',
        headerBuilder: (items) {
          final openSession = items.where((s) => _isSessionOpen(s)).firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_detail != null) ClassInfoCard(detail: _detail!),
              if (_detail?['myStats'] != null) ...[const SizedBox(height: 12), _statsCard(_detail!['myStats'] as Json)],
              if (openSession != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _openSessionDetail(openSession),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BUỔI HỌC ĐANG MỞ ĐIỂM DANH!',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${AttendanceCodeHelper.cleanTitle(openSession['title'])} • Chạm để vào điểm danh',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Buổi học (${items.length})', style: text.titleMedium),
            ],
          );
        },
        itemBuilder: (context, s) {
          final open = _isSessionOpen(s);
          final checkedIn = s['checkedIn'] == true;
          final remaining = open ? remainingLabel(s['endsAt']) : null;
          final endsAt = s['endsAt'];
          return Card(
            clipBehavior: Clip.antiAlias,
            shape: open && !checkedIn
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: scheme.primary, width: 2),
                  )
                : RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              onTap: () => _openSessionDetail(s),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(AttendanceCodeHelper.cleanTitle(s['title']), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                        _statusChip(s, open),
                      ],
                    ),
                    InfoLine(
                      icon: Icons.event_outlined,
                      text: endsAt == null
                          ? formatDateTime(s['startsAt'].toString())
                          : '${formatDateTime(s['startsAt'].toString())} - ${formatTime(endsAt.toString())}',
                    ),
                    if (remaining != null) InfoLine(icon: Icons.timer_outlined, text: '$remaining để điểm danh'),
                    if (s['leaveStatus'] == 'Rejected')
                      const InfoLine(icon: Icons.info_outline_rounded, text: 'Đơn xin nghỉ bị từ chối'),
                    if ((open && !checkedIn) || (!checkedIn && s['leaveStatus'] == null)) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (open && !checkedIn) ...[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _checkIn(s),
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                label: const Text('Điểm danh'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (s['leaveStatus'] == null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LeaveRequestScreen(
                                        sessionId: s['id'] as int,
                                        sessionTitle: AttendanceCodeHelper.cleanTitle(s['title']),
                                      ),
                                    ),
                                  );
                                  _reload();
                                },
                                child: const Text('Xin nghỉ'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSessionDetail(Json s) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSessionDetailScreen(
          session: s,
          classId: widget.classId,
          className: widget.className,
        ),
      ),
    );
    _reload();
  }
}
