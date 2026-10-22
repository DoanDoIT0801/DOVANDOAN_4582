import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final _storage = const FlutterSecureStorage();

  Future<String?> get token => _storage.read(key: 'token');
  Future<String?> get role => _storage.read(key: 'role');
  Future<String?> get fullName => _storage.read(key: 'fullName');

  Future<void> save({required String token, required String role, required String fullName}) async {
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'role', value: role);
    await _storage.write(key: 'fullName', value: fullName);
  }

  Future<void> clear() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'role');
    await _storage.delete(key: 'fullName');
  }

  // ── Quản lý đăng nhập bằng khuôn mặt ──
  Future<bool> get isFaceLoginEnabled async => (await _storage.read(key: 'face_enabled')) == 'true';
  Future<String?> get faceUsername => _storage.read(key: 'face_username');
  Future<String?> get faceFullName => _storage.read(key: 'face_fullName');
  Future<String?> get faceRole => _storage.read(key: 'face_role');
  Future<String?> get faceToken => _storage.read(key: 'face_token');
  Future<String?> get faceImagePath => _storage.read(key: 'face_image_path');

  Future<void> saveFaceAccount({
    required String username,
    required String token,
    required String role,
    required String fullName,
    String? imagePath,
  }) async {
    await _storage.write(key: 'face_enabled', value: 'true');
    await _storage.write(key: 'face_username', value: username);
    await _storage.write(key: 'face_token', value: token);
    await _storage.write(key: 'face_role', value: role);
    await _storage.write(key: 'face_fullName', value: fullName);
    if (imagePath != null) {
      await _storage.write(key: 'face_image_path', value: imagePath);
    }
  }

  Future<void> disableFaceLogin() async {
    await _storage.delete(key: 'face_enabled');
    await _storage.delete(key: 'face_username');
    await _storage.delete(key: 'face_token');
    await _storage.delete(key: 'face_role');
    await _storage.delete(key: 'face_fullName');
    await _storage.delete(key: 'face_image_path');
  }
}
