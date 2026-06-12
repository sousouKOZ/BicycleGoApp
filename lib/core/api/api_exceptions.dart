class ApiException implements Exception {
  final String code;
  final String message;
  const ApiException(this.code, this.message);

  @override
  String toString() => 'ApiException($code): $message';
}

class AuthGraceExpiredException extends ApiException {
  const AuthGraceExpiredException(String message)
      : super('auth_grace_expired', message);
}

/// MCU からの parking_detect 自体が無い（自転車が検知されていない）。
class NoRecentDetectionException extends ApiException {
  const NoRecentDetectionException(String message)
      : super('no_recent_detection', message);
}

class DeviceNotFoundException extends ApiException {
  const DeviceNotFoundException(String message)
      : super('device_not_found', message);
}

class SessionNotFoundException extends ApiException {
  const SessionNotFoundException(String message)
      : super('session_not_found', message);
}
