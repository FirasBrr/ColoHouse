import 'package:email_validator/email_validator.dart';

/// Form validators shared by the login, register and reset-password forms.
class AuthValidators {
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!EmailValidator.validate(v.trim())) {
      return 'Enter a valid email address (e.g. you@example.com)';
    }
    return null;
  }

  static String? name(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    if (v.trim().length > 50) return '$field is too long';
    return null;
  }

  // Sign-up rule: at least 8 characters with a letter and a digit
  static String? newPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'Add at least one letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add at least one digit';
    return null;
  }
}
