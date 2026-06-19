import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../settings/models/store_settings.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      
      // 1. Create Account
      await authRepo.register(_emailCtrl.text.trim(), _passCtrl.text);
      
      // 2. Prepare business data
      final settings = StoreSettings(
        businessName: _storeNameCtrl.text.trim(),
        ownerName:    _ownerNameCtrl.text.trim(),
        phone:        _phoneCtrl.text.trim(),
        email:        _bizEmailCtrl.text.trim(),
        address:      _addressCtrl.text.trim(),
        description:  _descCtrl.text.trim(),
      );

      // 3. Save profile (SettingsNotifier will handle the Firestore path)
      await ref.read(settingsProvider.notifier).updateSettings(settings);

    } catch (e) {
      if (mounted) showError(context, 'Gagal mendaftar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Daftar Akun Baru'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 600,
          margin: const EdgeInsets.symmetric(vertical: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Form(
            key: _formKey,
            child: Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep++);
                  }
                } else {
                  _register();
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
                          onPressed: _loading ? null : details.onStepContinue,
                          child: _loading ? const AppLoading() : Text(_currentStep == 0 ? 'LANJUT KE INFO BISNIS' : 'DAFTAR SEKARANG'),
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
                  title: const Text('Akun'),
                  isActive: _currentStep >= 0,
                  content: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email Login', prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                        obscureText: true,
                        validator: (v) => v!.length < 8 ? 'Password minimal 8 karakter' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPassCtrl,
                        decoration: const InputDecoration(labelText: 'Konfirmasi Password', prefixIcon: Icon(Icons.lock_reset_outlined)),
                        obscureText: true,
                        validator: (v) => v != _passCtrl.text ? 'Password tidak cocok' : null,
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Bisnis'),
                  isActive: _currentStep >= 1,
                  content: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _ownerNameCtrl,
                            decoration: const InputDecoration(labelText: 'Nama Pemilik', prefixIcon: Icon(Icons.person_outline)),
                            validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _storeNameCtrl,
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
                            decoration: const InputDecoration(labelText: 'Nomor Telepon', prefixIcon: Icon(Icons.phone_outlined)),
                            validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _bizEmailCtrl,
                            decoration: const InputDecoration(labelText: 'Email Bisnis', prefixIcon: Icon(Icons.business_outlined)),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Alamat Toko', prefixIcon: Icon(Icons.location_on_outlined)),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(labelText: 'Deskripsi Toko', prefixIcon: Icon(Icons.description_outlined)),
                        maxLines: 2,
                      ),
                    ],
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
