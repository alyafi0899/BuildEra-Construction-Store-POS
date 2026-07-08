import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('loginEmail', isEqualTo: email)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw 'Data tidak ditemukan atau tidak cocok dengan sistem kami.';
      }

      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      
      if (mounted) {
        showSuccess(context, 'Link reset password telah dikirim ke email Anda.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_reset_rounded, size: 64, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text('Lupa Password', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(
                  'Untuk keamanan, masukkan Email Login dan Nomor HP Pemilik yang terdaftar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Login',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor HP Pemilik',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Nomor HP wajib diisi' : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _reset,
                    child: _loading ? const AppLoading() : const Text('VERIFIKASI & KIRIM LINK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
