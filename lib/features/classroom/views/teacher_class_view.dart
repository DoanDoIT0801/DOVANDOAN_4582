import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/attendance_code_helper.dart';
import '../../../core/utils/location_util.dart';
import '../../../core/utils/schedule_helper.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../attendance/views/session_detail_screen.dart';
import '../../attendance/views/session_qr_screen.dart';
import '../../leave_requests/views/absence_report_screen.dart';
import '../../leave_requests/views/leave_review_screen.dart';
import '../widgets/class_form_dialog.dart';
import '../widgets/class_info_card.dart';
import 'class_members_view.dart';

class TeacherClassScreen extends StatefulWidget {
  const TeacherClassScreen({super.key, required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<TeacherClassScreen> createState() => _TeacherClassScreenState();
}

class _TeacherClassScreenState extends State<TeacherClassScreen> {
  late Future<List<Json>> _future;
  Json? _detail;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Json>> _load() async {
    final api = context.read<ApiService>();
    final results = await Future.wait([api.classDetail(widget.classId), api.sessions(widget.classId)]);
    if (mounted) {
      setState(() {
        _detail = results[0] as Json;
      });
    }
    final list = List<Json>.from(results[1] as List<Json>);
    list.sort((a, b) => (a['startsAt']?.toString() ?? '').compareTo(b['startsAt']?.toString() ?? ''));
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

  // Mở một màn hình con, quay lại thì làm mới (số liệu có thể đã thay đổi).
  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  Future<void> _editClass() async {
    final api = context.read<ApiService>();
    final detail = _detail;
    if (detail == null) return;
    final List<Json> subjects;
    try {
      subjects = await api.subjects();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    final data = await showClassForm(context, cls: detail, subjects: subjects);
    if (data == null || !mounted) return;
    try {
      await api.updateClass(widget.classId, data);
      if (mounted) showMessage(context, 'Đã cập nhật thông tin lớp.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // Tạo buổi học bằng bảng trượt; vị trí lớp lấy từ GPS hiện tại. Tạo xong mở mã QR ngay.
  Future<void> _createSession() async {
    final api = context.read<ApiService>();
    final nextNumber = (_detail?['sessionCount'] as int? ?? 0) + 1;
    final result = await showModalBottomSheet<_NewSession>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewSessionSheet(defaultTitle: 'Buổi $nextNumber'),
    );
    if (result == null || !mounted) return;
    try {
      final session = await runWithProgress(context, 'Đang lấy vị trí lớp và tạo buổi học...', () async {
        final position = await currentPosition();
        final created = await api.createSession(
          widget.classId,
          title: result.title,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: 50000000,
          durationMinutes: result.minutes == 0 ? null : result.minutes,
        );
        created['classId'] = widget.classId;

        // Nếu mở điểm danh có thời hạn, tạo mã PIN và cập nhật title
        if (result.minutes > 0) {
          final qrToken = created['qrToken']?.toString() ?? '';
          final pin = AttendanceCodeHelper.fallbackPinFromToken(qrToken);
          final clean = AttendanceCodeHelper.cleanTitle(created['title']);
          final payload = AttendanceCodeHelper.createPayload(qrToken, pin, lat: position.latitude, lon: position.longitude);
          final updatedTitle = '$clean [PIN:$payload]';
          try {
            await api.updateSession(
              sessionId: created['id'] as int,
              title: updatedTitle,
              startsAt: DateTime.tryParse(created['startsAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
              latitude: position.latitude,
              longitude: position.longitude,
              radiusMeters: 50000000,
            );
            created['title'] = updatedTitle;
          } catch (_) {}

          // Kích hoạt buổi học với thời gian chính xác
          try {
            final reopened = await api.reopenSession(created['id'] as int, result.minutes);
            created['endsAt'] = reopened['endsAt'] ?? DateTime.now().add(Duration(minutes: result.minutes)).toUtc().toIso8601String();
            created['isOpen'] = true;
          } catch (_) {}
        }
        return created;
      });
      if (!mounted) return;
      await _open(SessionQrScreen(session: session));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openQrScreen(Json s) async {
    final api = context.read<ApiService>();
    String qrToken = s['qrToken']?.toString() ?? '';
    if (qrToken.isEmpty) {
      try {
        final list = await api.sessions(widget.classId);
        final updated = list.firstWhere((item) => item['id'] == s['id'], orElse: () => s);
        qrToken = updated['qrToken']?.toString() ?? qrToken;
        s.addAll(updated);
      } catch (_) {}
    }
    final pin = AttendanceCodeHelper.fallbackPinFromToken(qrToken);
    final payload = AttendanceCodeHelper.extractPayload(s['title']);
    if (payload == null && qrToken.isNotEmpty) {
      final clean = AttendanceCodeHelper.cleanTitle(s['title']);
      final newPayload = AttendanceCodeHelper.createPayload(
        qrToken,
        pin,
        lat: (s['latitude'] as num?)?.toDouble() ?? 0,
        lon: (s['longitude'] as num?)?.toDouble() ?? 0,
      );
      final updatedTitle = '$clean [PIN:$newPayload]';
      try {
        await api.updateSession(
          sessionId: s['id'] as int,
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
    await _open(SessionQrScreen(session: s, pinCode: pin));
    _reload();
  }

  Future<void> _closeSession(Json s) async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Đóng điểm danh?',
      message: 'Sinh viên sẽ không thể điểm danh buổi "${s['title']}" nữa. Bạn vẫn mở lại được sau.',
      confirmLabel: 'Đóng',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.closeSession(s['id'] as int);
      if (mounted) showMessage(context, 'Đã đóng điểm danh.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _generateSessionsFromSchedule() async {
    final schedule = _detail?['schedule']?.toString() ?? '';
    final planned = (_detail?['plannedSessions'] as int?) ?? 15;
    final plans = ScheduleDateHelper.generateSessionPlans(
      schedule: schedule,
      fallbackPlannedSessions: planned,
    );

    if (plans.isEmpty) {
      showMessage(context, 'Không tìm thấy lịch học để tạo buổi.');
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: 'Tạo ${plans.length} buổi học?',
      message: 'Hệ thống sẽ tự động tạo sẵn ${plans.length} buổi học theo thời khoá biểu:\n$schedule\n\nMỗi buổi học sẽ có danh sách sinh viên, mã QR và chức năng điểm danh.',
      confirmLabel: 'Tạo ${plans.length} buổi học',
    );
    if (!confirmed || !mounted) return;

    final api = context.read<ApiService>();
    try {
      await runWithProgress(context, 'Đang khởi tạo ${plans.length} buổi học theo lịch...', () async {
        double lat = 0;
        double lng = 0;
        try {
          final pos = await currentPosition();
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {}

        for (final p in plans) {
          await api.createSession(
            widget.classId,
            title: p.title,
            startsAt: p.startsAt,
            latitude: lat,
            longitude: lng,
            radiusMeters: 100,
            durationMinutes: p.durationMinutes,
          );
        }
      });
      if (mounted) {
        showMessage(context, 'Đã tạo thành công ${plans.length} buổi học.');
        _reload();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final studentCount = _detail?['studentCount'] as int? ?? 0;
    final scheduleStr = _detail?['schedule']?.toString() ?? '';
    final plannedSessions = (_detail?['plannedSessions'] as int?) ?? 15;
    final targetPlans = ScheduleDateHelper.generateSessionPlans(
      schedule: scheduleStr,
      fallbackPlannedSessions: plannedSessions,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Tạo các buổi học theo thời khoá biểu',
            onPressed: _generateSessionsFromSchedule,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buổi học mới'),
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.event_note_outlined,
        emptyTitle: 'Chưa có buổi học nào',
        emptyMessage: 'Bấm nút bên dưới để tạo sẵn ${targetPlans.length} buổi học theo thời khoá biểu, hoặc bấm "Buổi học mới".',
        headerBuilder: (items) {
          final openCount = items.where((s) => s['isOpen'] == true).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_detail != null) ClassInfoCard(detail: _detail!, onEdit: _editClass),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.groups_rounded,
                    label: 'Sinh viên',
                    onTap: () => _open(ClassMembersScreen(classId: widget.classId, className: widget.className)),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.inbox_rounded,
                    label: 'Đơn nghỉ',
                    onTap: () => _open(LeaveReviewScreen(classId: widget.classId)),
                  ),
                  const SizedBox(width: 12),
                  _QuickAction(
                    icon: Icons.insights_rounded,
                    label: 'Báo cáo vắng',
                    onTap: () => _open(AbsenceReportScreen(classId: widget.classId)),
                  ),
                ],
              ),
              if (items.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tự động tạo ${targetPlans.length} buổi học theo lịch',
                                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tạo trước ${targetPlans.length} buổi học theo thời khoá biểu. Mỗi buổi sẽ có danh sách sinh viên, phần điểm danh và mã QR.',
                                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: _generateSessionsFromSchedule,
                          icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
                          label: Text(
                            'Khởi tạo ${targetPlans.length} buổi học ngay',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Buổi học (${items.length}) • $openCount đang mở', style: text.titleMedium),
            ],
          );
        },
        itemBuilder: (context, s) {
          final open = s['isOpen'] == true;
          final remaining = open ? remainingLabel(s['endsAt']) : null;
          final endsAt = s['endsAt'];
          final startsAt = DateTime.tryParse(s['startsAt']?.toString() ?? '')?.toLocal();
          final isUpcoming = !open && startsAt != null && DateTime.now().isBefore(startsAt);

          final StatusChip statusChip;
          if (open) {
            statusChip = const StatusChip(label: 'Đang mở', icon: Icons.lock_open_rounded, tone: StatusTone.success);
          } else if (isUpcoming) {
            statusChip = const StatusChip(label: 'Chưa diễn ra', icon: Icons.schedule_rounded);
          } else {
            statusChip = const StatusChip(label: 'Đã kết thúc', icon: Icons.lock_outline_rounded);
          }

          final String attendanceSummary;
          if (open) {
            attendanceSummary = '${s['presentCount'] ?? 0}/$studentCount sinh viên có mặt • Chạm để xem chi tiết';
          } else if (isUpcoming) {
            attendanceSummary = 'Chưa tới ngày học • Sĩ số: $studentCount sinh viên';
          } else {
            attendanceSummary = '${s['presentCount'] ?? 0}/$studentCount sinh viên có mặt • Chạm để xem chi tiết';
          }

          return TapCard(
            onTap: () {
              s['classId'] = widget.classId;
              _open(SessionDetailScreen(session: s, classId: widget.classId));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(AttendanceCodeHelper.cleanTitle(s['title']), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                    statusChip,
                  ],
                ),
                InfoLine(
                  icon: Icons.event_outlined,
                  text: endsAt == null
                      ? formatDateTime(s['startsAt'].toString())
                      : '${formatDateTime(s['startsAt'].toString())} - ${formatTime(endsAt.toString())}',
                ),
                if (remaining != null) InfoLine(icon: Icons.timer_outlined, text: remaining),
                InfoLine(
                  icon: isUpcoming ? Icons.calendar_today_outlined : Icons.how_to_reg_outlined,
                  text: attendanceSummary,
                ),
                if (open) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openQrScreen(s),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Mã QR'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _closeSession(s),
                          icon: const Icon(Icons.lock_outline_rounded),
                          label: const Text('Đóng'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: TapCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _NewSession {
  const _NewSession(this.title, this.radius, this.minutes);

  final String title;
  final double radius;
  // 0 = mở đến khi giảng viên đóng.
  final int minutes;
}

class _NewSessionSheet extends StatefulWidget {
  const _NewSessionSheet({required this.defaultTitle});

  final String defaultTitle;

  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  late final _title = TextEditingController(text: widget.defaultTitle);
  double _radius = 100;
  int _minutes = 15;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên buổi học');
      return;
    }
    Navigator.pop(context, _NewSession(_title.text.trim(), _radius, _minutes));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Buổi học mới', style: text.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Tên buổi học', hintText: 'Ví dụ: Buổi 3 - Chương 2', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Text('Thời gian mở điểm danh', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in const [(15, '15 phút'), (30, '30 phút'), (45, '45 phút'), (90, '90 phút'), (0, 'Đến khi đóng')])
                  ChoiceChip(
                    label: Text(label),
                    selected: _minutes == value,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _minutes = value),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Phạm vi điểm danh', style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 50, label: Text('50 m')),
                ButtonSegment(value: 100, label: Text('100 m')),
                ButtonSegment(value: 200, label: Text('200 m')),
              ],
              selected: {_radius},
              onSelectionChanged: (s) => setState(() => _radius = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.my_location_rounded, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vị trí lớp được lấy từ GPS hiện tại của bạn. Hãy tạo buổi học khi đang ở trong lớp.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Tạo và hiện mã QR')),
          ],
        ),
      ),
    );
  }
}
