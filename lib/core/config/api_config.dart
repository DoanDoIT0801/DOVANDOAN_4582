import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ignore: camel_case_types
class Config_URL {
  static String get baseUrl {
    final url = dotenv.env['BASE_URL'];
    if (url == null) {
      debugPrint("BASE_URL is not set in the .env file. Using default URL.");
      //đường dẫn API nếu không đọc được URL trong file .env
      return "https://longashgrape36.conveyor.cloud/api/";
    }
    return url;
  }
}

