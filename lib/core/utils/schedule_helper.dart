class ScheduledSessionPlan {
  const ScheduledSessionPlan({
    required this.index,
    required this.title,
    required this.startsAt,
    this.durationMinutes,
  });

  final int index;
  final String title;
  final DateTime startsAt;
  final int? durationMinutes;
}

class ScheduleDateHelper {
  static const daysOfWeek = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  static const dayMap = {
    'Thứ 2': DateTime.monday,
    'Thứ 3': DateTime.tuesday,
    'Thứ 4': DateTime.wednesday,
    'Thứ 5': DateTime.thursday,
    'Thứ 6': DateTime.friday,
    'Thứ 7': DateTime.saturday,
    'Chủ nhật': DateTime.sunday,
  };

  static List<ScheduledSessionPlan> generateSessionPlans({
    required String schedule,
    int? fallbackPlannedSessions,
  }) {
    final raw = schedule.trim();
    final fallbackCount = fallbackPlannedSessions != null && fallbackPlannedSessions > 0
        ? fallbackPlannedSessions
        : 15;

    if (raw.isEmpty) {
      return _generateFallback(fallbackCount);
    }

    // 1. Phân tích thứ
    final matchedDays = daysOfWeek.where((d) => raw.contains(d)).toList();
    final targetWeekdays = matchedDays.map((d) => dayMap[d]).whereType<int>().toSet();

    // 2. Phân tích giờ (HH:mm - HH:mm)
    int startHour = 7;
    int startMinute = 0;
    int? durationMinutes;
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(raw);
    if (timeMatch != null) {
      startHour = int.tryParse(timeMatch.group(1)!) ?? 7;
      startMinute = int.tryParse(timeMatch.group(2)!) ?? 0;
      final endH = int.tryParse(timeMatch.group(3)!) ?? 10;
      final endM = int.tryParse(timeMatch.group(4)!) ?? 30;
      final diff = (endH * 60 + endM) - (startHour * 60 + startMinute);
      durationMinutes = diff > 0 ? diff : 180;
    }

    // 3. Phân tích khoảng ngày (dd/MM/yyyy - dd/MM/yyyy)
    final dateMatch = RegExp(r'(\d{1,2}/\d{1,2}/\d{4})\s*-\s*(\d{1,2}/\d{1,2}/\d{4})').firstMatch(raw);
    DateTime? startDate;
    DateTime? endDate;
    if (dateMatch != null) {
      startDate = _parseDate(dateMatch.group(1)!);
      endDate = _parseDate(dateMatch.group(2)!);
    }

    if (startDate == null || endDate == null || targetWeekdays.isEmpty) {
      return _generateFallback(fallbackCount);
    }

    final plans = <ScheduledSessionPlan>[];
    DateTime cur = DateTime(startDate.year, startDate.month, startDate.day, startHour, startMinute);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    int index = 1;
    while (!cur.isAfter(end)) {
      if (targetWeekdays.contains(cur.weekday)) {
        final dStr = '${cur.day.toString().padLeft(2, '0')}/${cur.month.toString().padLeft(2, '0')}/${cur.year}';
        plans.add(ScheduledSessionPlan(
          index: index,
          title: 'Buổi $index ($dStr)',
          startsAt: cur,
          durationMinutes: durationMinutes,
        ));
        index++;
      }
      cur = cur.add(const Duration(days: 1));
    }

    if (plans.isEmpty) {
      return _generateFallback(fallbackCount);
    }
    return plans;
  }

  static DateTime? _parseDate(String str) {
    try {
      final parts = str.split('/');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  static List<ScheduledSessionPlan> _generateFallback(int count) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final cur = now.add(Duration(days: i * 7));
      final dStr = '${cur.day.toString().padLeft(2, '0')}/${cur.month.toString().padLeft(2, '0')}/${cur.year}';
      return ScheduledSessionPlan(
        index: i + 1,
        title: 'Buổi ${i + 1} ($dStr)',
        startsAt: DateTime(cur.year, cur.month, cur.day, 7, 0),
        durationMinutes: 180,
      );
    });
  }
}
