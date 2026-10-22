import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../exceptions/api_exception.dart';
import '../storage/token_storage.dart';

typedef Json = Map<String, dynamic>;

class ApiService {
  ApiService(this._storage)
      : _dio = Dio(BaseOptions(
          baseUrl: Config_URL.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _storage.token;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  final TokenStorage _storage;
  final Dio _dio;

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      throw ApiException(_messageOf(e));
    }
  }

  List<Json> _list(dynamic data) => (data as List).cast<Json>();

  Json _map(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  String _messageOf(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      final errors = data['errors'];
      if (errors is Map && errors.values.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['title'] != null) return data['title'].toString();
    }
    switch (e.response?.statusCode) {
      case 401:
        return 'Sai thông tin đăng nhập hoặc phiên đã hết hạn.';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu.';
    }
    return 'Không kết nối được máy chủ.';
  }

  // Xác thực
  Future<Json> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    return _map(await _send(() => _dio.post('/api/auth/register', data: {
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': role,
        })));
  }

  Future<Json> verifyRegister(String username, String code) async {
    return _map(await _send(() => _dio.post('/api/auth/register/verify', data: {'username': username, 'code': code})));
  }

  Future<Json> login(String username, String password) async {
    return _map(await _send(() => _dio.post('/api/auth/login', data: {'username': username, 'password': password})));
  }

  Future<Json> verifyLogin(String username, String code) async {
    return _map(await _send(() => _dio.post('/api/auth/login/verify', data: {'username': username, 'code': code})));
  }

  // account: tên đăng nhập hoặc email.
  Future<Json> forgotPassword(String account) async {
    return _map(await _send(() => _dio.post('/api/auth/forgot-password', data: {'account': account})));
  }

  Future<Json> resetPassword({required String account, required String code, required String newPassword}) async {
    return _map(await _send(() => _dio.post('/api/auth/reset-password', data: {
          'account': account,
          'code': code,
          'newPassword': newPassword,
        })));
  }

  // Lớp và buổi học
  Future<List<Json>> classes() async => _list(await _send(() => _dio.get('/api/classes')));

  // Chi tiết lớp; sinh viên nhận thêm myStats (có mặt, vắng, có phép, còn được nghỉ).
  Future<Json> classDetail(int classId) async => _map(await _send(() => _dio.get('/api/classes/$classId')));

  Future<List<Json>> sessions(int classId) async {
    final list = _list(await _send(() => _dio.get('/api/classes/$classId/sessions')));
    for (final s in list) {
      debugPrint('SERVER SESSION RAW: $s');
    }
    return list;
  }

  // durationMinutes: thời gian mở điểm danh; null = mở đến khi giảng viên đóng.
  Future<Json> createSession(int classId, {
    required String title,
    DateTime? startsAt,
    double latitude = 0,
    double longitude = 0,
    double radiusMeters = 50,
    int? durationMinutes,
  }) async {
    return _map(await _send(() => _dio.post('/api/classes/$classId/sessions', data: {
          'title': title,
          'startsAt': (startsAt ?? DateTime.now()).toUtc().toIso8601String(),
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
          'durationMinutes': durationMinutes,
        })));
  }

  Future<void> closeSession(int sessionId) async {
    await _send(() => _dio.post('/api/sessions/$sessionId/close'));
  }

  Future<Json> openSession({
    required int sessionId,
    double latitude = 0,
    double longitude = 0,
    double radiusMeters = 50,
    int? durationMinutes,
  }) async {
    final r = radiusMeters > 0 ? radiusMeters : 50.0;
    final res = await _send(() => _dio.post('/api/sessions/$sessionId/open', data: {
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': r,
          'durationMinutes': ?durationMinutes,
        }));
    return _map(res);
  }

  Future<Json> updateSession({
    required int sessionId,
    required String title,
    required DateTime startsAt,
    double latitude = 0,
    double longitude = 0,
    double radiusMeters = 50000000,
    int? durationMinutes,
  }) async {
    return _map(await _send(() => _dio.put('/api/sessions/$sessionId', data: {
          'title': title,
          'startsAt': startsAt.toUtc().toIso8601String(),
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters > 0 ? radiusMeters : 50000000.0,
          if (durationMinutes != null && durationMinutes > 0) 'durationMinutes': durationMinutes,
        })));
  }

  Future<Json> reopenSession(int sessionId, int minutes) async {
    return _map(await _send(() => _dio.post('/api/sessions/$sessionId/reopen', data: {'minutes': minutes})));
  }

  // Cả lớp trong một buổi với trạng thái Present / Excused / PendingLeave / Absent.
  Future<List<Json>> roster(int sessionId) async =>
      _list(await _send(() => _dio.get('/api/sessions/$sessionId/roster')));

  Future<void> manualCheckIn(int sessionId, int studentId) async {
    await _send(() => _dio.post('/api/sessions/$sessionId/manual-checkin', data: {'studentId': studentId}));
  }

  Future<void> removeAttendance(int sessionId, int studentId) async {
    await _send(() => _dio.delete('/api/sessions/$sessionId/attendances/$studentId'));
  }

  // Sinh viên chưa có trong lớp, dùng khi thêm sinh viên.
  Future<List<Json>> classCandidates(int classId, {String query = ''}) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/candidates', queryParameters: {'q': query})));

  Future<List<Json>> attendances(int sessionId) async =>
      _list(await _send(() => _dio.get('/api/sessions/$sessionId/attendances')));

  Future<Json> checkIn({
    required int sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
    String? photoPath,
  }) async {
    final form = FormData.fromMap({
      'qrToken': qrToken,
      'latitude': latitude,
      'longitude': longitude,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath, filename: photoPath.split(RegExp(r'[\\/]')).last),
    });
    return _map(await _send(() => _dio.post('/api/sessions/$sessionId/check-in', data: form)));
  }

  // Đơn xin nghỉ
  Future<void> submitLeave({required int sessionId, required String reason, String? evidencePath}) async {
    final form = FormData.fromMap({
      'sessionId': sessionId,
      'reason': reason,
      if (evidencePath != null) 'evidence': await MultipartFile.fromFile(evidencePath, filename: evidencePath.split(RegExp(r'[\\/]')).last),
    });
    await _send(() => _dio.post('/api/leave-requests', data: form));
  }

  Future<List<Json>> myLeaves() async => _list(await _send(() => _dio.get('/api/leave-requests/mine')));

  Future<List<Json>> classLeaves(int classId) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/leave-requests')));

  Future<void> reviewLeave(int id, {required bool approve}) async {
    await _send(() => _dio.put('/api/leave-requests/$id/review', data: {'approve': approve}));
  }

  Future<List<Json>> absenceReport(int classId) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/absence-report')));

  Future<Json> sendWarnings(int classId) async =>
      _map(await _send(() => _dio.post('/api/classes/$classId/send-warnings')));

  // Sinh viên trong lớp
  Future<List<Json>> classStudents(int classId) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/students')));

  Future<void> enroll(int classId, int studentId) async {
    await _send(() => _dio.post('/api/classes/$classId/students', data: {'studentId': studentId}));
  }

  Future<void> unenroll(int classId, int studentId) async {
    await _send(() => _dio.delete('/api/classes/$classId/students/$studentId'));
  }

  // Quản trị
  Future<List<Json>> users() async => _list(await _send(() => _dio.get('/api/users')));

  Future<void> createUser({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    await _send(() => _dio.post('/api/users', data: {
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': role,
        }));
  }

  Future<void> deleteUser(int id) async {
    await _send(() => _dio.delete('/api/users/$id'));
  }

  Future<List<Json>> subjects() async => _list(await _send(() => _dio.get('/api/subjects')));

  Future<Json> createSubject(String code, String name) async {
    return _map(await _send(() => _dio.post('/api/subjects', data: {'code': code, 'name': name})));
  }

  Future<void> deleteSubject(int id) async {
    await _send(() => _dio.delete('/api/subjects/$id'));
  }

  // data: name, subjectId, teacherId, room, schedule, plannedSessions.
  // Khi giảng viên tạo/sửa lớp, server luôn gán chính giảng viên đó (bỏ qua teacherId).
  Future<Json> createClass(Json data) async {
    return _map(await _send(() => _dio.post('/api/classes', data: data)));
  }

  Future<void> deleteClass(int id) async {
    await _send(() => _dio.delete('/api/classes/$id'));
  }

  Future<void> updateUser(int id, {
    required String email,
    required String fullName,
    required String role,
    required bool isActive,
  }) async {
    await _send(() => _dio.put('/api/users/$id', data: {
          'email': email,
          'fullName': fullName,
          'role': role,
          'isActive': isActive,
        }));
  }

  Future<Json> updateSubject(int id, String code, String name) async {
    return _map(await _send(() => _dio.put('/api/subjects/$id', data: {'code': code, 'name': name})));
  }

  Future<void> updateClass(int id, Json data) async {
    await _send(() => _dio.put('/api/classes/$id', data: data));
  }
}
