class InputSanitizer {
  /// Sanitize a string to prevent XSS and common injection patterns.
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    
    return input
        .trim()
        // Remove script tags and other dangerous HTML
        .replaceAll(RegExp(r'<script\b[^>]*>([\s\S]*?)<\/script>', caseSensitive: false), "")
        .replaceAll(RegExp(r'<[^>]*>?'), "")
        // Limit length to prevent buffer overflow-like issues or large data spam
        .substring(0, input.length > 2000 ? 2000 : input.length);
  }

  /// Validate if the string is a valid email.
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  /// Validate password strength (example).
  static bool isStrongPassword(String password) {
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }
}
