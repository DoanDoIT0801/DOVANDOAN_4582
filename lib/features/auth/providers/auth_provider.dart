import 'package:flutter/foundation.dart';

import '../../../core/storage/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._storage);

  final TokenStorage _storage;
  bool ready = false;
  String? role;
  String? fullName;

  bool get isLoggedIn => role != null;

  Future<void> restore() async {
    try {
      final token = await _storage.token;
      if (token != null) {
        role = await _storage.role;
        fullName = await _storage.fullName;
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
      try {
        await _storage.clear();
      } catch (_) {}
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> saveSession(Map<String, dynamic> data) async {
    final newRole = data['role'].toString();
    final name = data['fullName'].toString();
    await _storage.save(token: data['token'] as String, role: newRole, fullName: name);
    role = newRole;
    fullName = name;
    notifyListeners();
  }

  Future<bool> loginWithFace() async {
    final token = await _storage.faceToken;
    final faceRole = await _storage.faceRole;
    final name = await _storage.faceFullName;
    if (token != null && faceRole != null && name != null) {
      await _storage.save(token: token, role: faceRole, fullName: name);
      role = faceRole;
      fullName = name;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> hasFaceEnrolled() => _storage.isFaceLoginEnabled;

  Future<void> logout() async {
    await _storage.clear();
    role = null;
    fullName = null;
    notifyListeners();
  }
}
