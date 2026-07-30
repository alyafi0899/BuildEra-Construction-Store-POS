import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthUser {
  final String uid;
  final String email;
  final bool isEmailVerified;
  final String? displayName;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.isEmailVerified,
    this.displayName,
  });

  factory AuthUser.fromSupabase(sb.User user) {
    return AuthUser(
      uid:             user.id,
      email:           user.email ?? '',
      isEmailVerified: user.emailConfirmedAt != null,
      displayName:     user.userMetadata?['display_name']?.toString(),
    );
  }
}
