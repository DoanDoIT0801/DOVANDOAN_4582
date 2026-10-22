import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leave_requests/views/my_leaves_screen.dart';
import '../../profile/views/profile_view.dart';
import 'student_class_view.dart';

// Khu vực sinh viên: thanh điều hướng dưới với 3 mục chính.
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _tab = 0;
  // Tăng phiên bản khi chọn tab để tab đó tạo lại và tải dữ liệu mới.
  final _versions = [0, 0, 0];

  static const _titles = ['Lớp học của tôi', 'Đơn xin nghỉ', 'Tài khoản'];

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
                color: scheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.secondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded, size: 16, color: scheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    'Sinh viên',
                    style: TextStyle(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(_titles[_tab]),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới danh sách',
            onPressed: () => setState(() => _versions[_tab]++),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          KeyedSubtree(key: ValueKey('classes-${_versions[0]}'), child: const _ClassesTab()),
          KeyedSubtree(key: ValueKey('leaves-${_versions[1]}'), child: const MyLeavesView()),
          const ProfileView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _versions[i]++;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Lớp học',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Đơn nghỉ',
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

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().fullName ?? '';
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AsyncListView(
      future: _future,
      onRefresh: _reload,
      emptyIcon: Icons.class_outlined,
      emptyTitle: 'Bạn chưa có lớp nào',
      emptyMessage: 'Khi quản trị viên thêm bạn vào lớp, lớp sẽ hiện ở đây.',
      headerBuilder: (items) => _WelcomeBanner(
        name: name,
        isDark: isDark,
        scheme: scheme,
        text: text,
        subtitle: items.isEmpty
            ? 'Hôm nay bạn chưa có lớp nào.'
            : 'Bạn đang học ${items.length} lớp. Chọn lớp để điểm danh.',
        icon: Icons.school_rounded,
        stats: items.isEmpty
            ? null
            : [_StatBadge(label: 'Lớp học', value: '${items.length}', icon: Icons.class_rounded)],
      ),
      itemBuilder: (context, c) => _ClassCard(
        classData: c,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentClassScreen(
              classId: c['id'] as int,
              className: c['name'].toString(),
            ),
          ),
        ),
      ),
    );
  }
}

// Banner chào hỏi chuyên nghiệp
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.name,
    required this.isDark,
    required this.scheme,
    required this.text,
    required this.subtitle,
    required this.icon,
    this.stats,
  });

  final String name;
  final bool isDark;
  final ColorScheme scheme;
  final TextTheme text;
  final String subtitle;
  final IconData icon;
  final List<Widget>? stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E3A8A), const Color(0xFF0369A1)]
              : [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
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
                      'Xin chào, $name 👋',
                      style: text.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ],
          ),
          if (stats != null) ...[
            const SizedBox(height: 16),
            Row(children: stats!),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, height: 1.1),
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

// Card lớp học đẹp cho sinh viên
class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.classData, required this.onTap});

  final Json classData;
  final VoidCallback onTap;

  // Màu sắc ngẫu nhiên nhưng nhất quán theo id
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
    final schedule = (classData['schedule']?.toString() ?? '');
    final room = (classData['room']?.toString() ?? '');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Subject initial circle
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
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classData['subject'].toString(),
                      style: text.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            classData['teacher'].toString(),
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (schedule.isNotEmpty || room.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 13, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                [if (schedule.isNotEmpty) schedule, if (room.isNotEmpty) room].join(' • '),
                                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
