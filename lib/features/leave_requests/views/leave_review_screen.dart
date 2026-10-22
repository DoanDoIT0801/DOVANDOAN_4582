import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/protected_image.dart';

class LeaveReviewScreen extends StatefulWidget {
  const LeaveReviewScreen({super.key, required this.classId});

  final int classId;

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Đơn chờ duyệt lên đầu.
  Future<List<Json>> _load() async {
    final list = await context.read<ApiService>().classLeaves(widget.classId);
    list.sort((a, b) => (b['status'] == 'Pending' ? 1 : 0) - (a['status'] == 'Pending' ? 1 : 0));
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

  Future<void> _review(Json l, bool approve) async {
    try {
      await context.read<ApiService>().reviewLeave(l['id'] as int, approve: approve);
      if (mounted) showMessage(context, approve ? 'Đã duyệt đơn của ${l['student']}.' : 'Đã từ chối đơn của ${l['student']}.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn xin nghỉ')),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        emptyIcon: Icons.inbox_outlined,
        emptyTitle: 'Chưa có đơn xin nghỉ',
        headerBuilder: (items) {
          final pending = items.where((l) => l['status'] == 'Pending').length;
          return Text(pending == 0 ? 'Không có đơn chờ duyệt' : '$pending đơn đang chờ duyệt', style: text.titleMedium);
        },
        itemBuilder: (context, l) {
          final pending = l['status'] == 'Pending';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(name: l['student'].toString(), size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l['student'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(l['session'].toString(), style: text.bodySmall),
                          ],
                        ),
                      ),
                      leaveStatusChip(l['status'].toString()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l['reason'].toString(), style: text.bodyMedium),
                  InfoLine(icon: Icons.schedule_rounded, text: 'Gửi lúc ${formatDateTime(l['createdAt'].toString())}'),
                  if (l['hasEvidence'] == true)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showProtectedImage(context, '/api/leave-requests/${l['id']}/evidence'),
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Xem minh chứng'),
                      ),
                    ),
                  if (pending) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => _review(l, false), child: const Text('Từ chối'))),
                        const SizedBox(width: 12),
                        Expanded(child: FilledButton(onPressed: () => _review(l, true), child: const Text('Duyệt'))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
