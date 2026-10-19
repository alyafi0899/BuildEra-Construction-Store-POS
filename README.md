# BuildEra - High-Performance Construction Store POS

BuildEra is a professional, **Offline-First** Point of Sale (POS) system engineered specifically for construction and building material stores. It combines the speed of local database technology with the reliability of Cloud Sync, offering a robust solution for businesses requiring deep financial tracking, complex inventory management, and stable desktop performance.

## 🚀 Build Release! Download and try the App Here:
https://github.com/alyafi0899/BuildEra-Construction-Store-POS-Open-Source-Yall/releases/tag/v1.2.0
<img width="1920" height="1080" alt="Slide 16_9 - 3" src="https://github.com/user-attachments/assets/eeb826fc-2d58-4008-a8ca-57b714bf72f2" />

---

## 🔒 Advanced Security System (New in v1.2.0)
Security is no longer an afterthought. BuildEra now features a multi-layered protection system:
- **Enforced PIN Setup**: New users are required to configure a Security PIN immediately after registration/verification to protect sensitive store data.
- **Auto-Lock Navigation**: The application automatically re-locks sensitive pages (Analytics, Product Costs, Bills) whenever you switch between sidebar menus.
- **Protected Actions**: Critical operations such as **deleting invoices**, **modifying customer data**, or **wiping debt records** now require explicit PIN authorization.
- **Secure PIN Input**: Optimized focus management ensures the PIN field is active the moment a security gate appears, providing a seamless yet secure workflow.

---

## 📩 Support, Privacy & Account Deletion
BuildEra includes a direct support flow and user-data controls for compliance and customer care.
- **Support email**: wenyafi@gmail.com
- **Privacy policy**: https://alyafi0899.github.io/BuildEra-Construction-Store-POS/privacy-policy/
- **Account deletion request**: https://alyafi0899.github.io/BuildEra-Construction-Store-POS/account-deletion/
- **SLA**: account deletion requests are processed within 30 days.

To publish these pages, open **GitHub → Settings → Pages**, choose **Deploy from a branch**, select the default branch and the `/docs` folder, then save. After deployment, open both URLs above and confirm they return HTTP 200.

---

## ⚡ Performance & Low-Spec Optimization
BuildEra is now rigorously optimized for older hardware (Old POS PCs/Monitors) commonly found in traditional stores:
- **Zero-Latency Rendering**: Replaced GPU-heavy Blur/Backdrop filters with high-performance solid overlays, increasing scrolling smoothness by up to 300% on integrated graphics.
- **Smart Image Caching**: Automatic memory-level resizing of product images prevents RAM bloat, allowing the app to run comfortably on systems with only 2GB-4GB of RAM.
- **Search Debouncing**: Sophisticated filtering logic that waits for the user to finish typing (300ms) before processing large datasets (800+ items), eliminating "typing stutter."
- **Atomic Bulk Sync**: Refactored synchronization engine that handles **8000+ products** using 200-item chunks and anti-choke delays, ensuring 100% data integrity even on unstable internet.

---

## 🌟 Premium Features

### 🛒 Modern Cashier (POS)
- **Focus Separation Logic**: Scanned barcodes are sent directly to the cart even if the cursor is in the search field.
- **Intelligent Search**: Search field populates and stays with the scanned code for visual confirmation without triggering accidental checkouts.
- **Hybrid Scanning**: Seamlessly switch between "Direct Sell" (Auto-add) and "Manual Search" modes.
- **Unit Versatility**: Sell products in any unit (e.g., Roll, Meter, Sack, Kg) with automatic stock conversion.
- **Customer Display**: Live cart synchronization to a secondary customer-facing window (Windows Optimized).

### 📦 Advanced Inventory & Restock
- **Batch Audit Trail**: Complete history of every stock entry with the ability to edit or delete past batches.
- **Profit Forecasting**: Live estimates of net profit based on current stock and latest modal costs.
- **Intelligent Restock**: Automated modal calculation and selling price suggestions based on the latest cost batch.

### 💳 Financial & Bill Management
- **Multi-Payment Bills**: Manage debts to Suppliers and Shippers with support for **Partial Payments (Installments)**.
- **Piutang Pelanggan**: Dedicated dashboard for customer debts with detailed transaction history and Excel exports.
- **Automated Reminders**: Analytics dashboard instantly flags unpaid supplier invoices and shipping fees.

---

## 🎨 UI/UX Excellence
- **Adobe-Style Branding**: Premium splash screen with radial gradients and smooth scale transitions.
- **Instant Boot**: Enabled Hive Hybrid Loading for near-instant access to data after the splash screen.
- **Fail-Safe Initialization**: 10-second timeout protection during boot to prevent hanging on poor internet connections.

---

## 🛠 Technical Architecture

- **Framework**: Flutter 3.13+ (Desktop/Windows Priority)
- **Local Storage**: Hive (NoSQL) for ultra-fast local reads/writes.
- **Cloud Sync**: Supabase (PostgreSQL) with a **Realtime Sync Engine** for large-scale data integrity.
- **State Management**: Flutter Riverpod (Notifier & AsyncNotifier patterns).

---

**Developed by**: **Al Yafi**
- **Version**: 1.2.0 (High-Performance Stable)
- **Status**: Production Ready for Windows Desktop
