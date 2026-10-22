import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/attendance_code_helper.dart';
import '../../../core/utils/location_util.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/protected_image.dart';
import '../../classroom/widgets/class_info_card.dart';
import 'session_qr_screen.dart';

// Chi tiết một buổi học: trạng thái của cả lớp, điểm danh hộ, đóng/mở lại điểm danh.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.session, this.classId});

  final Json session;
  final int? classId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<List<Json>> _future;
  late bool _open = widget.session['isOpen'] == true;
  late Object? _endsAt = widget.session['endsAt'];
  String? _currentPin;

  int get _id => widget.session['id'] as int;
  int? get _classId => widget.classId ?? int.tryParse(widget.session['classId']?.toString() ?? '');

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().roster(_id);
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<ApiService>().roster(_id);
    });
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _close() async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Đóng điểm danh?',
      message: 'Sinh viên sẽ không thể điểm danh buổi này nữa. Bạn vẫn mở lại được sau.',
      confirmLabel: 'Đóng',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.closeSession(_id);
      if (!mounted) return;
      setState(() => _open = false);
      showMessage(context, 'Đã đóng điểm danh.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openAttendance() async {
    final api = context.read<ApiService>();
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Mở điểm danh trong bao lâu?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final m in const [5, 10, 15, 30])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$m phút'),
                onTap: () => Navigator.pop(sheetContext, m),
              ),
          ],
        ),
      ),
    );
    if (minutes == null) return;

    try {
      // 1. Lấy toạ độ GPS nếu có
      double lat = (widget.session['latitude'] as num?)?.toDouble() ?? 0;
      double lon = (widget.session['longitude'] as num?)?.toDouble() ?? 0;
      if (lat == 0 && lon == 0) {
        try {
          final pos = await currentPosition();
          lat = pos.latitude;
          lon = pos.longitude;
          widget.session['latitude'] = lat;
          widget.session['longitude'] = lon;
        } catch (_) {}
      }

      // 2. Đảm bảo có qrToken chính xác
      String qrToken = widget.session['qrToken']?.toString() ?? '';
      if (qrToken.isEmpty && _classId != null) {
        try {
          final list = await api.sessions(_classId!);
          final updated = list.firstWhere((s) => s['id'] == _id, orElse: () => <String, dynamic>{});
          if (updated.isNotEmpty) {
            qrToken = updated['qrToken']?.toString() ?? qrToken;
            widget.session.addAll(updated);
          }
        } catch (_) {}
      }

      // 3. Tạo mã PIN và payload gắn vào tiêu đề
      final pin = AttendanceCodeHelper.fallbackPinFromToken(qrToken);
      final clean = AttendanceCodeHelper.cleanTitle(widget.session['title']);
      final payload = AttendanceCodeHelper.createPayload(qrToken, pin, lat: lat, lon: lon);
      final updatedTitle = '$clean [PIN:$payload]';

      // 4. Cập nhật tiêu đề chứa PIN và mở rộng bán kính 50,000 km
      await api.updateSession(
        sessionId: _id,
        title: updatedTitle,
        startsAt: DateTime.tryParse(widget.session['startsAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        latitude: lat,
        longitude: lon,
        radiusMeters: 50000000,
      );
      widget.session['title'] = updatedTitle;

      // 5. Mở điểm danh với thời gian phút đã chọn
      final reopened = await api.reopenSession(_id, minutes);
      final endsAt = reopened['endsAt'] ?? DateTime.now().add(Duration(minutes: minutes)).toUtc().toIso8601String();

      if (!mounted) return;
      widget.session['endsAt'] = endsAt;
      widget.session['qrToken'] = qrToken;
      widget.session['isOpen'] = true;
      setState(() {
        _open = true;
        _endsAt = endsAt;
        _currentPin = pin;
      });

      // 6. Mở màn hình hiển thị Mã QR & Mã 4 số
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionQrScreen(
            session: widget.session,
            pinCode: pin,
          ),
        ),
      );
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // Điểm danh hộ, có nút hoàn tác trên thông báo.
  Future<void> _markPresent(Json st) async {
    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.manualCheckIn(_id, st['studentId'] as int);
      _reload();
      messenger.showSnackBar(SnackBar(
        content: Text('Đã điểm danh hộ ${st['fullName']}.'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () async {
            await api.removeAttendance(_id, st['studentId'] as int);
            _reload();
          },
        ),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _removeAttendance(Json st) async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Huỷ điểm danh?',
      message: '${st['fullName']} sẽ được tính là vắng buổi này.',
      confirmLabel: 'Huỷ điểm danh',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.removeAttendance(_id, st['studentId'] as int);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  StatusChip _chip(String status, bool isUpcoming) {
    switch (status) {
      case 'Present':
        return const StatusChip(label: 'Có mặt', icon: Icons.check_circle_rounded, tone: StatusTone.success);
      case 'Excused':
        return const StatusChip(label: 'Có phép', icon: Icons.assignment_turned_in_rounded, tone: StatusTone.info);
      case 'PendingLeave':
        return const StatusChip(label: 'Chờ duyệt đơn', icon: Icons.hourglass_top_rounded, tone: StatusTone.warning);
      default:
        if (_open) {
          return const StatusChip(label: 'Chưa điểm danh', icon: Icons.schedule_rounded);
        }
        if (isUpcoming) {
          return const StatusChip(label: 'Chưa diễn ra', icon: Icons.schedule_rounded);
        }
        return const StatusChip(label: 'Vắng', icon: Icons.cancel_rounded, tone: StatusTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = widget.session;
    final remaining = _open ? remainingLabel(_endsAt) : null;
    final startsAt = DateTime.tryParse(s['startsAt']?.toString() ?? '')?.toLocal();
    final isUpcoming = !_open && startsAt != null && DateTime.now().isBefore(startsAt);

    return Scaffold(
      appBar: AppBar(title: Text(AttendanceCodeHelper.cleanTitle(s['title']))),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        emptyIcon: Icons.groups_outlined,
        emptyTitle: 'Lớp chưa có sinh viên',
        headerBuilder: (items) {
          int count(String status) => items.where((r) => r['status'] == status).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(formatDateTime(s['startsAt'].toString()), style: text.titleMedium)),
                          _open
                              ? const StatusChip(label: 'Đang mở', icon: Icons.lock_open_rounded, tone: StatusTone.success)
                              : isUpcoming
                                  ? const StatusChip(label: 'Chưa diễn ra', icon: Icons.schedule_rounded)
                                  : const StatusChip(label: 'Đã kết thúc', icon: Icons.lock_outline_rounded),
                        ],
                      ),
                      if (remaining != null) InfoLine(icon: Icons.timer_outlined, text: remaining),
                      InfoLine(icon: Icons.near_me_outlined, text: 'Bán kính ${(s['radiusMeters'] as num).round()} m'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          StatTile(value: '${count('Present')}', label: 'Có mặt', icon: Icons.check_circle_rounded, color: AppTheme.successColor),
                          const SizedBox(width: 8),
                          StatTile(value: '${count('Excused')}', label: 'Có phép', icon: Icons.assignment_turned_in_rounded, color: scheme.primary),
                          const SizedBox(width: 8),
                          StatTile(
                            value: '${count('Absent') + count('PendingLeave')}',
                            label: _open
                                ? 'Chưa điểm danh'
                                : isUpcoming
                                    ? 'Chưa diễn ra'
                                    : 'Vắng',
                            icon: isUpcoming
                                ? Icons.schedule_rounded
                                : _open
                                    ? Icons.schedule_rounded
                                    : Icons.cancel_rounded,
                            color: isUpcoming
                                ? scheme.onSurfaceVariant
                                : _open
                                    ? scheme.primary
                                    : scheme.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_open) ...[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final api = context.read<ApiService>();
                                  String currentPin = _currentPin ?? AttendanceCodeHelper.extractPin(s['title']) ?? '';
                                  if (currentPin.isEmpty || AttendanceCodeHelper.extractPayload(s['title']) == null) {
                                    String qrToken = s['qrToken']?.toString() ?? '';
                                    if (qrToken.isEmpty && _classId != null) {
                                      try {
                                        final list = await api.sessions(_classId!);
                                        final updated = list.firstWhere((item) => item['id'] == _id, orElse: () => s);
                                        qrToken = updated['qrToken']?.toString() ?? qrToken;
                                        s.addAll(updated);
                                      } catch (_) {}
                                    }
                                    currentPin = AttendanceCodeHelper.fallbackPinFromToken(qrToken);
                                    final clean = AttendanceCodeHelper.cleanTitle(s['title']);
                                    final payload = AttendanceCodeHelper.createPayload(qrToken, currentPin,
                                      lat: (s['latitude'] as num?)?.toDouble() ?? 0,
                                      lon: (s['longitude'] as num?)?.toDouble() ?? 0,
                                    );
                                    final updatedTitle = '$clean [PIN:$payload]';
                                    try {
                                      await api.updateSession(
                                        sessionId: _id,
                                        title: updatedTitle,
                                        startsAt: DateTime.tryParse(s['startsAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
                                        latitude: (s['latitude'] as num?)?.toDouble() ?? 0,
                                        longitude: (s['longitude'] as num?)?.toDouble() ?? 0,
                                        radiusMeters: 50000000,
                                      );
                                      s['title'] = updatedTitle;
                                    } catch (_) {}
                                  }
                                  if (!mounted) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SessionQrScreen(session: s, pinCode: currentPin.isNotEmpty ? currentPin : null),
                                    ),
                                  );
                                  _reload();
                                },
                                icon: const Icon(Icons.qr_code_2_rounded),
                                label: const Text('Mã QR & Mã số'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _close,
                                icon: const Icon(Icons.lock_outline_rounded),
                                label: const Text('Đóng'),
                              ),
                            ),
                          ] else
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _openAttendance,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Mở điểm danh'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Danh sách lớp (${items.length})', style: text.titleMedium),
            ],
          );
        },
        itemBuilder: (context, st) {
          final present = st['status'] == 'Present';
          final details = present
              ? [
                  'Lúc ${formatTime(st['checkedInAt'].toString())}',
                  st['isManual'] == true ? 'Điểm danh hộ' : 'Cách lớp ${(st['distanceMeters'] as num).round()} m',
                ].join(' • ')
              : st['username'].toString();
          return Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  InitialsAvatar(name: st['fullName'].toString(), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st['fullName'].toString(), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text(details, style: text.bodySmall),
                        const SizedBox(height: 6),
                        _chip(st['status'].toString(), isUpcoming),
                      ],
                    ),
                  ),
                  if (present && st['hasPhoto'] == true)
                    IconButton(
                      tooltip: 'Xem ảnh minh chứng',
                      icon: const Icon(Icons.photo_outlined),
                      onPressed: () => showProtectedImage(context, '/api/attendances/${st['attendanceId']}/photo'),
                    ),
                  if (present)
                    IconButton(
                      tooltip: 'Huỷ điểm danh của ${st['fullName']}',
                      icon: Icon(Icons.person_off_outlined, color: scheme.error),
                      onPressed: () => _removeAttendance(st),
                    )
                  else
                    TextButton(onPressed: () => _markPresent(st), child: const Text('Điểm danh hộ')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
