import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../../settings/models/store_settings.dart';
import '../../../../core/sync/providers/initial_sync_provider.dart';
import '../../../../core/sync/providers/connectivity_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _loading = false;

  // Step 1: Account
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Step 2: Business
  final _ownerNameCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bizEmailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    for (var c in [_emailCtrl, _passCtrl, _confirmPassCtrl, _ownerNameCtrl, _storeNameCtrl, _phoneCtrl, _bizEmailCtrl, _addressCtrl, _descCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey2.currentState!.validate()) return;
    if (!ref.read(isOnlineProvider)) {
      showError(context, 'Tidak ada koneksi internet. Silakan hubungkan perangkat ke jaringan.');
      return;
    }

    setState(() => _loading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      // 0. Store password temporarily for auto-login after verification
      ref.read(temporaryPasswordProvider.notifier).set(password);
      
      // 1. Prepare business data to be sent as metadata
      final settings = StoreSettings(
        businessName: _storeNameCtrl.text.trim(),
        ownerName:    _ownerNameCtrl.text.trim(),
        phone:        _phoneCtrl.text.trim(),
        email:        _bizEmailCtrl.text.trim(),
        loginEmail:   email,
        address:      _addressCtrl.text.trim(),
        description:  _descCtrl.text.trim(),
      );

      // 2. Create Account with metadata (DB trigger will create the profile automatically)
      final user = await authRepo.register(
        email, 
        password, 
        metadata: {'store_settings': settings.toMap()},
      );
      
      if (user != null) {
        // Mark initial sync as done for new users locally
        await ref.read(initialSyncProvider.notifier).markAsDone(user.uid);
      }
      
      // --- IMPORTANT: NO NAVIGATION HERE ---
      // authStateProvider will emit the new (unverified) user, 
      // and AuthGate will automatically switch to VerifyEmailPage.

    } on AuthException catch (e) {
      // Ignore errors related to 'session is null' since registration still succeeded
      if (e.message.contains('session') || e.message.contains('null')) return;

      if (mounted) {
        String msg = e.message;
        if (msg.contains('User already registered')) msg = 'Email sudah terdaftar.';
        showError(context, 'Gagal mendaftar: $msg');
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal mendaftar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Daftar Akun Baru'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              backgroundColor: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              side: BorderSide(color: isOnline ? Colors.green : Colors.red),
              label: Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(color: isOnline ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              avatar: Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 12, color: isOnline ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          width: 800,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.accent,
                secondary: AppTheme.accent,
                onSurface: Colors.white,
              ),
              canvasColor: AppTheme.surface,
            ),
            child: Stepper(
              type: isDesktop ? StepperType.horizontal : StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  if (_formKey1.currentState!.validate()) {
                    setState(() => _currentStep++);
                  }
                } else {
                  if (_formKey2.currentState!.validate()) {
                    _register();
                  }
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading || !isOnline ? null : details.onStepContinue,
                          child: _loading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                              : Text(_currentStep == 0 ? 'LANJUT KE INFO BISNIS' : 'DAFTAR SEKARANG'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _loading ? null : details.onStepCancel,
                        child: const Text('KEMBALI'),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Akun', style: TextStyle(color: Colors.white, fontSize: 12)),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formKey1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email Login', prefixIcon: Icon(Icons.email_outlined)),
                          validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                          obscureText: true,
                          validator: (v) => v!.length < 8 ? 'Password minimal 8 karakter' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPassCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Konfirmasi Password', prefixIcon: Icon(Icons.lock_reset_outlined)),
                          obscureText: true,
                          validator: (v) => v != _passCtrl.text ? 'Password tidak cocok' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Bisnis', style: TextStyle(color: Colors.white, fontSize: 12)),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formKey2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: TextFormField(
                              controller: _ownerNameCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.name,
                              decoration: const InputDecoration(labelText: 'Nama Pemilik', prefixIcon: Icon(Icons.person_outline)),
                              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: TextFormField(
                              controller: _storeNameCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.name,
                              decoration: const InputDecoration(labelText: 'Nama Toko', prefixIcon: Icon(Icons.store_outlined)),
                              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextFormField(
                              controller: _phoneCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Nomor Telepon', prefixIcon: Icon(Icons.phone_outlined)),
                              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: TextFormField(
                              controller: _bizEmailCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email Bisnis', prefixIcon: Icon(Icons.business_outlined)),
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(labelText: 'Alamat Toko', prefixIcon: Icon(Icons.location_on_outlined)),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(labelText: 'Deskripsi Toko', prefixIcon: Icon(Icons.description_outlined)),
                          maxLines: 2,
                        ),
                      ],
                    ),
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
