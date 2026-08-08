import 'package:flutter/foundation.dart';

class ApiConstants {
  // En web usa localhost; en emulador Android 10.0.2.2 apunta al PC host.
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  static const String login = '/auth/login';
  static const String users = '/users';
  static const String motorbikes = '/motorbikes';
  static const String rides = '/rides';
  static const String routes = '/routes';
}
