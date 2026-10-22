import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';

// Tab "Đơn nghỉ" của sinh viên.
class MyLeavesView extends StatefulWidget {
  const MyLeavesView({super.key});

  @override
  State<MyLeavesView> createState() => _MyLeavesViewState();
}

class _MyLeavesViewState extends State<MyLeavesView> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().myLeaves();
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<ApiService>().myLeaves();
    });
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AsyncListView(
      future: _future,
      onRefresh: _reload,
      emptyIcon: Icons.assignment_outlined,
      emptyTitle: 'Chưa có đơn xin nghỉ',
      emptyMessage: 'Vào một lớp học, chọn buổi học rồi bấm "Xin nghỉ" để gửi đơn.',
      itemBuilder: (context, l) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l['session'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                  leaveStatusChip(l['status'].toString()),
                ],
              ),
              const SizedBox(height: 8),
              Text(l['reason'].toString(), style: text.bodyMedium),
              InfoLine(icon: Icons.schedule_rounded, text: 'Gửi lúc ${formatDateTime(l['createdAt'].toString())}'),
            ],
          ),
        ),
      ),
    );
  }
}
