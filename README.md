# Konstruksi POS - Construction Store Point of Sale System

A modern Flutter-based Point of Sale (POS) system designed specifically for construction material stores. Built with Firebase backend, real-time inventory management, and comprehensive sales analytics.

## Features

### 🛒 Cashier Module
- Fast product search and barcode scanning
- Dynamic shopping cart with multiple unit support
- Flexible discount system
- Automatic tax calculation (PPN 11%)
- Multiple payment method support
- Real-time stock availability indicators

### 📦 Inventory Management
- Track product stock levels
- Low stock warnings
- Product categorization
- Bulk operations with Excel import/export
- Real-time stock updates across modules

### 🛍️ Product Management
- Add/edit/delete products with ease
- Multiple unit configurations per product
- Dynamic pricing based on units
- Barcode support
- Product image support
- Category management

### 💳 Transaction & Payment
- Complete transaction history
- Multiple payment method tracking
- Receipt generation
- Transaction analytics
- Payment reconciliation

### 📊 Analytics Dashboard
- Sales overview and trends
- Revenue by category
- Top selling products
- Daily/monthly/yearly reports
- Stock level analytics
- Visual charts and graphs

## Tech Stack

- **Frontend**: Flutter 3.13+
- **State Management**: Flutter Riverpod 3.3+
- **Backend**: Firebase with Cloud Firestore
- **UI Framework**: Material Design 3
- **Data Visualization**: FL Chart
- **Local Storage**: Shared Preferences
- **Localization**: Intl (Indonesian language support)
- **Excel Support**: Excel 4.0+
- **File Handling**: File Picker

## Prerequisites

- Flutter SDK: >=3.13.0
- Dart SDK: >=3.1.0
- Firebase account and project
- iOS: Xcode 14+
- Android: Android Studio with SDK 21+
- Windows: Visual Studio 2022 with C++ development tools
- macOS: Xcode 14+

## Installation & Setup

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
- Download your Google services configuration files:
  - `google-services.json` → `android/app/`
  - `GoogleService-Info.plist` → `ios/Runner/`
- Update `lib/firebase_options.dart` with your Firebase configuration

### 4. Run the Application

**Development**:
```bash
flutter run
```

**Release Build**:
```bash
flutter run --release
```

**Platform-specific builds**:
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
│
├── core/
│   ├── theme/
│   │   └── app_theme.dart             # Theme definitions (dark mode)
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants
│   └── utils/
│       └── formatters.dart            # Currency, date, number formatting
│
├── shared/
│   ├── models/
│   │   ├── product.dart               # Product & ProductUnit models
│   │   └── transaction.dart           # Transaction model
│   └── widgets/
│       ├── sidebar.dart               # Main navigation sidebar
│       └── common_widgets.dart        # Reusable UI components
│
├── features/
│   ├── cashier/
│   │   ├── models/
│   │   │   └── cart_item.dart         # Shopping cart item model
│   │   ├── providers/
│   │   │   └── cart_provider.dart     # Cart state management
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   └── cashier_page.dart  # Main cashier UI
│   │   │   └── widgets/
│   │   │       └── payment_dialog.dart # Payment processing
│   │
│   ├── products/
│   │   ├── providers/
│   │   │   └── product_provider.dart  # Product CRUD & state
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   │   └── products_page.dart # Product management UI
│   │   │   └── widgets/
│   │   │       ├── product_form_dialog.dart
│   │   │       └── excel_import_dialog.dart
│   │
│   ├── inventory/
│   │   └── presentation/
│   │       └── pages/
│   │           └── inventory_page.dart # Stock management
│   │
│   ├── payment/
│   │   ├── providers/
│   │   │   └── transaction_provider.dart
│   │   └── presentation/
│   │       └── pages/
│   │           └── transactions_page.dart # Transaction history
│   │
│   └── analytics/
│       └── presentation/
│           └── pages/
│               └── analytics_page.dart # Sales analytics & reports
│
└── database/
    └── local_database.dart            # Local caching (SQLite/Hive)
```

## Key Features Explained

### Multi-Unit Product System
Products can have multiple selling units (e.g., cement sold by "bag", "kg", "ton") with different prices:
```dart
Product(
  name: "Cement",
  baseUnit: "kg",
  basePrice: 1500,
  units: [
    ProductUnit(unitName: "bag", conversionRate: 50, sellPrice: 75000),
    ProductUnit(unitName: "kg", conversionRate: 1, sellPrice: 1500),
  ]
)
```

### Cart Management
- Intelligent cart system tracking product units
- Automatic price calculation per unit
- Support for partial quantities
- Discount and tax application

### Real-Time Inventory
- Stock updates synchronized across modules
- Low stock warnings (< 10 units)
- Stock validation during checkout

### Firebase Integration
- Cloud Firestore for data persistence
- Real-time data syncing
- Scalable backend infrastructure
- Offline-ready local caching

## Development Guidelines

### State Management with Riverpod
- Use Riverpod for all state management
- Providers for data access and mutations
- ConsumerWidget/ConsumerStatefulWidget for UI that watches state

### Theme System
- Centralized dark theme in `app_theme.dart`
- Material Design 3 color tokens
- Accessible color contrasts

### Code Style
- Dart conventions
- Clear widget composition
- Proper resource cleanup (dispose)

## Testing

Run tests with:
```bash
flutter test
```

## Building for Production

### Android Release
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS Release
```bash
flutter build ios --release
```

### Web (if enabled)
```bash
flutter build web --release
```

## Troubleshooting

### Firebase Connection Issues
- Verify Google services configuration files
- Check Firebase security rules
- Ensure internet connectivity

### State Management Issues
- Clear app cache: `flutter clean`
- Rebuild providers: `flutter pub get`
- Check Riverpod debugger in Chrome DevTools

### Build Issues
- Update Flutter: `flutter upgrade`
- Clean build: `flutter clean && flutter pub get`
- Check platform-specific requirements

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Commit changes: `git commit -am 'Add new feature'`
3. Push to branch: `git push origin feature/your-feature`
4. Open a Pull Request

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Support

For issues, questions, or suggestions:
- Open an issue on [GitHub Issues](https://github.com/alyafi0899/Construction-Store-Pos/issues)
- Check existing documentation and FAQs

## Changelog

### Version 1.0.0
- Initial release
- Cashier module with full cart system
- Product and inventory management
- Transaction tracking
- Analytics dashboard

---

**Developed by**: [Your Team]  
**Last Updated**: 2026-06-01  
**Repository**: https://github.com/alyafi0899/Construction-Store-Pos
