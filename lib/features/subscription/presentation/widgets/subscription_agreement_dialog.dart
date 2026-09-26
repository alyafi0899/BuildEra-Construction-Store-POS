import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/subscription.dart';
import '../../../shared/presentation/pages/legal_document_page.dart';

class SubscriptionAgreementDialog extends StatefulWidget {
  final PlanType plan;
  final VoidCallback onAccepted;

  const SubscriptionAgreementDialog(
      {super.key, required this.plan, required this.onAccepted});

  @override
  State<SubscriptionAgreementDialog> createState() =>
      _SubscriptionAgreementDialogState();
}

class _SubscriptionAgreementDialogState
    extends State<SubscriptionAgreementDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final amount = widget.plan == PlanType.yearly
        ? 'Rp 1.000.000 / tahun'
        : 'Rp 100.000 / bulan';
    return AlertDialog(
      title: const Text('Konfirmasi Langganan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anda akan memilih Paket Full Features seharga $amount.',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pembayaran pada aplikasi saat ini hanya simulasi. Tidak ada tagihan atau transaksi nyata yang dibuat.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Checkbox(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                activeColor: AppTheme.accent,
              ),
              Expanded(
                child: Wrap(
                  children: [
                    const Text('Saya setuju dengan '),
                    GestureDetector(
                      onTap: () =>
                          _showLegal(context, 'Syarat & Ketentuan', _tosText),
                      child: const Text(
                        'Syarat & Ketentuan',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text(' serta '),
                    GestureDetector(
                      onTap: () => _showLegal(
                          context, 'Kebijakan Privasi', _privacyText),
                      child: const Text(
                        'Kebijakan Privasi',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text(' yang berlaku.'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('BATAL', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          onPressed: _agreed
              ? () {
                  Navigator.pop(context);
                  widget.onAccepted();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('LANJUTKAN KE PEMBAYARAN'),
        ),
      ],
    );
  }

  void _showLegal(BuildContext context, String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegalDocumentPage(title: title, content: content),
      ),
    );
  }

  static const _tosText = '''
SYARAT & KETENTUAN LAYANAN POS CONSTRUCTION

1. Layanan Langganan:
  - Paket Full Features memberikan akses ke seluruh fitur premium sesuai durasi paket yang dipilih.
   - Pembayaran dilakukan di muka (prepaid).

2. Pembayaran:
  - Alur pembayaran yang tersedia saat ini merupakan simulasi.
  - Tidak ada tagihan atau transaksi nyata yang dibuat dari alur simulasi ini.

3. Kebijakan Pengembalian Dana:
   - Pembayaran yang sudah dilakukan tidak dapat dikembalikan (non-refundable).

4. Penggunaan Data:
   - Data transaksi Anda disimpan secara aman di server cloud kami.
   - Anda bertanggung jawab atas kerahasiaan akun dan PIN keamanan Anda.
''';

  static const _privacyText = '''
KEBIJAKAN PRIVASI POS CONSTRUCTION

1. Pengumpulan Data:
   - Kami mengumpulkan data transaksi, stok, dan profil toko untuk menyediakan fitur analitik.
   - Kami mengumpulkan email Anda untuk keperluan autentikasi akun.

2. Keamanan Data:
   - Data Anda dienkripsi dan disimpan menggunakan infrastruktur Supabase yang aman.
   - Kami tidak akan pernah menjual data bisnis Anda kepada pihak ketiga manapun.

3. Hak Pengguna:
   - Anda memiliki hak penuh atas data Anda dan dapat mengekspor atau menghapusnya kapan saja melalui koordinasi dengan tim support kami.
''';
}
