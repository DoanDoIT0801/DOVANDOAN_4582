import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/schedule_helper.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../classroom/views/class_members_view.dart';
import '../../classroom/widgets/class_form_dialog.dart';
import '../../profile/views/profile_view.dart';

// Trang quản trị: người dùng, môn học, lớp học và tài khoản.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;
  // Tăng phiên bản khi chọn tab để tab đó tạo lại và tải dữ liệu mới.
  final _versions = [0, 0, 0, 0];

  static const _titles = ['Người dùng', 'Môn học', 'Lớp học', 'Tài khoản'];

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
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: scheme.primary,
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
            tooltip: 'Làm mới dữ liệu',
            onPressed: () => setState(() => _versions[_tab]++),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          KeyedSubtree(key: ValueKey('users-${_versions[0]}'), child: const _UsersTab()),
          KeyedSubtree(key: ValueKey('subjects-${_versions[1]}'), child: const _SubjectsTab()),
          KeyedSubtree(key: ValueKey('classes-${_versions[2]}'), child: const _ClassesTab()),
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
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Người dùng',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Môn học',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Lớp học',
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

// Menu "Sửa / Xoá" trên mỗi thẻ.
class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      tooltip: 'Tuỳ chọn',
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Sửa'))),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: error), title: Text('Xoá', style: TextStyle(color: error))),
        ),
      ],
    );
  }
}

Future<void> _delete(BuildContext context, String what, Future<void> Function() action, VoidCallback onDone) async {
  final ok = await confirmAction(
    context,
    title: 'Xoá $what?',
    message: 'Thao tác này không thể hoàn tác.',
    confirmLabel: 'Xoá',
    destructive: true,
  );
  if (!ok) return;
  try {
    await action();
    if (context.mounted) showMessage(context, 'Đã xoá $what.');
    onDone();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

// ---------- Người dùng ----------

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Json>? _users;
  String? _error;
  String _query = '';
  String _role = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<ApiService>().users();
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<Json> get _filtered {
    final q = _query.trim().toLowerCase();
    return (_users ?? []).where((u) {
      if (_role != 'All' && u['role'] != _role) return false;
      if (q.isEmpty) return true;
      return '${u['fullName']} ${u['username']} ${u['email']}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openForm([Json? user]) async {
    final api = context.read<ApiService>();
    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserForm(user: user),
    );
    if (values == null || !mounted) return;
    try {
      if (user == null) {
        await api.createUser(
          username: values['username'],
          email: values['email'],
          password: values['password'],
          fullName: values['fullName'],
          role: values['role'],
        );
      } else {
        await api.updateUser(
          user['id'] as int,
          email: values['email'],
          fullName: values['fullName'],
          role: values['role'],
          isActive: values['isActive'],
        );
      }
      if (mounted) showMessage(context, user == null ? 'Đã thêm người dùng.' : 'Đã lưu thay đổi.');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget body;
    if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_users == null) {
      body = const SkeletonList();
    } else {
      final list = _filtered;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Tìm theo tên, tài khoản, email', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in const [('All', 'Tất cả'), ('SinhVien', 'Sinh viên'), ('GiangVien', 'Giảng viên'), ('Admin', 'Quản trị')])
                  ChoiceChip(
                    label: Text(label),
                    selected: _role == value,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _role = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${list.length} người dùng', style: text.titleMedium),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const EmptyState(icon: Icons.person_search_outlined, title: 'Không tìm thấy người dùng phù hợp')
            else
              for (final u in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TapCard(
                    onTap: () => _openForm(u),
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    child: Row(
                      children: [
                        InitialsAvatar(name: u['fullName'].toString()),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['fullName'].toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              Text('${u['username']} • ${u['email']}', style: text.bodySmall),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  StatusChip(
                                    label: roleLabel(u['role'].toString()),
                                    icon: u['role'] == 'Admin'
                                        ? Icons.admin_panel_settings_rounded
                                        : (u['role'] == 'GiangVien' ? Icons.badge_rounded : Icons.school_rounded),
                                    tone: u['role'] == 'GiangVien' ? StatusTone.warning : StatusTone.info,
                                  ),
                                  if (u['isActive'] != true)
                                    const StatusChip(label: 'Chưa kích hoạt', icon: Icons.block_rounded, tone: StatusTone.danger),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _ItemMenu(
                          onEdit: () => _openForm(u),
                          onDelete: () => _delete(
                            context,
                            'người dùng ${u['username']}',
                            () => context.read<ApiService>().deleteUser(u['id'] as int),
                            _load,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Thêm'),
      ),
    );
  }
}

class _UserForm extends StatefulWidget {
  const _UserForm({this.user});

  final Json? user;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.user?['fullName']?.toString() ?? '');
  late final _email = TextEditingController(text: widget.user?['email']?.toString() ?? '');
  final _username = TextEditingController();
  final _password = TextEditingController();
  late String _role = widget.user?['role']?.toString() ?? 'SinhVien';
  late bool _isActive = widget.user?['isActive'] != false;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    for (final c in [_fullName, _email, _username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {
      'fullName': _fullName.text.trim(),
      'email': _email.text.trim(),
      'username': _username.text.trim(),
      'password': _password.text,
      'role': _role,
      'isActive': _isActive,
    });
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Sửa người dùng' : 'Thêm người dùng', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email chưa đúng định dạng' : null,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Tên đăng nhập'), validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu', helperText: 'Tối thiểu 6 ký tự'),
                  validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu cần tối thiểu 6 ký tự' : null,
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'SinhVien', label: Text('Sinh viên')),
                  ButtonSegment(value: 'GiangVien', label: Text('Giảng viên')),
                  ButtonSegment(value: 'Admin', label: Text('Quản trị')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              if (_isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tài khoản đang hoạt động'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: Text(_isEdit ? 'Lưu thay đổi' : 'Thêm người dùng')),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Môn học ----------

// Form thêm / sửa môn học
class _SubjectForm extends StatefulWidget {
  const _SubjectForm({this.subject});

  final Json? subject;

  @override
  State<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<_SubjectForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.subject?['code']?.toString() ?? '');
  late final _name = TextEditingController(text: widget.subject?['name']?.toString() ?? '');

  bool get _isEdit => widget.subject != null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {
      'code': _code.text.trim().toUpperCase(),
      'name': _name.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit_note_rounded : Icons.bookmark_add_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEdit ? 'Sửa môn học' : 'Thêm môn học mới', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Nhập mã môn và tên môn học để đưa vào chương trình giảng dạy', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Mã môn học',
                  hintText: 'Ví dụ: CS101, IT4582',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập mã môn';
                  if (v.trim().length < 2) return 'Mã môn tối thiểu 2 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Tên môn học',
                  hintText: 'Ví dụ: Lập trình Di động',
                  prefixIcon: const Icon(Icons.menu_book_rounded),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên môn học';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                icon: Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded),
                label: Text(_isEdit ? 'Lưu thay đổi' : 'Thêm môn học'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectsTab extends StatefulWidget {
  const _SubjectsTab();

  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  List<Json>? _subjects;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<ApiService>().subjects();
      if (mounted) {
        setState(() {
          _subjects = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<Json> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _subjects ?? [];
    return (_subjects ?? []).where((s) {
      final code = (s['code'] ?? '').toString().toLowerCase();
      final name = (s['name'] ?? '').toString().toLowerCase();
      return code.contains(q) || name.contains(q);
    }).toList();
  }

  Future<void> _openForm([Json? subject]) async {
    final api = context.read<ApiService>();
    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SubjectForm(subject: subject),
    );
    if (values == null || !mounted) return;

    final code = values['code'] as String;
    final name = values['name'] as String;

    try {
      if (subject == null) {
        final created = await api.createSubject(code, name);
        if (mounted) {
          setState(() {
            _subjects = [...?_subjects, created];
          });
          showMessage(context, 'Đã thêm môn học $name.');
        }
      } else {
        final id = subject['id'] as int;
        final updated = await api.updateSubject(id, code, name);
        if (mounted) {
          setState(() {
            _subjects = _subjects?.map((s) => s['id'] == id ? updated : s).toList();
          });
          showMessage(context, 'Đã cập nhật môn học $name.');
        }
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteSubject(Json s) async {
    final id = s['id'] as int;
    final name = s['name'].toString();
    final ok = await confirmAction(
      context,
      title: 'Xoá môn học?',
      message: 'Bạn có chắc chắn muốn xoá môn học "$name"? Thao tác này không thể hoàn tác.',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !mounted) return;

    // Cập nhật UI ngay lập tức
    final previous = _subjects;
    setState(() {
      _subjects = _subjects?.where((item) => item['id'] != id).toList();
    });

    try {
      await context.read<ApiService>().deleteSubject(id);
      if (mounted) showMessage(context, 'Đã xoá môn học $name.');
      _load();
    } catch (e) {
      // Phục hồi lại dữ liệu nếu server từ chối xoá
      if (mounted) {
        setState(() => _subjects = previous);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget body;
    if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_subjects == null) {
      body = const SkeletonList();
    } else {
      final list = _filtered;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Tìm theo mã môn, tên môn học...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              EmptyState(
                icon: Icons.book_outlined,
                title: _query.isEmpty ? 'Chưa có môn học' : 'Không tìm thấy môn học',
                message: _query.isEmpty ? 'Bấm "Thêm môn học" để tạo môn học đầu tiên.' : 'Thử tìm với từ khoá khác.',
              )
            else
              for (final s in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TapCard(
                    onTap: () => _openForm(s),
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s['code'].toString(),
                            style: text.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            s['name'].toString(),
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        _ItemMenu(
                          onEdit: () => _openForm(s),
                          onDelete: () => _deleteSubject(s),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm môn học'),
      ),
      body: body,
    );
  }
}

// ---------- Lớp học ----------

class _ClassesTab extends StatefulWidget {
  const _ClassesTab();

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  List<Json>? _classes;
  String? _error;
  String _query = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<ApiService>().classes();
      if (mounted) {
        setState(() {
          _classes = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<Json> get _filtered {
    final q = _query.trim().toLowerCase();
    return (_classes ?? []).where((c) {
      final studentCount = (c['studentCount'] as int?) ?? 0;
      if (_filter == 'HasStudents' && studentCount == 0) return false;
      if (_filter == 'Empty' && studentCount > 0) return false;
      if (q.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      final subject = (c['subject'] ?? '').toString().toLowerCase();
      final teacher = (c['teacher'] ?? '').toString().toLowerCase();
      final room = (c['room'] ?? '').toString().toLowerCase();
      final schedule = (c['schedule'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          subject.contains(q) ||
          teacher.contains(q) ||
          room.contains(q) ||
          schedule.contains(q);
    }).toList();
  }

  Future<void> _openForm([Json? cls]) async {
    final api = context.read<ApiService>();
    final List<Json> subjects;
    final List<Json> teachers;
    try {
      subjects = await api.subjects();
      teachers = (await api.users()).where((u) => u['role'] == 'GiangVien').toList();
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (!mounted) return;
    if (subjects.isEmpty || teachers.isEmpty) {
      showMessage(context, 'Cần có ít nhất 1 môn học và 1 giảng viên trước khi tạo lớp.');
      return;
    }

    final data = await showClassForm(context, cls: cls, subjects: subjects, teachers: teachers);
    if (data == null || !mounted) return;
    try {
      if (cls == null) {
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
      } else {
        await api.updateClass(cls['id'] as int, data);
      }
      if (mounted) showMessage(context, cls == null ? 'Đã tạo lớp ${data['name']}.' : 'Đã lưu thay đổi.');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _openMembers(Json c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassMembersScreen(
          classId: c['id'] as int,
          className: c['name'].toString(),
          classInfo: c,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget body;
    if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_classes == null) {
      body = const SkeletonList();
    } else {
      final list = _filtered;
      final totalStudents = (_classes ?? []).fold<int>(0, (sum, c) => sum + ((c['studentCount'] as int?) ?? 0));

      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            // Ô tìm kiếm lớp học
            TextField(
              decoration: InputDecoration(
                hintText: 'Tìm theo tên lớp, môn học, giảng viên...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),

            // Bộ lọc lớp học
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in const [
                  ('All', 'Tất cả lớp'),
                  ('HasStudents', 'Có sinh viên'),
                  ('Empty', 'Chưa có SV'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == value,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = value),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Dòng thống kê số lượng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _query.isEmpty
                      ? '${list.length} lớp học • $totalStudents lượt SV'
                      : 'Kết quả: ${list.length} / ${_classes!.length} lớp',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (list.isEmpty)
              EmptyState(
                icon: Icons.class_outlined,
                title: _query.isEmpty ? 'Chưa có lớp học' : 'Không tìm thấy lớp học',
                message: _query.isEmpty
                    ? 'Bấm "Tạo lớp học" bên dưới để thiết lập lớp học mới cho học kỳ.'
                    : 'Không tìm thấy lớp nào khớp với từ khoá "$_query".',
                action: _query.isEmpty
                    ? FilledButton.icon(
                        onPressed: _openForm,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tạo lớp học'),
                      )
                    : null,
              )
            else
              for (final c in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TapCard(
                    onTap: () => _openMembers(c),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dòng tiêu đề thẻ: Badge môn học + Sĩ số + Menu
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 14, color: scheme.onSecondaryContainer),
                                  const SizedBox(width: 5),
                                  Text(
                                    c['subject'].toString(),
                                    style: TextStyle(
                                      color: scheme.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            StatusChip(
                              label: '${c['studentCount']} SV',
                              icon: Icons.groups_rounded,
                              tone: (c['studentCount'] as int? ?? 0) > 0 ? StatusTone.info : StatusTone.neutral,
                            ),
                            _ItemMenu(
                              onEdit: () => _openForm(c),
                              onDelete: () => _delete(
                                context,
                                'lớp ${c['name']}',
                                () => context.read<ApiService>().deleteClass(c['id'] as int),
                                _load,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Tên lớp học lớn, rõ ràng
                        Text(
                          c['name'].toString(),
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),

                        // Giảng viên phụ trách
                        Row(
                          children: [
                            Icon(Icons.person_pin_rounded, size: 16, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Giảng viên: ${c['teacher']}',
                              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Chips thông tin: Phòng & Lịch học
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (c['room'] != null && c['room'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.meeting_room_outlined, size: 13),
                                    const SizedBox(width: 4),
                                    Text('Phòng: ${c['room']}', style: const TextStyle(fontSize: 11.5)),
                                  ],
                                ),
                              ),
                            if (c['schedule'] != null && c['schedule'].toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 13),
                                    const SizedBox(width: 4),
                                    Text('${c['schedule']}', style: const TextStyle(fontSize: 11.5)),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_repeat_rounded, size: 13),
                                  const SizedBox(width: 4),
                                  Text('${c['plannedSessions'] ?? 15} buổi', style: const TextStyle(fontSize: 11.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Nút hành động trực quan
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _openMembers(c),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.people_alt_rounded, size: 18),
                            label: Text('Quản lý danh sách sinh viên (${c['studentCount']})'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo lớp học'),
      ),
      body: body,
    );
  }
}
