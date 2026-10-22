import 'package:flutter/material.dart';

import '../../../core/network/api_service.dart';
import '../../../core/theme/app_theme.dart';

// Thẻ thông tin lớp: môn học, giảng viên, phòng, lịch học, sĩ số, số buổi.
class ClassInfoCard extends StatelessWidget {
  const ClassInfoCard({super.key, required this.detail, this.onEdit});

  final Json detail;
  final VoidCallback? onEdit;

  Color _subjectColor(int id) {
    const colors = [
      AppTheme.primaryColor,
      AppTheme.tertiaryColor,
      Color(0xFF0D9488), // Teal
      Color(0xFFD97706), // Amber
      AppTheme.secondaryColor,
      Color(0xFFE11D48), // Rose
      Color(0xFF7C3AED), // Violet
    ];
    return colors[id % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final room = detail['room']?.toString();
    final schedule = detail['schedule']?.toString();
    final id = (detail['id'] as int?) ?? 0;
    final color = _subjectColor(id);
    final subjectName = detail['subject'].toString();
    final initial = subjectName.isNotEmpty ? subjectName[0].toUpperCase() : 'C';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Colored header bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.75)],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
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
                        detail['subject'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mã môn: ${detail['subjectCode']}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Sửa thông tin lớp',
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: onEdit,
                  ),
              ],
            ),
          ),
          // Info rows
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Giảng viên',
                  value: detail['teacher'].toString(),
                  color: color,
                  scheme: scheme,
                  text: text,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.meeting_room_outlined,
                  label: 'Phòng học',
                  value: (room == null || room.isEmpty) ? 'Chưa cập nhật' : room,
                  color: color,
                  scheme: scheme,
                  text: text,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Lịch học',
                  value: (schedule == null || schedule.isEmpty) ? 'Chưa cập nhật' : schedule,
                  color: color,
                  scheme: scheme,
                  text: text,
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.groups_outlined,
                  label: 'Sĩ số / Buổi học',
                  value: '${detail['studentCount']} sinh viên  •  ${detail['sessionCount']}/${detail['plannedSessions']} buổi',
                  color: color,
                  scheme: scheme,
                  text: text,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.scheme,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Ô số liệu nhỏ: con số lớn + nhãn.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, required this.icon, this.color});

  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, color: c, fontSize: 22),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
