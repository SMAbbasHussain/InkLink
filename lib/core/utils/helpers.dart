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

/// Validate password strength
/// Requirements: At least 6 characters
bool isValidPassword(String password) {
  return password.length >= 6;
}
