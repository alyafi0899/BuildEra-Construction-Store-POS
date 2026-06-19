import 'package:firebase_auth/firebase_auth.dart';

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

  factory AuthUser.fromFirebase(User user) {
    return AuthUser(
      uid:             user.uid,
      email:           user.email ?? '',
      isEmailVerified: user.emailVerified,
      displayName:     user.displayName,
    );
  }
}
