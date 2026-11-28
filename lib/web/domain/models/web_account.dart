/// Signed-in user identity exposed to the web companion without leaking
/// Firebase Auth SDK types into UI or Cubit layers.
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
