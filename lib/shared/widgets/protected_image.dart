import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/storage/token_storage.dart';

// Mở ảnh minh chứng từ API. Endpoint yêu cầu đăng nhập nên phải gửi kèm JWT.
Future<void> showProtectedImage(BuildContext context, String path) async {
  final token = await TokenStorage().token;
  if (!context.mounted) return;
  final base = Config_URL.baseUrl.replaceFirst(RegExp(r'/$'), '');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.network(
            '$base$path',
            headers: {'Authorization': 'Bearer $token'},
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Không mở được ảnh.'),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Đóng')),
        ],
      ),
    ),
  );
}
