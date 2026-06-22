/// Base class for all domain-level errors surfaced to the UI.
class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Raised when the backend returns HTTP 402 (out of AI credits). The app
/// listens for this globally to show the paywall, mirroring the web
/// `credits-depleted` event.
class InsufficientCreditsException extends AppException {
  const InsufficientCreditsException()
      : super('Insufficient AI credits', statusCode: 402);
}

/// Raised on connectivity / timeout failures.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error. Please try again.']);
}

/// Raised when the session is missing or rejected (needs re-login).
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired'])
      : super(statusCode: 401);
}
