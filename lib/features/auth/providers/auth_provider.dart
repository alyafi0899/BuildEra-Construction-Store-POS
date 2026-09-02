import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart' as model;
import '../../settings/models/store_settings.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Tracks the email used during the most recent registration attempt to show the verify screen
final registrationEmailProvider = NotifierProvider<RegistrationEmailNotifier, String?>(RegistrationEmailNotifier.new);

class RegistrationEmailNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? email) => state = email;
}

/// Robust Auth Notifier that handles session changes and manual refreshes
class AuthNotifier extends StreamNotifier<model.AuthUser?> {
  @override
  Stream<model.AuthUser?> build() {
    final client = ref.watch(supabaseClientProvider);
    
    // Listen to Supabase Auth Changes
    return client.auth.onAuthStateChange.asyncMap((data) async {
      final user = data.session?.user;
      if (user == null) return null;
      
      // Clear registration email if we successfully signed in
      ref.read(registrationEmailProvider.notifier).set(null);
      
      return model.AuthUser.fromSupabase(user);
    });
  }

  /// Manually force a user reload to check for email verification status
  Future<void> refreshUser() async {
    try {
      final client = ref.read(supabaseClientProvider);
      // getUser() fetches the latest user data from the server, 
      // bypassing the local cached session.
      final response = await client.auth.getUser();
      if (response.user != null) {
        state = AsyncData(model.AuthUser.fromSupabase(response.user!));
      }
    } catch (e) {
      // Ignore refresh errors
    }
  }
}

final authStateProvider = StreamNotifierProvider<AuthNotifier, model.AuthUser?>(AuthNotifier.new);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider), ref);
});

class AuthRepository {
  final SupabaseClient _client;
  final Ref _ref;
  AuthRepository(this._client, this._ref);

  GoTrueClient get _auth => _client.auth;

  Future<void> login(String email, String password) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<User?> register({
    required String email, 
    required String password,
    required StoreSettings settings,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email, 
        password: password,
        data: settings.toMap(), 
      );
      
      if (response.user != null) {
        _ref.read(registrationEmailProvider.notifier).set(email);
      }
      
      return response.user;
    } on AuthException catch (e) {
      if (e.statusCode == '429' || e.code == 'over_email_send_rate_limit' || e.message.contains('User already registered')) {
        _ref.read(registrationEmailProvider.notifier).set(email);
        if (e.code == 'over_email_send_rate_limit') {
           throw 'Limit pengiriman email tercapai. Akun telah dibuat, silakan cek inbox Anda atau tunggu 1 menit.';
        }
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _ref.read(registrationEmailProvider.notifier).set(null);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  Future<void> verifyAndSendPasswordReset({required String email, required String phone}) async {
    // FIX: Using Case-Insensitive (ilike) and robust trimming for search
    final response = await _client
        .from('users')
        .select('id, login_email, phone')
        .ilike('login_email', email.trim())
        .eq('phone', phone.trim())
        .maybeSingle();

    if (response == null) {
      throw 'Data tidak ditemukan atau tidak cocok dengan sistem kami.\nPastikan Email dan No HP Pemilik sudah benar.';
    }

    await _auth.resetPasswordForEmail(email.trim());
  }

  Future<void> sendVerificationEmail() async {
    final email = _ref.read(registrationEmailProvider) ?? _auth.currentUser?.email;
    if (email != null) {
      await _auth.resend(type: OtpType.signup, email: email);
    }
  }

  Future<void> reloadUser() async {
    await _ref.read(authStateProvider.notifier).refreshUser();
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> verifyCredentials(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email, password: password).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw 'Password yang Anda masukkan salah atau email tidak terdaftar.';
    }
  }

  Future<void> reauthenticate(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan login kembali.');
    }
    
    if (user.email != null && user.email!.toLowerCase() != email.toLowerCase()) {
      throw Exception('Email konfirmasi tidak sesuai dengan akun yang login.');
    }

    try {
      await _auth.signInWithPassword(email: email, password: password).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Waktu verifikasi habis atau kredensial salah. Periksa koneksi internet Anda.');
    }
  }
}
