class AuthException implements Exception {
  final String message;
  // HTTP status of the API answer when there was one (e.g. 404), to choose what to show
  final int? statusCode;
  AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
