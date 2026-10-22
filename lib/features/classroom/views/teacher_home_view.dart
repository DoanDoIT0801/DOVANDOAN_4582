import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/schedule_helper.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/views/profile_view.dart';
import '../widgets/class_form_dialog.dart';
import 'teacher_class_view.dart';

// Dashboard giảng viên: danh sách lớp dạy và tài khoản.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _tab = 0;
  // Tăng phiên bản khi chọn tab lớp để tải lại danh sách lớp.
  int _classesVersion = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.tertiary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_rounded, size: 16, color: scheme.tertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Giảng viên',
                    style: TextStyle(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(_tab == 0 ? 'Lớp đang dạy' : 'Tài khoản'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới danh sách',
            onPressed: () => setState(() => _classesVersion++),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          KeyedSubtree(key: ValueKey('classes-$_classesVersion'), child: const _ClassesTab()),
          const ProfileView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          if (i == 0) _classesVersion++;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.co_present_outlined),
            selectedIcon: Icon(Icons.co_present_rounded),
            label: 'Lớp dạy',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

class _ClassesTab extends StatefulWidget {
  const _ClassesTab();

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  late Future<List<Json>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().classes();
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<ApiService>().classes();
    });
    try {
      await _future;
    } catch (_) {}
  }

  // Giảng viên tự tạo lớp; server tự gán giảng viên là người tạo.
  Future<void> _createClass() async {
    final api = context.read<ApiService>();
    final List<Json> subjects;
    try {
      subjects = await api.subjects();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    if (subjects.isEmpty) {
      showMessage(context, 'Chưa có môn học nào. Hãy nhờ quản trị viên tạo môn học trước.');
      return;
    }
    final data = await showClassForm(context, subjects: subjects);
    if (data == null || !mounted) return;
    try {
      final newCls = await api.createClass(data);
      final newClassId = newCls['id'] as int?;
      final scheduleStr = data['schedule']?.toString() ?? '';
      if (newClassId != null && scheduleStr.isNotEmpty) {
        final plans = ScheduleDateHelper.generateSessionPlans(
          schedule: scheduleStr,
          fallbackPlannedSessions: data['plannedSessions'] as int?,
        );
        for (final p in plans) {
          try {
            await api.createSession(
              newClassId,
              title: p.title,
              startsAt: p.startsAt,
              durationMinutes: p.durationMinutes,
            );
          } catch (_) {}
        }
      }
      if (mounted) showMessage(context, 'Đã tạo lớp ${data['name']}.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().fullName ?? '';
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClass,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo lớp mới'),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      body: AsyncListView(
        future: _future,
        onRefresh: _reload,
        bottomPadding: 96,
        emptyIcon: Icons.co_present_outlined,
        emptyTitle: 'Bạn chưa có lớp nào',
        emptyMessage: "Bấm 'Tạo lớp mới' để tạo lớp học đầu tiên, sau đó thêm sinh viên vào lớp.",
        headerBuilder: (items) {
          final totalStudents = items.fold<int>(0, (sum, c) => sum + ((c['studentCount'] as int?) ?? 0));
          return _TeacherBanner(
            name: name,
            isDark: isDark,
            text: text,
            classCount: items.length,
            studentCount: totalStudents,
          );
        },
        itemBuilder: (context, c) {
          final room = c['room']?.toString() ?? '';
          final schedule = c['schedule']?.toString() ?? '';
          return _TeacherClassCard(
            classData: c,
            room: room,
            schedule: schedule,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherClassScreen(
                    classId: c['id'] as int,
                    className: c['name'].toString(),
                  ),
                ),
              );
              _reload();
            },
          );
        },
      ),
    );
  }
}

class _TeacherBanner extends StatelessWidget {
  const _TeacherBanner({
    required this.name,
    required this.isDark,
    required this.text,
    required this.classCount,
    required this.studentCount,
  });

  final String name;
  final bool isDark;
  final TextTheme text;
  final int classCount;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E3A8A), const Color(0xFF312E81)]
              : [AppTheme.primaryColor, AppTheme.tertiaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chào thầy/cô $name 👋',
                      style: text.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classCount == 0
                          ? 'Hãy tạo lớp đầu tiên của bạn!'
                          : 'Đang phụ trách $classCount lớp. Chọn lớp để mở buổi học.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.co_present_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          if (classCount > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _QuickStat(
                  value: '$classCount',
                  label: 'Lớp học',
                  icon: Icons.class_rounded,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  value: '$studentCount',
                  label: 'Sinh viên',
                  icon: Icons.groups_rounded,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherClassCard extends StatelessWidget {
  const _TeacherClassCard({
    required this.classData,
    required this.room,
    required this.schedule,
    required this.onTap,
  });

  final Json classData;
  final String room;
  final String schedule;
  final VoidCallback onTap;

  Color _colorFor(int id) {
    const colors = [
      AppTheme.primaryColor,
      AppTheme.tertiaryColor,
      Color(0xFF0D9488), // Teal
      Color(0xFFD97706), // Amber
      AppTheme.secondaryColor,
      Color(0xFFE11D48), // Rose
      Color(0xFF7C3AED), // Violet
    ];
    return colors[id.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final id = classData['id'] as int;
    final color = _colorFor(id);
    final studentCount = (classData['studentCount'] as int?) ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    classData['subject'].toString().isNotEmpty
                        ? classData['subject'].toString()[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classData['name'].toString(),
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      classData['subject'].toString(),
                      style: text.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.groups_rounded,
                          label: '$studentCount SV',
                          color: scheme.onSurfaceVariant,
                        ),
                        if (schedule.isNotEmpty)
                          _InfoChip(
                            icon: Icons.calendar_month_outlined,
                            label: schedule,
                            color: scheme.onSurfaceVariant,
                            maxChars: 15,
                          ),
                        if (room.isNotEmpty)
                          _InfoChip(
                            icon: Icons.meeting_room_outlined,
                            label: room,
                            color: scheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.color, this.maxChars = 30});

  final IconData icon;
  final String label;
  final Color color;
  final int maxChars;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.length > maxChars ? '${label.substring(0, maxChars)}…' : label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          displayLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          maxLines: 1,
        ),
      ],
    );
  }
}
