import 'dart:convert';
import 'dart:math';

/// Helper quản lý mã điểm danh 4 chữ số và mã hoá/giải mã token buổi học.
class AttendanceCodeHelper {
  /// Lọc bỏ payload mã bí mật khỏi tiêu đề buổi học để hiển thị cho người dùng.
  /// Ví dụ: "Buổi 1 (24/10/2026) [PIN:...]" -> "Buổi 1 (24/10/2026)"
  static String cleanTitle(dynamic title) {
    if (title == null) return '';
    return title.toString().replaceAll(RegExp(r'\s*\[PIN:[^\]]+\]'), '').trim();
  }

  /// Trích xuất payload mã bí mật từ tiêu đề buổi học (nếu có).
  static String? extractPayload(dynamic title) {
    if (title == null) return null;
    final match = RegExp(r'\[PIN:([^\]]+)\]').firstMatch(title.toString());
    return match?.group(1);
  }

  static List<int>? _safeBase64Decode(String str) {
    String clean = str.trim();
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    try {
      return base64Url.decode(clean);
    } catch (_) {
      try {
        return base64.decode(clean);
      } catch (_) {
        return null;
      }
    }
  }

  /// Trích xuất mã PIN từ tiêu đề nếu có
  static String? extractPin(dynamic title) {
    final payload = extractPayload(title);
    if (payload == null) return null;
    final bytes = _safeBase64Decode(payload);
    if (bytes != null) {
      try {
        final dec = utf8.decode(bytes);
        final idx = dec.indexOf(':');
        if (idx > 0) return dec.substring(0, idx);
      } catch (_) {}
    }
    return null;
  }

  /// Sinh ngẫu nhiên một mã 4 chữ số từ 1000 đến 9999.
  static String generateRandomPin() {
    final rand = Random();
    return (1000 + rand.nextInt(9000)).toString();
  }

  /// Mã hoá qrToken cùng với PIN bí mật và toạ độ (nếu có) thành chuỗi Base64Url an toàn.
  static String createPayload(String qrToken, String pin, {double? lat, double? lon}) {
    final raw = (lat != null && lon != null)
        ? '$pin:$qrToken:$lat:$lon'
        : '$pin:$qrToken';
    return base64Url.encode(utf8.encode(raw));
  }

  /// Trích xuất chi tiết token và toạ độ từ payload khi sinh viên nhập đúng PIN.
  static ({String? token, double? lat, double? lon}) resolveDetailsWithPin(String payload, String pin) {
    final trimmedPin = pin.trim();
    // 1. Thử định dạng Base64(pin:qrToken hoặc pin:qrToken:lat:lon)
    final bytes = _safeBase64Decode(payload);
    if (bytes != null) {
      try {
        final dec = utf8.decode(bytes);
        final parts = dec.split(':');
        if (parts.length >= 2) {
          final expectedPin = parts[0].trim();
          if (expectedPin == trimmedPin) {
            final token = parts[1].trim();
            double? lat;
            double? lon;
            if (parts.length >= 4) {
              lat = double.tryParse(parts[2].trim());
              lon = double.tryParse(parts[3].trim());
            }
            return (token: token, lat: lat, lon: lon);
          }
        }
      } catch (_) {}

      // 2. Thử định dạng XOR cũ (OK:qrToken)
      try {
        final keyBytes = utf8.encode(trimmedPin);
        final dec = <int>[];
        for (int i = 0; i < bytes.length; i++) {
          dec.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
        }
        final result = utf8.decode(dec);
        if (result.startsWith('OK:')) {
          return (token: result.substring(3), lat: null, lon: null);
        }
      } catch (_) {}
    }

    return (token: null, lat: null, lon: null);
  }

  /// Giải mã qrToken từ payload khi sinh viên nhập mã 4 số.
  /// Trả về qrToken nếu nhập đúng mã PIN, trả về null nếu nhập sai.
  static String? resolveQrTokenWithPin(String payload, String pin) {
    return resolveDetailsWithPin(payload, pin).token;
  }

  /// Tạo mã PIN từ chính qrToken (deterministic).
  static String fallbackPinFromToken(String qrToken) {
    if (qrToken.isEmpty) return '1234';
    final trimmed = qrToken.trim();
    if (trimmed.length == 4 && int.tryParse(trimmed) != null) {
      return trimmed;
    }
    int hash = 5381;
    for (final unit in trimmed.codeUnits) {
      hash = ((hash << 5) + hash) + unit;
    }
    return (1000 + (hash.abs() % 9000)).toString();
  }
}
