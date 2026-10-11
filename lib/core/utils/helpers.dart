// Utility helper functions for the InkLink app

/// Generate search keywords from a name string
/// Used for Firestore full-text search functionality
List<String> generateSearchKeywords(String name) {
  List<String> keywords = [];
  String temp = "";
  for (int i = 0; i < name.length; i++) {
    temp = temp + name[i].toLowerCase();
    keywords.add(temp);
  }
  return keywords;
}

/// Validate email format using regex
bool isValidEmail(String email) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}

/// Validate password strength (FR01-04)
/// Requirements:
/// - Minimum 8 characters
/// - At least one uppercase letter (A-Z)
/// - At least one lowercase letter (a-z)
/// - At least one digit (0-9)
/// - At least one special symbol (!@#$%^&* etc.)
String? getPasswordStrengthError(String password) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters long.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Password must include at least one uppercase letter (A-Z).';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Password must include at least one lowercase letter (a-z).';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Password must include at least one number (0-9).';
  }
  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\/~`\\]').hasMatch(password)) {
    return 'Password must include at least one special character (!@#\$%^&* etc.).';
  }
  return null;
}

/// Returns true if password meets all minimum strength rules
bool isValidPassword(String password) {
  return getPasswordStrengthError(password) == null;
}
