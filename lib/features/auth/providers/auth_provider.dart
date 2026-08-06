import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

class TemporaryPassword extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final temporaryPasswordProvider = NotifierProvider<TemporaryPassword, String?>(TemporaryPassword.new);

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  
  return client.auth.onAuthStateChange.map((data) {
    // Identity is known if session.user is present, or fallback to current user
    final user = data.session?.user ?? client.auth.currentUser;
    if (user == null) return null;
    return AuthUser.fromSupabase(user);
  });
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  GoTrueClient get _auth => _client.auth;

  Future<void> login(String email, String password) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthUser?> register(String email, String password, {Map<String, dynamic>? metadata}) async {
    final res = await _auth.signUp(
      email: email, 
      password: password,
      data: metadata,
    );
    if (res.user == null) return null;
    return AuthUser.fromSupabase(res.user!);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  Future<void> sendVerificationEmail() async {
    final email = _auth.currentUser?.email;
    if (email != null) {
      await _auth.resend(type: OtpType.signup, email: email);
    }
  }

  Future<void> reloadUser() async {
    await _auth.refreshSession();
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    await _auth.updateUser(UserAttributes(email: newEmail));
  }

  Future<void> reauthenticate(String email, String password) async {
    // Supabase doesn't have a direct 'reauthenticate' like Firebase.
    // We typically just try to sign in again or rely on the session.
    await _auth.signInWithPassword(email: email, password: password);
  }
}
