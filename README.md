# 🔧 KonstrukPOS (Web + Desktop)

POS System profesional untuk toko bangunan — Flutter + Hive + Riverpod.

## ✨ Stack Teknologi

| Layer | Teknologi |
|-------|-----------|
| UI Framework | Flutter 3.x |
| State Management | Riverpod 2.x |
| Database Lokal | **Hive** (NoSQL, web + desktop compatible) |
| Platform | Web (Chrome/Edge) · Windows · macOS · Linux |

## 🚀 Cara Menjalankan

### Prasyarat
```bash
flutter --version  # >= 3.10.0
```

### Run di Web (Chrome)
```bash
cd konstrukpos
flutter pub get
flutter run -d chrome
```

### Run di Desktop (Windows/macOS/Linux)
```bash
flutter config --enable-windows-desktop  # atau macos / linux
flutter run -d windows
```

### Build Web Production
```bash
flutter build web --release
# Output: build/web/  → deploy ke Nginx / Firebase Hosting / Vercel
```

### Build Windows EXE
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/konstrukpos.exe
```

## 📁 Struktur Project

```
lib/
├── core/
│   ├── constants/    # AppConstants, AppRoutes
│   ├── errors/       # AppException hierarchy
│   ├── theme/        # AppTheme, AppColors (dark industrial)
│   └── utils/        # Formatters (IDR), DecimalUtils
├── data/
│   └── hive/
│       ├── hive_models.dart    # HiveProduct, HiveTransaction + TypeAdapters
│       └── hive_service.dart   # CRUD ops, seed data, ID counters
├── features/
│   ├── cashier/       # Halaman kasir, cart state
│   ├── inventory/     # Manajemen stok, penyesuaian stok
│   ├── payment/       # Dialog pembayaran, riwayat transaksi
│   ├── products/      # CRUD produk, multi-satuan
│   └── settings/      # Info toko, statistik
├── shared/
│   └── widgets/       # Sidebar, CommonWidgets, DataTable, BarcodeListener
├── app_shell.dart     # Root layout + routing
└── main.dart          # Init Hive + seed + ProviderScope
```

## 🗄️ Hive Database

### Box Registry
| Box Name | Type | Isi |
|----------|------|-----|
| `products` | `Box<HiveProduct>` | Semua produk + unit satuan |
| `transactions` | `Box<HiveTransaction>` | Semua transaksi + item |
| `meta` | `Box<dynamic>` | ID counters, seed flag |

### TypeAdapter IDs
| typeId | Class |
|--------|-------|
| 0 | HiveProductUnit |
| 1 | HiveProduct |
| 2 | HiveTransactionItem |
| 3 | HiveTransaction |

> ⚠️ Jangan ubah typeId — akan merusak data tersimpan.

## 🔄 Multi-Unit System

```
Semen Portland (base: kg)
  ├── kg     → Rp 1.800   (ratio = 1)
  └── sak    → Rp 75.000  (ratio = 40, 1 sak = 40 kg)

Tali Tambang (base: meter)
  ├── meter  → Rp 8.500   (ratio = 1)
  └── roll   → Rp 400.000 (ratio = 50, 1 roll = 50 meter)
```

Saat checkout, stok dikurangi dalam satuan dasar:
`stok_dikurangi = qty × conversion_ratio`

## 🎨 Design Tokens

| Token | Hex |
|-------|-----|
| Background | `#0F1117` |
| Surface | `#1A1D27` |
| Primary (Orange) | `#FF6B1A` |
| Text Primary | `#F0F2FF` |
| Success | `#2ECC71` |
| Warning | `#F39C12` |
| Error | `#E74C3C` |

## 🐛 FAQ

**Q: Data hilang saat refresh browser?**  
A: Hive di web menyimpan di IndexedDB browser — data persisten. Jangan clear site data.

**Q: Ganti nama toko?**  
A: Edit `lib/core/constants/app_constants.dart` → `storeName`, `storeAddress`, `storePhone`.

**Q: Reset semua data?**  
A: Di browser: DevTools → Application → IndexedDB → hapus `hive`. Di desktop: hapus folder `hive/` di AppData.

**Q: Tambah kategori baru?**  
A: Edit `AppConstants.categories` di `app_constants.dart`.
