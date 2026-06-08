# Konstruksi POS - Construction Store Point of Sale System

A modern Flutter-based Point of Sale (POS) system designed specifically for construction material stores. Built with Firebase backend, real-time inventory management, and comprehensive sales analytics.

## 🌟 Key Features

### 🛒 Cashier Module
- **Advanced Barcode Scanning**: Fast global scanning with "Jual Langsung" (Auto-add) or "Cari Produk" modes.
- **Dynamic Shopping Cart**: Multiple unit support (e.g., sell by kg, roll, or box) with interactive unit switching.
- **Flexible Discounts**: Apply discounts per-item or per-transaction (Percentage or Fixed amount).
- **Price Override (Harga Kurang)**: Allow authorized cashiers to manually adjust selling prices during checkout.
- **Diverse Payment Methods**: Support for Cash, QRIS, Debit, and **Bank Transfer** (with manual confirmation).
- **Instant Stock Sync**: Real-time availability indicators and automatic inventory deduction.

### 📄 Professional PDF Invoicing
- **Auto-generated Receipts**: High-quality PDF invoices generated instantly after checkout.
- **Store Branding**: Receipts include store name, address, phone, and **Bank Transfer details**.
- **Unit Support**: Clearly shows quantities and units (e.g., "2 kg x Rp 20.000").
- **Flexible Actions**: Print directly, save locally, or share via WhatsApp/Email immediately after payment.

### 📦 Inventory & Product Management
- **Real-time Stream**: Built using `StreamProvider` for instant UI updates when data changes in Firebase.
- **Multi-Unit Pricing**: Define base units and unlimited additional selling units with custom conversion rates.
- **Product Photos**: Upload compressed product images to Firebase Storage with local caching for offline viewing.
- **Excel Import**: Bulk add products using a simplified 7-column format (Nama, Barcode, Kategori, Satuan, Stok, Modal, Harga Jual).
- **Default Unit Settings**: Set specific units (e.g., "Box") to be automatically selected when scanning.

### 📊 Analytics Dashboard
- **Profit Tracking**: Monitor both **Gross Profit** (Potential) and **Net Profit** (Actual after discounts/overrides).
- **Daily Detail Reports**: Expandable daily reports showing every transaction, payment method, and individual profits.
- **KPI Cards**: Instant overview of Total Revenue, Net Profit, Total SKU, and Low Stock items.
- **Visual Trends**: Revenue bar charts and payment method distribution pie charts.

### ⚙️ Store Configuration
- **Cloud Settings**: Store identity and bank accounts stored securely in **Firebase Firestore**.
- **Multi-Bank Management**: Register multiple bank accounts for customer transfer options.

## 🛠 Tech Stack

- **Frontend**: Flutter 3.13+
- **State Management**: Flutter Riverpod 3.2+ (Using modern `Notifier` and `StreamProvider` patterns)
- **Backend**: Firebase (Cloud Firestore & Firebase Storage)
- **PDF & Printing**: `pdf`, `printing`
- **Utilities**: `image` (compression), `share_plus`, `file_picker`, `excel`, `shared_preferences`
- **UI Framework**: Material Design 3
- **Data Visualization**: FL Chart

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/alyafi0899/Construction-Store-Pos.git
cd "Construction Store Pos"
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
- Create a Firebase project at [firebase.google.com](https://firebase.google.com)
- Enable **Firestore Database** and **Firebase Storage**.
- Download configuration files:
  - `google-services.json` → `android/app/`
  - `GoogleService-Info.plist` → `ios/Runner/`
- Update `lib/firebase_options.dart` using FlutterFire CLI.

### 4. Run the Application
```bash
flutter run -d chrome  # For Web
# or
flutter run           # For Desktop/Mobile
```

## 📁 Project Structure

```
lib/
├── core/
│   ├── theme/           # AppTheme (Dark/Light mode)
│   ├── utils/           # Formatters, InvoiceHelper, ImageHelper
│   └── constants/       # AppConstants & Payment Methods
├── features/
│   ├── cashier/         # Cart, BarcodeListener, PaymentDialog
│   ├── products/        # CRUD, Excel Import, Image Upload
│   ├── inventory/       # Stock Adjustment & Monitoring
│   ├── payment/         # Transaction History & PDF Export
│   ├── analytics/       # Profit Dashboard & Daily Reports
│   └── settings/        # Store Info & Bank Accounts (Cloud Sync)
├── shared/
│   ├── models/          # Product, Transaction, StoreSettings models
│   └── widgets/         # Sidebar, StatCards, ProductImage widget
└── main.dart            # Application Bootstrap
```

## 📝 Excel Import Format
To import products, use an Excel file with these columns in order:
- **A**: Product Name (Required)
- **B**: Barcode
- **C**: Category
- **D**: Base Unit (e.g., kg, pcs)
- **E**: Initial Stock
- **F**: Cost Price (Harga Modal)
- **G**: Base Selling Price (Harga Jual Dasar)

---

**Developed by**: Al Yafi alongside with Claude AI coding Agent
**Last Updated**: 2026-06-07
**Repository**: https://github.com/alyafi0899/Construction-Store-Pos
