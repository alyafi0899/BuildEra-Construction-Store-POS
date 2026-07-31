import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb hide AuthUser;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart';

final supabaseClientProvider = Provider<sb.SupabaseClient>((ref) => sb.Supabase.instance.client);

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange.map((data) {
    final user = data.session?.user;
    if (user == null) return null;
    return AuthUser.fromSupabase(user);
  });
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

class AuthRepository {
  final sb.SupabaseClient _supabase;
  AuthRepository(this._supabase);

  Future<void> login(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<sb.User?> register(String email, String password) async {
    final response = await _supabase.auth.signUp(email: email, password: password);
    return response.user;
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> reloadUser() async {
    await _supabase.auth.refreshSession();
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(sb.UserAttributes(password: newPassword));
  }

  Future<void> updateEmail(String newEmail) async {
    await _supabase.auth.updateUser(sb.UserAttributes(email: newEmail));
  }

  Future<void> reauthenticate(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendVerificationEmail(String email) async {
    await _supabase.auth.resend(type: sb.OtpType.signup, email: email);
  }
}
