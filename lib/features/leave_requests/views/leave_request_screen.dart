import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../shared/widgets/common_widgets.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key, required this.sessionId, required this.sessionTitle});

  final int sessionId;
  final String sessionTitle;

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String? _evidencePath;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (picked != null) setState(() => _evidencePath = picked.path);
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final api = context.read<ApiService>();
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await api.submitLeave(sessionId: widget.sessionId, reason: _reason.text.trim(), evidencePath: _evidencePath);
      if (!mounted) return;
      await showResultDialog(
        context,
        success: true,
        title: 'Đã gửi đơn',
        message: 'Đơn xin nghỉ đang chờ giảng viên duyệt. Bạn có thể theo dõi ở tab "Đơn nghỉ".',
      );
      navigator.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Xin nghỉ học')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(widget.sessionTitle),
                subtitle: const Text('Buổi học xin nghỉ'),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _reason,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Lý do xin nghỉ',
                helperText: 'Ví dụ: ốm, có giấy khám bệnh',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập lý do xin nghỉ' : null,
            ),
            const SizedBox(height: 16),
            Text('Minh chứng (không bắt buộc)', style: text.titleSmall),
            const SizedBox(height: 8),
            if (_evidencePath == null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickEvidence(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Chụp ảnh'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickEvidence(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Thư viện'),
                    ),
                  ),
                ],
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Image.file(File(_evidencePath!), height: 200, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Bỏ ảnh minh chứng',
                        onPressed: () => setState(() => _evidencePath = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Đơn được duyệt thì buổi này không bị tính là vắng.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Gửi đơn'),
          ),
        ),
      ),
    );
  }
}
