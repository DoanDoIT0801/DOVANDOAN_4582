import 'package:flutter/material.dart';

import '../../../core/network/api_service.dart';

// Bảng trượt tạo/sửa lớp học với thiết kế hiện đại, bố cục logic và trực quan.
// teachers = null khi giảng viên tự tạo/sửa lớp (hệ thống tự gán giảng viên đó).
Future<Json?> showClassForm(
  BuildContext context, {
  Json? cls,
  required List<Json> subjects,
  List<Json>? teachers,
}) {
  return showModalBottomSheet<Json>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClassForm(cls: cls, subjects: subjects, teachers: teachers),
  );
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({this.cls, required this.subjects, this.teachers});

  final Json? cls;
  final List<Json> subjects;
  final List<Json>? teachers;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.cls?['name']?.toString() ?? '');
  late final _room = TextEditingController(text: widget.cls?['room']?.toString() ?? '');
  late final _schedule = TextEditingController(text: widget.cls?['schedule']?.toString() ?? '');
  late final _planned = TextEditingController(text: (widget.cls?['plannedSessions'] ?? 15).toString());
  late int _subjectId = _pick(widget.subjects, widget.cls?['subjectId']);
  late int _teacherId = widget.teachers == null ? 0 : _pick(widget.teachers!, widget.cls?['teacherId']);

  static int _pick(List<Json> items, Object? current) =>
      items.any((i) => i['id'] == current) ? current as int : items.first['id'] as int;

  @override
  void initState() {
    super.initState();
    // Nếu tạo mới và tên đang trống, tự gợi ý tên lớp từ môn học đầu tiên
    if (widget.cls == null && _name.text.isEmpty && widget.subjects.isNotEmpty) {
      final s = widget.subjects.firstWhere((item) => item['id'] == _subjectId, orElse: () => widget.subjects.first);
      _name.text = '${s['name']} - Lớp mới';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _room, _schedule, _planned]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSubjectChanged(int? newId) {
    if (newId == null) return;
    setState(() {
      _subjectId = newId;
      // Gợi ý lại tên lớp nếu người dùng chưa sửa hoặc đang dùng tên mặc định
      final s = widget.subjects.firstWhere((item) => item['id'] == newId, orElse: () => widget.subjects.first);
      if (_name.text.isEmpty || _name.text.endsWith('- Lớp mới')) {
        _name.text = '${s['name']} - Lớp mới';
      }
    });
  }

  Future<void> _openSchedulePicker() async {
    final result = await showModalBottomSheet<_SchedulePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SchedulePickerSheet(initialSchedule: _schedule.text),
    );
    if (result != null && mounted) {
      setState(() {
        _schedule.text = result.schedule;
        if (result.sessionCount > 0) {
          _planned.text = result.sessionCount.toString();
        }
      });
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      'subjectId': _subjectId,
      'teacherId': _teacherId,
      'room': _room.text.trim(),
      'schedule': _schedule.text.trim(),
      'plannedSessions': int.parse(_planned.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isEdit = widget.cls != null;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
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
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_note_rounded : Icons.add_home_work_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Chỉnh sửa lớp học' : 'Tạo lớp học mới',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isEdit
                            ? 'Cập nhật môn học, giảng viên, phòng hoặc lịch học'
                            : 'Điền thông tin học phần và lịch trình để mở lớp',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
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

          const Divider(height: 1),

          // Form fields
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Học phần & Giảng viên
                    Text('1. Môn học & Giảng viên phụ trách', style: text.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<int>(
                      initialValue: _subjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Môn học *',
                        prefixIcon: Icon(Icons.menu_book_rounded),
                      ),
                      items: [
                        for (final s in widget.subjects)
                          DropdownMenuItem(
                            value: s['id'] as int,
                            child: Text('[${s['code']}] ${s['name']}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _onSubjectChanged,
                    ),

                    if (widget.teachers != null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _teacherId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Giảng viên giảng dạy *',
                          prefixIcon: Icon(Icons.person_pin_rounded),
                        ),
                        items: [
                          for (final t in widget.teachers!)
                            DropdownMenuItem(
                              value: t['id'] as int,
                              child: Text('${t['fullName']} (${t['username']})', overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() => _teacherId = v ?? _teacherId),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Section 2: Thông tin lớp & Địa điểm
                    Text('2. Chi tiết lớp học & Lịch trình', style: text.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Tên lớp học *',
                        hintText: 'Ví dụ: Lập trình Di động - 23DTHC4',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên lớp học' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _room,
                            decoration: const InputDecoration(
                              labelText: 'Phòng học',
                              hintText: 'Ví dụ: A.301',
                              prefixIcon: Icon(Icons.meeting_room_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: TextFormField(
                            controller: _planned,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số buổi dự kiến',
                              hintText: '15',
                              prefixIcon: Icon(Icons.event_repeat_outlined),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '');
                              return (n == null || n < 1 || n > 100) ? '1 - 100' : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Thời khoá biểu tương tác: Chọn giờ dạy & ngày dạy
                    TextFormField(
                      controller: _schedule,
                      readOnly: true,
                      onTap: _openSchedulePicker,
                      decoration: InputDecoration(
                        labelText: 'Thời khoá biểu / Lịch học *',
                        hintText: 'Chạm để chọn thứ, giờ dạy và khoảng ngày...',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_schedule.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                tooltip: 'Xoá lịch',
                                onPressed: () => setState(() => _schedule.clear()),
                              ),
                            IconButton(
                              icon: Icon(Icons.edit_calendar_rounded, color: scheme.primary),
                              tooltip: 'Chọn thời khoá biểu',
                              onPressed: _openSchedulePicker,
                            ),
                          ],
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng chọn thời khoá biểu' : null,
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: Icon(isEdit ? Icons.save_rounded : Icons.check_circle_rounded),
                        label: Text(
                          isEdit ? 'Lưu thay đổi' : 'Tạo lớp học',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulePickerResult {
  const _SchedulePickerResult({
    required this.schedule,
    required this.sessionCount,
  });

  final String schedule;
  final int sessionCount;
}

// Bảng chọn Thời khoá biểu chi tiết: Thứ, Giờ bắt đầu/kết thúc, Ngày bắt đầu/kết thúc
class _SchedulePickerSheet extends StatefulWidget {
  const _SchedulePickerSheet({this.initialSchedule});

  final String? initialSchedule;

  @override
  State<_SchedulePickerSheet> createState() => _SchedulePickerSheetState();
}

class _SchedulePickerSheetState extends State<_SchedulePickerSheet> {
  static const _daysOfWeek = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  final Set<String> _selectedDays = {'Thứ 2'};
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));

  @override
  void initState() {
    super.initState();
    _parseInitial();
  }

  void _parseInitial() {
    final raw = widget.initialSchedule?.trim() ?? '';
    if (raw.isEmpty) return;

    // Phân tích thứ
    final days = _daysOfWeek.where((d) => raw.contains(d)).toSet();
    if (days.isNotEmpty) {
      _selectedDays.clear();
      _selectedDays.addAll(days);
    }

    // Phân tích giờ (HH:mm - HH:mm)
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(raw);
    if (timeMatch != null) {
      final sh = int.tryParse(timeMatch.group(1)!);
      final sm = int.tryParse(timeMatch.group(2)!);
      final eh = int.tryParse(timeMatch.group(3)!);
      final em = int.tryParse(timeMatch.group(4)!);
      if (sh != null && sm != null && eh != null && em != null) {
        _startTime = TimeOfDay(hour: sh, minute: sm);
        _endTime = TimeOfDay(hour: eh, minute: em);
      }
    }

    // Phân tích ngày (dd/MM/yyyy - dd/MM/yyyy)
    final dateMatch = RegExp(r'(\d{1,2}/\d{1,2}/\d{4})\s*-\s*(\d{1,2}/\d{1,2}/\d{4})').firstMatch(raw);
    if (dateMatch != null) {
      final sd = _tryParseDate(dateMatch.group(1)!);
      final ed = _tryParseDate(dateMatch.group(2)!);
      if (sd != null && ed != null) {
        _startDate = sd;
        _endDate = ed;
      }
    }
  }

  static DateTime? _tryParseDate(String str) {
    try {
      final parts = str.split('/');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _generatedSchedule {
    final daysStr = _selectedDays.isEmpty ? 'Chưa chọn thứ' : _selectedDays.join(', ');
    final timeStr = '${_formatTime(_startTime)} - ${_formatTime(_endTime)}';
    final dateStr = '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
    return '$daysStr ($timeStr) • $dateStr';
  }

  int get _calculatedSessionCount {
    if (_selectedDays.isEmpty) return 0;
    const dayMap = {
      'Thứ 2': DateTime.monday,
      'Thứ 3': DateTime.tuesday,
      'Thứ 4': DateTime.wednesday,
      'Thứ 5': DateTime.thursday,
      'Thứ 6': DateTime.friday,
      'Thứ 7': DateTime.saturday,
      'Chủ nhật': DateTime.sunday,
    };
    final targetWeekdays = _selectedDays.map((d) => dayMap[d]).whereType<int>().toSet();
    if (targetWeekdays.isEmpty) return 0;

    DateTime cur = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    if (cur.isAfter(end)) return 0;

    int count = 0;
    while (!cur.isAfter(end)) {
      if (targetWeekdays.contains(cur.weekday)) {
        count++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'CHỌN GIỜ BẮT ĐẦU DẠY',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'CHỌN GIỜ KẾT THÚC DẠY',
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'CHỌN NGÀY BẮT ĐẦU KHOÁ HỌC',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 90));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2035),
      helpText: 'CHỌN NGÀY KẾT THÚC KHOÁ HỌC',
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'CHỌN KHOẢNG THỜI GIAN HỌC KỲ',
      saveText: 'CHỌN',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _applyQuickShift(int startH, int startM, int endH, int endM) {
    setState(() {
      _startTime = TimeOfDay(hour: startH, minute: startM);
      _endTime = TimeOfDay(hour: endH, minute: endM);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
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
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_calendar_rounded, color: scheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chọn Thời khoá biểu', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Chọn thứ dạy, khung giờ và khoảng thời gian đào tạo', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
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

          const Divider(height: 1),

          // Nội dung lựa chọn
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thứ trong tuần
                  Row(
                    children: [
                      Icon(Icons.view_week_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('1. Thứ trong tuần', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final day in _daysOfWeek)
                        FilterChip(
                          label: Text(day),
                          selected: _selectedDays.contains(day),
                          showCheckmark: false,
                          selectedColor: scheme.primary,
                          labelStyle: TextStyle(
                            color: _selectedDays.contains(day) ? Colors.white : scheme.onSurfaceVariant,
                            fontWeight: _selectedDays.contains(day) ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(
                            color: _selectedDays.contains(day) ? scheme.primary : scheme.outlineVariant,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(day);
                              } else {
                                if (_selectedDays.length > 1) {
                                  _selectedDays.remove(day);
                                }
                              }
                            });
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 2. Dạy từ mấy giờ tới mấy giờ
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('2. Giờ học (Từ mấy giờ tới mấy giờ)', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Từ giờ', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 20, color: scheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(_startTime),
                                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Đến giờ', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_filled_rounded, size: 20, color: scheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(_endTime),
                                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Text('Gợi ý ca học chuẩn:', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Tiết 1-4 (07:00 - 10:30)'),
                        avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                        onPressed: () => _applyQuickShift(7, 0, 10, 30),
                      ),
                      ActionChip(
                        label: const Text('Tiết 4-6 (09:30 - 12:00)'),
                        avatar: const Icon(Icons.wb_sunny_rounded, size: 16),
                        onPressed: () => _applyQuickShift(9, 30, 12, 0),
                      ),
                      ActionChip(
                        label: const Text('Tiết 7-9 (12:30 - 15:00)'),
                        avatar: const Icon(Icons.brightness_5_rounded, size: 16),
                        onPressed: () => _applyQuickShift(12, 30, 15, 0),
                      ),
                      ActionChip(
                        label: const Text('Tiết 10-12 (15:00 - 17:30)'),
                        avatar: const Icon(Icons.brightness_6_rounded, size: 16),
                        onPressed: () => _applyQuickShift(15, 0, 17, 30),
                      ),
                      ActionChip(
                        label: const Text('Ca Tối (18:00 - 20:30)'),
                        avatar: const Icon(Icons.nights_stay_rounded, size: 16),
                        onPressed: () => _applyQuickShift(18, 0, 20, 30),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // 3. Từ ngày nào tới ngày nào
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.date_range_rounded, size: 18, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '3. Khoảng ngày áp dụng',
                                style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.calendar_today_rounded, size: 15),
                        label: const Text('Chọn dải ngày', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Từ ngày', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.event_available_rounded, size: 20, color: scheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(_startDate),
                                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickEndDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Đến ngày', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.event_busy_rounded, size: 20, color: scheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(_endDate),
                                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Hộp xem trước kết quả
                  Text('Xem trước kết quả lịch học:', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: scheme.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _generatedSchedule,
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Chuỗi thời khoá biểu này sẽ được lưu và hiển thị cho cả giảng viên và sinh viên',
                                    style: text.bodySmall?.copyWith(fontSize: 11.5, color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Icon(Icons.calculate_outlined, size: 16, color: scheme.primary),
                              Text(
                                'Tự động tính: $_calculatedSessionCount buổi học',
                                style: text.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                              Text(
                                '(tự điền vào Số buổi)',
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _SchedulePickerResult(
                    schedule: _generatedSchedule,
                    sessionCount: _calculatedSessionCount,
                  ),
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  _calculatedSessionCount > 0
                      ? 'Áp dụng ($_calculatedSessionCount buổi học)'
                      : 'Áp dụng thời khoá biểu',
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
