import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  // Use userChanges() instead of authStateChanges() to catch metadata changes like email verification
  return ref.watch(firebaseAuthProvider).userChanges().map((user) {
    if (user == null) return null;
    return AuthUser.fromFirebase(user);
  });
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

class AuthRepository {
  final FirebaseAuth _auth;
  AuthRepository(this._auth);

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<User?> register(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.sendEmailVerification();
    return cred.user;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
  }

  /// Standard sign-in check for "Forgot PIN" scenario to bypass strict reauthentication timeouts
  Future<void> verifyCredentials(String email, String password) async {
    try {
      // Use a temporary firebase auth instance or just try to sign in with credentials
      // to verify they are correct without binding to the main session if possible
      final tempAuth = FirebaseAuth.instance;
      await tempAuth.signInWithEmailAndPassword(email: email, password: password).timeout(const Duration(seconds: 10));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'user-not-found') {
        throw 'Password yang Anda masukkan salah atau email tidak terdaftar.';
      }
      rethrow;
    } catch (e) {
      throw 'Gagal verifikasi: $e';
    }
  }

  Future<void> reauthenticate(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Sesi login tidak ditemukan. Silakan login kembali.',
      );
    }
    
    // Safety check to ensure we are re-authenticating the right user
    if (user.email != null && user.email!.toLowerCase() != email.toLowerCase()) {
      throw FirebaseAuthException(
        code: 'email-mismatch',
        message: 'Email konfirmasi tidak sesuai dengan akun yang login.',
      );
    }

    final cred = EmailAuthProvider.credential(email: email, password: password);
    try {
      await user.reauthenticateWithCredential(cred).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'network-timeout',
        message: 'Waktu verifikasi habis. Periksa koneksi internet Anda.',
      );
    }
  }
}
