import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../classroom/widgets/class_info_card.dart';

// Báo cáo vắng với cảnh báo sớm: sinh viên còn từ 1 buổi được nghỉ trở xuống sẽ bị đánh dấu.
class AbsenceReportScreen extends StatefulWidget {
  const AbsenceReportScreen({super.key, required this.classId});

  final int classId;

  @override
  State<AbsenceReportScreen> createState() => _AbsenceReportScreenState();
}

class _AbsenceReportScreenState extends State<AbsenceReportScreen> {
  late Future<List<Json>> _future;
  int _warnedCount = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Sinh viên bị cảnh báo lên đầu, sau đó theo số buổi còn được nghỉ tăng dần.
  Future<List<Json>> _load() async {
    final list = await context.read<ApiService>().absenceReport(widget.classId);
    list.sort((a, b) => (a['remainingAbsences'] as int).compareTo(b['remainingAbsences'] as int));
    if (mounted) {
      setState(() {
        _warnedCount = list.where((r) => r['isWarned'] == true).length;
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

  Future<void> _sendWarnings() async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Gửi email cảnh báo?',
      message: 'Hệ thống sẽ gửi email nhắc nhở tới $_warnedCount sinh viên sắp hết hoặc đã hết số buổi được nghỉ.',
      confirmLabel: 'Gửi',
    );
    if (!ok || !mounted) return;
    try {
      final res = await runWithProgress(context, 'Đang gửi email cảnh báo...', () => api.sendWarnings(widget.classId));
      if (mounted) showMessage(context, 'Đã gửi cảnh báo cho ${res['sent']} sinh viên.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo vắng')),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.groups_outlined,
        emptyTitle: 'Lớp chưa có sinh viên',
        headerBuilder: (items) {
          final warn = _warnedCount > 0;
          final held = items.isEmpty ? 0 : items.first['totalSessions'] as int;
          return Card(
            color: warn ? scheme.errorContainer : scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(warn ? Icons.warning_amber_rounded : Icons.verified_rounded,
                      size: 36, color: warn ? scheme.onErrorContainer : scheme.onPrimaryContainer),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warn
                              ? '$_warnedCount/${items.length} sinh viên sắp hết hoặc đã hết số buổi được nghỉ'
                              : 'Chưa có sinh viên nào cần cảnh báo',
                          style: text.titleMedium?.copyWith(color: warn ? scheme.onErrorContainer : scheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tính trên $held buổi đã kết thúc. Buổi có đơn nghỉ được duyệt không tính là vắng.',
                          style: text.bodySmall?.copyWith(color: warn ? scheme.onErrorContainer : scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        itemBuilder: (context, r) {
          final warned = r['isWarned'] == true;
          final absent = r['absentSessions'] as int;
          final remaining = r['remainingAbsences'] as int;
          final allowed = absent + remaining;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(name: r['fullName'].toString(), size: 40),
                      const SizedBox(width: 12),
                      Expanded(child: Text(r['fullName'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                      warned
                          ? const StatusChip(label: 'Cảnh báo', icon: Icons.warning_amber_rounded, tone: StatusTone.danger)
                          : const StatusChip(label: 'Ổn', icon: Icons.check_circle_rounded, tone: StatusTone.success),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatTile(value: '${r['presentSessions']}', label: 'Có mặt', icon: Icons.check_circle_rounded, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      StatTile(value: '${r['excusedSessions']}', label: 'Có phép', icon: Icons.assignment_turned_in_rounded, color: scheme.primary),
                      const SizedBox(width: 8),
                      StatTile(value: '$absent', label: 'Vắng', icon: Icons.cancel_rounded, color: scheme.error),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: allowed <= 0 ? 1 : (absent / allowed).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      color: warned ? scheme.error : scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                      semanticsLabel: 'Số buổi đã nghỉ so với mức cho phép',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    remaining >= 0 ? 'Còn được nghỉ $remaining/$allowed buổi' : 'Đã nghỉ vượt ${-remaining} buổi so với mức cho phép',
                    style: text.bodyMedium?.copyWith(color: warned ? scheme.error : null),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _warnedCount > 0
          ? FloatingActionButton.extended(
              onPressed: _sendWarnings,
              icon: const Icon(Icons.forward_to_inbox_rounded),
              label: Text('Gửi cảnh báo ($_warnedCount)'),
            )
          : null,
    );
  }
}
