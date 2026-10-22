import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';

// Danh sách sinh viên của lớp với tính năng tìm kiếm, tóm tắt thông tin lớp,
// và thêm sinh viên hàng loạt (Batch Enrollment).
class ClassMembersScreen extends StatefulWidget {
  const ClassMembersScreen({
    super.key,
    required this.classId,
    required this.className,
    this.classInfo,
  });

  final int classId;
  final String className;
  final Json? classInfo;

  @override
  State<ClassMembersScreen> createState() => _ClassMembersScreenState();
}

class _ClassMembersScreenState extends State<ClassMembersScreen> {
  late Future<List<Json>> _future;
  Json? _detail;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _detail = widget.classInfo;
    _future = context.read<ApiService>().classStudents(widget.classId);
    _fetchDetail();
  }

  void _reload() {
    setState(() {
      _future = context.read<ApiService>().classStudents(widget.classId);
    });
  }

  Future<void> _fetchDetail() async {
    try {
      final d = await context.read<ApiService>().classDetail(widget.classId);
      if (mounted) setState(() => _detail = d);
    } catch (_) {}
  }

  Future<void> _add() async {
    final api = context.read<ApiService>();
    final pickedList = await showModalBottomSheet<List<Json>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BatchStudentPicker(
        classId: widget.classId,
        className: widget.className,
      ),
    );

    if (pickedList == null || pickedList.isEmpty || !mounted) return;

    // Tiến hành ghi danh hàng loạt
    int successCount = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang thêm sinh viên vào lớp...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    for (final s in pickedList) {
      try {
        await api.enroll(widget.classId, s['id'] as int);
        successCount++;
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context); // Tắt loading dialog
      showMessage(context, 'Đã thêm $successCount sinh viên vào lớp ${widget.className}.');
      _reload();
      _fetchDetail();
    }
  }

  Future<void> _remove(Json s) async {
    final api = context.read<ApiService>();
    final ok = await confirmAction(
      context,
      title: 'Xoá khỏi lớp?',
      message: 'Bỏ sinh viên ${s['fullName']} (${s['username']}) khỏi lớp ${widget.className}?\nLịch sử điểm danh cũ vẫn sẽ được lưu trữ an toàn.',
      confirmLabel: 'Xoá khỏi lớp',
      destructive: true,
    );
    if (!ok) return;
    try {
      await api.unenroll(widget.classId, s['studentId'] as int);
      if (mounted) showMessage(context, 'Đã đưa ${s['fullName']} ra khỏi lớp.');
      _reload();
      _fetchDetail();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quản lý Sinh viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.className, style: TextStyle(fontSize: 13, color: scheme.primary, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: () {
              _reload();
              _fetchDetail();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Thêm sinh viên'),
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return ErrorState(message: snap.error.toString(), onRetry: _reload);
          }

          final allStudents = snap.data ?? [];
          final q = _search.trim().toLowerCase();
          final filtered = q.isEmpty
              ? allStudents
              : allStudents.where((s) {
                  final name = (s['fullName'] ?? '').toString().toLowerCase();
                  final user = (s['username'] ?? '').toString().toLowerCase();
                  final email = (s['email'] ?? '').toString().toLowerCase();
                  return name.contains(q) || user.contains(q) || email.contains(q);
                }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _fetchDetail();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                // Thẻ tóm tắt thông tin lớp học
                if (_detail != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.08),
                          scheme.primaryContainer.withValues(alpha: 0.35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.class_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.className,
                                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (_detail!['subject'] != null)
                                    Text(
                                      'Môn: ${_detail!['subject']}',
                                      style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusChip(
                              label: '${allStudents.length} sinh viên',
                              icon: Icons.groups_rounded,
                              tone: allStudents.isEmpty ? StatusTone.neutral : StatusTone.info,
                            ),
                            if (_detail!['teacher'] != null)
                              StatusChip(
                                label: 'GV: ${_detail!['teacher']}',
                                icon: Icons.badge_rounded,
                                tone: StatusTone.warning,
                              ),
                            if (_detail!['room'] != null && _detail!['room'].toString().isNotEmpty)
                              StatusChip(
                                label: _detail!['room'].toString(),
                                icon: Icons.meeting_room_outlined,
                                tone: StatusTone.neutral,
                              ),
                            if (_detail!['schedule'] != null && _detail!['schedule'].toString().isNotEmpty)
                              StatusChip(
                                label: _detail!['schedule'].toString(),
                                icon: Icons.schedule_rounded,
                                tone: StatusTone.neutral,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Ô tìm kiếm sinh viên trong lớp
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm sinh viên theo tên, MSSV, email...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 16),

                // Tiêu đề số lượng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      q.isEmpty ? '${allStudents.length} sinh viên trong lớp' : 'Kết quả: ${filtered.length} / ${allStudents.length} sinh viên',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (allStudents.isNotEmpty)
                      TextButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Thêm SV'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (allStudents.isEmpty)
                  EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Lớp chưa có sinh viên nào',
                    message: 'Bấm nút "Thêm sinh viên" phía dưới để ghi danh sinh viên vào lớp học này.',
                    action: FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Thêm sinh viên ngay'),
                    ),
                  )
                else if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Không tìm thấy sinh viên',
                    message: 'Không có sinh viên nào khớp với từ khoá "$_search".',
                  )
                else
                  for (final s in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TapCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            InitialsAvatar(name: s['fullName'].toString(), size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['fullName'].toString(),
                                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s['username']} • ${s['email']}',
                                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xoá khỏi lớp',
                              icon: Icon(Icons.person_remove_outlined, color: scheme.error, size: 22),
                              onPressed: () => _remove(s),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Bảng chọn sinh viên hàng loạt (Batch Student Picker)
class _BatchStudentPicker extends StatefulWidget {
  const _BatchStudentPicker({required this.classId, required this.className});

  final int classId;
  final String className;

  @override
  State<_BatchStudentPicker> createState() => _BatchStudentPickerState();
}

class _BatchStudentPickerState extends State<_BatchStudentPicker> {
  Timer? _debounce;
  late Future<List<Json>> _future;
  final Set<int> _selectedIds = {};
  final Map<int, Json> _selectedMap = {};
  List<Json> _lastCandidates = [];

  @override
  void initState() {
    super.initState();
    _future = _loadCandidates('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<Json>> _loadCandidates(String query) async {
    final list = await context.read<ApiService>().classCandidates(widget.classId, query: query);
    _lastCandidates = list;
    return list;
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _future = _loadCandidates(q.trim());
        });
      }
    });
  }

  void _toggleAll() {
    setState(() {
      final allSelected = _lastCandidates.isNotEmpty && _lastCandidates.every((c) => _selectedIds.contains(c['id'] as int));
      if (allSelected) {
        for (final c in _lastCandidates) {
          final id = c['id'] as int;
          _selectedIds.remove(id);
          _selectedMap.remove(id);
        }
      } else {
        for (final c in _lastCandidates) {
          final id = c['id'] as int;
          _selectedIds.add(id);
          _selectedMap[id] = c;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thêm sinh viên vào lớp', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(widget.className, style: text.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Tìm sinh viên theo tên, tài khoản, email...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: _onQuery,
            ),
          ),

          // Quick action row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedIds.isEmpty ? 'Chọn sinh viên bên dưới' : 'Đã chọn: ${_selectedIds.length} sinh viên',
                  style: TextStyle(
                    color: _selectedIds.isEmpty ? scheme.onSurfaceVariant : scheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (_lastCandidates.isNotEmpty)
                  TextButton.icon(
                    onPressed: _toggleAll,
                    icon: Icon(
                      _lastCandidates.every((c) => _selectedIds.contains(c['id'] as int))
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _lastCandidates.every((c) => _selectedIds.contains(c['id'] as int)) ? 'Bỏ chọn hết' : 'Chọn tất cả',
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Danh sách sinh viên khả dụng
          Expanded(
            child: FutureBuilder<List<Json>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text(snap.error.toString()));
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Không tìm thấy sinh viên',
                    message: 'Tất cả sinh viên khả dụng đã có trong lớp, hoặc từ khoá tìm kiếm không khớp.',
                  );
                }

                return ListView.builder(
                  itemCount: list.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    final id = s['id'] as int;
                    final isSelected = _selectedIds.contains(id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? scheme.primary : scheme.outlineVariant,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(id);
                              _selectedMap.remove(id);
                            } else {
                              _selectedIds.add(id);
                              _selectedMap[id] = s;
                            }
                          });
                        },
                        leading: InitialsAvatar(name: s['fullName'].toString(), size: 40),
                        title: Text(
                          s['fullName'].toString(),
                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
                        ),
                        subtitle: Text('${s['username']} • ${s['email']}'),
                        trailing: Checkbox(
                          value: isSelected,
                          activeColor: scheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (_) {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(id);
                                _selectedMap.remove(id);
                              } else {
                                _selectedIds.add(id);
                                _selectedMap[id] = s;
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selectedMap.values.toList()),
                icon: const Icon(Icons.group_add_rounded),
                label: Text(
                  _selectedIds.isEmpty
                      ? 'Chọn sinh viên để thêm'
                      : 'Thêm ${_selectedIds.length} sinh viên vào lớp',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
