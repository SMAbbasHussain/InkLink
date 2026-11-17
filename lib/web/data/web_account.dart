/// The signed-in user as the web companion needs it (no Firebase types, so
/// pages can run on sample data in preview mode and tests).
class WebAccount {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;

  /// True when the account signs in with email and password (those accounts
  /// must verify their email first; Google accounts are verified already).
  final bool usesPassword;

  const WebAccount({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = true,
    this.usesPassword = false,
  });
}
