import 'package:supabase_flutter/supabase_flutter.dart';

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

  factory AuthUser.fromSupabase(User user) {
    return AuthUser(
      uid:             user.id,
      email:           user.email ?? '',
      isEmailVerified: user.emailConfirmedAt != null,
      displayName:     user.userMetadata?['display_name']?.toString(),
    );
  }
}
