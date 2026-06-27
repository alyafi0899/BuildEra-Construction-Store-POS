# BuildEra - High-Performance Construction Store POS

BuildEra is a professional, **Offline-First** Point of Sale (POS) system engineered specifically for construction and building material stores. It combines the speed of local database technology with the reliability of Cloud Sync, offering a robust solution for businesses requiring deep financial tracking, complex inventory management, and stable desktop performance.
## 🚀 Core Philosophy: Efficiency & Accuracy
https://github.com/alyafi0899/BuildEra-Construction-Store-POS-Open-Source-Yall/releases/tag/v1.0.0

## 📝 Core Philosophy: Efficiency & Accuracy
In the construction industry, prices fluctuate and weights vary. BuildEra is built to handle:
- **Last-In Costing**: Automatically updates product modal based on the latest restock batch.
- **Financial Depth**: Tracks Supplier Price and Shipping Cost separately for precise net profit.
- **Offline-First**: Every transaction and restock works instantly without internet, syncing to Firestore in the background.

---

## 🌟 Premium Features

### 🛒 Modern Cashier (POS)
- **Hybrid Scanning**: Seamlessly switch between "Direct Sell" (Auto-add) and "Manual Search" modes.
- **Unit Versatility**: Sell products in any unit (e.g., Roll, Meter, Sack, Kg) with automatic stock conversion.
- **Price Flexibility**: Support for item-level/transaction discounts and manual Price Overrides.
- **Customer Display**: Live cart synchronization to a secondary customer-facing window (Windows Optimized).

### 📦 Advanced Inventory & Restock
- **Batch Audit Trail**: Complete history of every stock entry with the ability to edit or delete past batches.
- **Profit Forecasting**: Live estimates of net profit based on current stock and latest modal costs.
- **Intelligent Restock**: Form identical to "Add Product" for a flat learning curve, including automated modal calculation and selling price suggestions.

### 💳 Financial & Bill Management (New!)
- **Multi-Payment Bills**: Manage debts to Suppliers and Shippers with support for **Partial Payments (Installments)**.
- **Payment History**: Track every cent paid toward a specific batch with dates and notes.
- **Piutang Pelanggan**: Dedicated dashboard for customer debts with detailed transaction history and Excel exports.
- **Automated Reminders**: Analytics dashboard instantly flags unpaid supplier invoices and shipping fees.

### 📊 Deep Analytics & Professional Reporting
- **Performance Summary**: Track Net Profit (Today/Month), Revenue trends, and Top Selling products.
- **Daily Detail**: Expandable daily breakdowns showing transaction-level profitability.
- **A4 PDF Reports**: Generate professional, high-density reports optimized for A4 printing and digital sharing.

---

## 🎨 UI/UX Excellence
- **Adobe-Style Branding**: Premium splash screen with radial gradients and smooth scale transitions.
- **Categorized Navigation**: Sidebar organized by **OPERASIONAL**, **INVENTORI**, **FINANSIAL**, and **SISTEM**.
- **Windows Stability**: Rigorously debugged to prevent common Flutter-on-Windows rendering crashes (Dropdown and BoxConstraints fixes).
- **Dark Mode Optimization**: A consistent, low-strain dark aesthetic for long-shift operations.

---

## 🛠 Technical Architecture

- **Framework**: Flutter 3.13+ (Desktop/Windows Priority)
- **Local Storage**: Hive (NoSQL) for ultra-fast local reads/writes.
- **Cloud Sync**: Firebase Firestore with a custom **Sync Queue Manager** for background data integrity.
- **State Management**: Flutter Riverpod (Modern Notifier & AsyncNotifier patterns).
- **File System**: Automated Downloads management and PDF generation via `pdf` and `path_provider`.

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── theme/           # Premium AppTheme (Dark)
│   ├── sync/            # Offline-to-Cloud Sync Engine
│   └── utils/           # Formatters, PDF Helpers, Image processing
├── features/
│   ├── cashier/         # POS UI, Cart Logic, Multi-window Sync
│   ├── products/        # CRUD, Entity Management (Suppliers/Shippers)
│   ├── inventory/       # Stock Logic, Restock History, Bill Management
│   ├── debts/           # Customer Piutang & Debt Detail
│   ├── analytics/       # Net Profit Dashboard
│   └── settings/        # Cloud-synced Store Profiles
├── shared/
│   ├── models/          # Product, Transaction, BillPayment models
│   └── widgets/         # Categorized Sidebar, PageHeaders, AppCards
└── main.dart            # Multi-window & Boot Logic
```

---

## 📝 Configuration Requirements

### Windows Build
BuildEra is optimized for Windows Desktop. Ensure your environment has:
- Visual Studio 2022 with "Desktop development with C++" workload.
- window_manager dependencies for multi-window support.

### Firebase Setup
1. Create a Firebase project.
2. Enable Firestore and Storage.
3. Use FlutterFire CLI to generate `firebase_options.dart`.
4. **Important**: For Windows, Firestore persistence is disabled manually in `main.dart` to ensure compatibility with our custom Hive Sync Engine.

---

**Developed by**: Al Yafi alongside with Claude AI coding Agent
**Version**: 1.5.0 (Stable)
**Status**: Production Ready for Windows Desktop
