class ApiException implements Exception {
  final String code;
  final String message;
  const ApiException(this.code, this.message);

  @override
  String toString() => 'ApiException($code): $message';
}

class GpsMismatchException extends ApiException {
  const GpsMismatchException(String message) : super('gps_mismatch', message);
}

class AuthGraceExpiredException extends ApiException {
  const AuthGraceExpiredException(String message)
      : super('auth_grace_expired', message);
}

class DeviceNotFoundException extends ApiException {
  const DeviceNotFoundException(String message)
      : super('device_not_found', message);
}

class SessionNotFoundException extends ApiException {
  const SessionNotFoundException(String message)
      : super('session_not_found', message);
}
