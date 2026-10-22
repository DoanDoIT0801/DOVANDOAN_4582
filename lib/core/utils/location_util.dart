import 'package:geolocator/geolocator.dart';

import '../exceptions/api_exception.dart';

// Lấy toạ độ hiện tại, xin quyền vị trí nếu cần.
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw ApiException('Vui lòng bật GPS trên điện thoại.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw ApiException('Ứng dụng cần quyền vị trí để điểm danh.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}
