import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/models/store_admin.dart';
import '../../../auth/providers/active_cashier_provider.dart';
import '../../../auth/providers/store_admins_provider.dart';
import '../../../settings/providers/settings_provider.dart';

class CashierSelectorSheet extends ConsumerStatefulWidget {
  const CashierSelectorSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CashierSelectorSheet(),
    );
  }

  @override
  ConsumerState<CashierSelectorSheet> createState() => _CashierSelectorSheetState();
}

class _CashierSelectorSheetState extends ConsumerState<CashierSelectorSheet> {
  StoreAdmin? _selectedAdmin; // null = Owner
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();
  bool _isOwnerSelected = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeAdmins = ref.read(storeAdminsProvider).value?.where((a) => a.isActive).toList() ?? [];
      if (activeAdmins.length == 1) {
        // Keputusan 3: If exactly 1 active admin exists, pre-select that admin profile automatically!
        setState(() {
          _isOwnerSelected = false;
          _selectedAdmin = activeAdmins.first;
        });
      }
      _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'PIN minimal 4 digit');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(activeCashierProvider.notifier);
      await notifier.verifyAndStartSession(
        admin: _isOwnerSelected ? null : _selectedAdmin,
        pin: pin,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          _pinCtrl.clear();
          _pinFocus.requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final ownerName = settings.ownerName.isEmpty ? 'Pemilik' : settings.ownerName;
    final admins = ref.watch(storeAdminsProvider).value?.where((a) => a.isActive).toList() ?? [];

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilih Kasir / Pemilik',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih profil dan masukkan PIN untuk mulai sesi transaksi',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),

            // Profile Grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                // Owner Profile Card
                _buildProfileCard(
                  title: ownerName,
                  subtitle: 'Pemilik Toko',
                  icon: Icons.person_pin_rounded,
                  color: AppTheme.accent,
                  isSelected: _isOwnerSelected,
                  onTap: () {
                    setState(() {
                      _isOwnerSelected = true;
                      _selectedAdmin = null;
                      _error = null;
                      _pinCtrl.clear();
                      _pinFocus.requestFocus();
                    });
                  },
                ),
                // Active Admin Cards
                for (final admin in admins)
                  _buildProfileCard(
                    title: admin.name,
                    subtitle: 'Kasir',
                    icon: Icons.badge_rounded,
                    color: AppTheme.success,
                    isSelected: !_isOwnerSelected && _selectedAdmin?.id == admin.id,
                    onTap: () {
                      setState(() {
                        _isOwnerSelected = false;
                        _selectedAdmin = admin;
                        _error = null;
                        _pinCtrl.clear();
                        _pinFocus.requestFocus();
                      });
                    },
                  ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              'Masukkan PIN (${_isOwnerSelected ? ownerName : _selectedAdmin?.name ?? ''})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),

            // PIN Input Box
            SizedBox(
              width: 220,
              child: TextField(
                controller: _pinCtrl,
                focusNode: _pinFocus,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(letterSpacing: 8),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                ),
                child: _loading ? const AppLoading() : const Text('MULAI SESI TRANSAKSI'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: isSelected ? color : AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
