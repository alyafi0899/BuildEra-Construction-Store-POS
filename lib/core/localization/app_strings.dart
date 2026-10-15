import 'app_language.dart';

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get isEnglish => language == AppLanguage.english;

  // ── Navigation & Sidebar ─────────────────────────────────────────
  String get navCashier => isEnglish ? 'Cashier' : 'Kasir';
  String get navProducts => isEnglish ? 'Products' : 'Produk';
  String get navTransactions => isEnglish ? 'Transactions' : 'Transaksi';
  String get navDebts => isEnglish ? 'Receivables' : 'Piutang';
  String get navCustomers => isEnglish ? 'Customers' : 'Pelanggan';
  String get navAnalytics => isEnglish ? 'Analytics' : 'Analitik';
  String get navBarcodes => isEnglish ? 'Barcode Labels' : 'Label Barcode';
  String get navSettings => isEnglish ? 'Settings' : 'Pengaturan';
  String get navBills => isEnglish ? 'Bills' : 'Tagihan';
  String get navCustomerDisplay => isEnglish ? 'Customer Display' : 'Tampilan Pelanggan';
  String get navPurchases => isEnglish ? 'Purchases' : 'Pembelian';
  String get navPurchaseHistory => isEnglish ? 'Purchase History' : 'Riwayat Beli';
  String get navMore => isEnglish ? 'More' : 'Lainnya';

  // ── Cashier Module ─────────────────────────────────────────────────
  String get cashierTitle => isEnglish ? 'POS Cashier' : 'Kasir';
  String get searchProductOrBarcode => isEnglish ? 'Search product or scan barcode...' : 'Cari produk atau scan barcode...';
  String get openCameraScanner => isEnglish ? 'Open Camera Scanner' : 'Buka Kamera Scanner';
  String get allCategories => isEnglish ? 'All Categories' : 'Semua Kategori';
  String get shoppingCart => isEnglish ? 'Shopping Cart' : 'Keranjang Belanja';
  String get cartIsEmpty => isEnglish ? 'Shopping Cart is Empty' : 'Keranjang Masih Kosong';
  String get addProductsFromListBeside => isEnglish ? 'Add products from the list on the left' : 'Tambahkan produk dari daftar di samping';
  String get totalPayment => isEnglish ? 'Total Payment' : 'Total Pembayaran';
  String get clearCart => isEnglish ? 'Clear Cart' : 'Bersihkan Keranjang';
  String get processPayment => isEnglish ? 'Process Payment' : 'Proses Pembayaran';
  String get selectCustomer => isEnglish ? 'Select Customer' : 'Pilih Pelanggan';
  String get selectCustomerOptional => isEnglish ? 'Select Customer (Optional)' : 'Pilih Pelanggan (Opsional)';
  String get generalCustomer => isEnglish ? 'General Customer' : 'Pelanggan Umum';
  String get discount => isEnglish ? 'Discount' : 'Diskon';
  String get mainCashier => isEnglish ? 'Main Cashier' : 'Kasir Utama';
  String get paymentMethod => isEnglish ? 'Payment Method' : 'Metode Pembayaran';
  String get cash => isEnglish ? 'Cash' : 'Tunai';
  String get qris => isEnglish ? 'Transfer / QRIS' : 'Transfer / QRIS';
  String get creditDebt => isEnglish ? 'Credit / Debt' : 'Tempo (Piutang)';
  String get moneyReceived => isEnglish ? 'Money Received' : 'Uang Diterima';
  String get change => isEnglish ? 'Change' : 'Kembalian';
  String get printReceipt => isEnglish ? 'Print Receipt' : 'Cetak Struk';
  String get transactionSuccessful => isEnglish ? 'Transaction Successful' : 'Transaksi Berhasil';
  String get amountLessTotal => isEnglish ? 'Payment amount is less than total' : 'Jumlah bayar kurang dari total';
  String get selectCustomerForCredit => isEnglish ? 'Select customer for credit transaction' : 'Pilih pelanggan untuk transaksi piutang';
  String get shippingFee => isEnglish ? 'Shipping Fee' : 'Biaya Pengiriman';
  String get notes => isEnglish ? 'Notes / Description' : 'Catatan / Keterangan';
  String get dueDateCredit => isEnglish ? 'Credit Due Date' : 'Jatuh Tempo Piutang';
  String get paymentInstruction => isEnglish ? 'Payment Instruction' : 'Instruksi Pembayaran';

  // ── Products Module ────────────────────────────────────────────────
  String get productsTitle => isEnglish ? 'Product Management' : 'Daftar Produk';
  String get addProduct => isEnglish ? 'Add Product' : 'Tambah Produk';
  String get editProduct => isEnglish ? 'Edit Product' : 'Edit Produk';
  String get deleteProduct => isEnglish ? 'Delete Product' : 'Hapus Produk';
  String get productName => isEnglish ? 'Product Name' : 'Nama Produk';
  String get productDescription => isEnglish ? 'Product Description / Notes' : 'Deskripsi / Catatan Produk';
  String get sellingPrice => isEnglish ? 'Selling Price' : 'Harga Jual';
  String get costPrice => isEnglish ? 'Cost Price' : 'Modal (HPP)';
  String get profitPercentage => isEnglish ? 'Profit Percentage (%)' : 'Persentase Keuntungan (%)';
  String get stock => isEnglish ? 'Stock' : 'Stok';
  String get category => isEnglish ? 'Category' : 'Kategori';
  String get unit => isEnglish ? 'Unit' : 'Satuan';
  String get barcode => isEnglish ? 'Barcode' : 'Barcode';
  String get generateBarcode => isEnglish ? 'Generate Barcode' : 'Acak Barcode';
  String get manageBarcode => isEnglish ? 'Manage Barcode' : 'Kelola Barcode';
  String get exportBackup => isEnglish ? 'Export Backup' : 'Ekspor Backup';
  String get importExcel => isEnglish ? 'Import Excel' : 'Impor Excel';
  String get deleteProductConfirm => isEnglish ? 'Are you sure you want to delete this product?' : 'Apakah Anda yakin ingin menghapus produk ini?';
  String get printLabel => isEnglish ? 'Print Label' : 'Cetak Label';
  String get supplierInfo => isEnglish ? 'Supplier & Cost Info' : 'Informasi Supplier & HPP';
  String get chooseCategory => isEnglish ? 'Choose Category' : 'Pilih Kategori';
  String get chooseUnit => isEnglish ? 'Choose Unit' : 'Pilih Satuan';
  String get unitConversion => isEnglish ? 'Unit Conversion' : 'Konversi Satuan';
  String get supplierPrice => isEnglish ? 'Supplier Purchase Price' : 'Harga Beli Supplier';
  String get supplierShippingCost => isEnglish ? 'Supplier Shipping Cost' : 'Ongkos Kirim Supplier';
  String get manualCostPrice => isEnglish ? 'Set Cost Price Manually' : 'Set Modal (HPP) Manual';

  // ── Transactions Module ─────────────────────────────────────────────
  String get transactionsTitle => isEnglish ? 'Transactions' : 'Transaksi';
  String get transactionHistory => isEnglish ? 'Transaction History' : 'Riwayat Transaksi';
  String get todayIncome => isEnglish ? "Today's Income" : 'Pendapatan Hari Ini';
  String get searchInvoiceOrCustomer => isEnglish ? 'Search invoice or customer...' : 'Cari nomor nota atau pelanggan...';
  String get transactionDetail => isEnglish ? 'Transaction Detail' : 'Detail Transaksi';
  String get invoiceNumber => isEnglish ? 'Invoice Number' : 'Nomor Nota';
  String get cashierName => isEnglish ? 'Cashier Name' : 'Nama Kasir';
  String get transactionDate => isEnglish ? 'Transaction Date' : 'Tanggal Transaksi';
  String get paymentReceipt => isEnglish ? 'Payment Receipt' : 'Struk Pembayaran';
  String get reprintReceipt => isEnglish ? 'Reprint Receipt' : 'Cetak Ulang Struk';
  String get cancelTransaction => isEnglish ? 'Cancel Transaction' : 'Batalkan Transaksi';
  String get refundTransaction => isEnglish ? 'Refund / Cancel Transaction' : 'Refund / Batalkan Transaksi';

  // ── Debts & Customers Module ────────────────────────────────────────
  String get debtSummary => isEnglish ? 'Receivables Summary' : 'Ringkasan Piutang';
  String get totalDebt => isEnglish ? 'Total Receivables' : 'Total Piutang';
  String get dueDate => isEnglish ? 'Due Date' : 'Jatuh Tempo';
  String get payDebt => isEnglish ? 'Pay Debt' : 'Bayar Piutang';
  String get addCustomer => isEnglish ? 'Add Customer' : 'Tambah Pelanggan';
  String get customerName => isEnglish ? 'Customer Name' : 'Nama Pelanggan';
  String get customerPhone => isEnglish ? 'Customer Phone' : 'Nomor Telepon Pelanggan';
  String get customerAddress => isEnglish ? 'Customer Address' : 'Alamat Pelanggan';
  String get paymentHistory => isEnglish ? 'Payment History' : 'Riwayat Pembayaran';
  String get remainingDebt => isEnglish ? 'Remaining Debt' : 'Sisa Piutang';
  String get customerList => isEnglish ? 'Customer List' : 'Daftar Pelanggan';
  String get payOff => isEnglish ? 'Full Payment' : 'Pelunasan';
  String get installment => isEnglish ? 'Installment' : 'Cicilan';
  String get debtPaymentSuccessful => isEnglish ? 'Debt payment recorded successfully' : 'Pembayaran piutang berhasil dicatat';

  // ── Purchases & Suppliers Module ────────────────────────────────────
  String get purchasesTitle => isEnglish ? 'Purchases' : 'Pembelian';
  String get purchaseNote => isEnglish ? 'Purchase Note' : 'Nota Pembelian';
  String get supplier => isEnglish ? 'Supplier' : 'Supplier';
  String get purchaseHistory => isEnglish ? 'Purchase History' : 'Riwayat Pembelian';
  String get supplierBills => isEnglish ? 'Supplier Bills' : 'Tagihan Supplier';
  String get totalBills => isEnglish ? 'Total Bills' : 'Total Tagihan';
  String get paymentStatus => isEnglish ? 'Payment Status' : 'Status Pembayaran';
  String get paid => isEnglish ? 'Paid' : 'Lunas';
  String get unpaid => isEnglish ? 'Unpaid' : 'Belum Lunas';
  String get operationalExpenses => isEnglish ? 'Operational Expenses' : 'Pengeluaran Operasional';
  String get addBill => isEnglish ? 'Add Bill' : 'Tambah Tagihan';
  String get billCategory => isEnglish ? 'Bill Category' : 'Kategori Tagihan';

  // ── Analytics Module ────────────────────────────────────────────────
  String get analyticsTitle => isEnglish ? 'Analytics & Reports' : 'Analitik & Laporan';
  String get totalSales => isEnglish ? 'Total Sales' : 'Total Penjualan';
  String get netProfit => isEnglish ? 'Net Profit' : 'Laba Bersih';
  String get salesChart => isEnglish ? 'Sales Chart' : 'Grafik Penjualan';
  String get topSellingProducts => isEnglish ? 'Top Selling Products' : 'Produk Terlaris';

  // ── Settings Module ─────────────────────────────────────────────────
  String get settingsTitle => isEnglish ? 'Settings' : 'Pengaturan';
  String get posFeatureManagement => isEnglish ? 'POS Feature Management' : 'Manajemen Fitur POS';
  String get storeSettings => isEnglish ? 'Store Settings' : 'Pengaturan Toko';
  String get businessIdentity => isEnglish ? 'Business Identity' : 'Identitas Bisnis';
  String get businessName => isEnglish ? 'Business Name' : 'Nama Bisnis';
  String get storeAddress => isEnglish ? 'Store Address' : 'Alamat Toko';
  String get phoneNumber => isEnglish ? 'Phone Number' : 'Nomor Telepon';
  String get paymentMethodQris => isEnglish ? 'Payment Methods & QRIS' : 'Metode Pembayaran & QRIS';
  String get printerAndReceiptDesign => isEnglish ? 'Printer & Receipt Design' : 'Printer & Desain Struk';
  String get securityAdminPin => isEnglish ? 'Security & Admin PIN' : 'Keamanan & PIN Admin';
  String get displaySettings => isEnglish ? 'Display Settings' : 'Pengaturan Tampilan & Layar';
  String get fullScreenMode => isEnglish ? 'Full Screen Mode' : 'Mode Layar Penuh';
  String get dualMonitorDisplay => isEnglish ? 'Dual Monitor Customer Display' : 'Tampilan Pelanggan Dual Monitor';
  String get displayScale => isEnglish ? 'Display Scale' : 'Skala Tampilan';
  String get languageSettings => isEnglish ? 'Language Settings' : 'Pengaturan Bahasa / Language';
  String get languageLabel => isEnglish ? 'Language' : 'Bahasa';
  String get selectLanguage => isEnglish ? 'Select Application Language' : 'Pilih Bahasa Aplikasi';
  String get dataBackupExcel => isEnglish ? 'Backup Data to Excel' : 'Backup Data ke Excel';
  String get resetStoreData => isEnglish ? 'Reset & Clear All Store Data' : 'Reset & Hapus Seluruh Data Toko';
  String get confirmResetData => isEnglish ? 'Are you sure you want to permanently delete all store operational data?' : 'Apakah Anda yakin ingin menghapus seluruh data operasional toko secara permanen?';
  String get saveSettings => isEnglish ? 'Save Settings' : 'Simpan Pengaturan';
  String get settingsSaved => isEnglish ? 'Settings saved successfully' : 'Pengaturan berhasil disimpan';

  // ── Subscription Module ─────────────────────────────────────────────
  String get subscriptionTitle => isEnglish ? 'Subscription Plans' : 'Paket Langganan';
  String get freePlan => isEnglish ? 'Free Plan' : 'Paket Gratis';
  String get monthlyPlan => isEnglish ? 'Monthly Plan' : 'Paket Bulanan';
  String get yearlyPlan => isEnglish ? 'Yearly Plan' : 'Paket Tahunan';
  String get subscriptionStatus => isEnglish ? 'Subscription Status' : 'Status Langganan';
  String get subscribeViaPlayStore => isEnglish ? 'SUBSCRIBE VIA GOOGLE PLAY' : 'BERLANGGANAN VIA GOOGLE PLAY';
  String get restorePurchases => isEnglish ? 'Restore Purchases' : 'Pulihkan Pembelian (Restore Purchases)';
  String get manageSubscriptions => isEnglish ? 'MANAGE SUBSCRIPTION IN GOOGLE PLAY' : 'KELOLA LANGGANAN DI GOOGLE PLAY';

  // ── Auth & Security Module ──────────────────────────────────────────
  String get loginTitle => isEnglish ? 'Login to Account' : 'Masuk ke Akun';
  String get registerTitle => isEnglish ? 'Register Account' : 'Daftar Akun';
  String get email => isEnglish ? 'Email' : 'Email';
  String get password => isEnglish ? 'Password' : 'Kata Sandi';
  String get enterPin => isEnglish ? 'Enter PIN' : 'Masukkan PIN';
  String get securityPinTitle => isEnglish ? 'Security PIN' : 'PIN Keamanan';
  String get enterAdminPin => isEnglish ? 'Enter Admin PIN' : 'Masukkan PIN Admin';
  String get pinCorrect => isEnglish ? 'PIN Correct' : 'PIN Benar';
  String get pinIncorrect => isEnglish ? 'Incorrect PIN' : 'PIN Salah';
  String get forgotPassword => isEnglish ? 'Forgot Password?' : 'Lupa Kata Sandi?';
  String get logout => isEnglish ? 'Logout' : 'Keluar Akun';

  // ── Common Controls ─────────────────────────────────────────────────
  String get save => isEnglish ? 'Save' : 'Simpan';
  String get cancel => isEnglish ? 'Cancel' : 'Batal';
  String get close => isEnglish ? 'Close' : 'Tutup';
  String get back => isEnglish ? 'Back' : 'Kembali';
  String get retry => isEnglish ? 'Retry' : 'Coba Lagi';
  String get delete => isEnglish ? 'Delete' : 'Hapus';
  String get edit => isEnglish ? 'Edit' : 'Edit';
  String get search => isEnglish ? 'Search...' : 'Cari...';
}
