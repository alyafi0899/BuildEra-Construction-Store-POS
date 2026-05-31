# 🚀 Konstruksi POS — Web Setup

## Langkah 1: Buka terminal di folder ini
```
cd konstruksi_pos_web
```

## Langkah 2: Jalankan flutter pub get
```
flutter pub get
```

## Langkah 3: Jalankan di browser
```
flutter run -d chrome
```

## Build untuk production
```
flutter build web --release
```
Output ada di folder `build/web/` — upload ke Netlify / Vercel / Firebase Hosting.

---

## Kenapa tidak ada folder android/ windows/ dll?

Project ini **hanya untuk web**. Tidak ada platform lain.
Saat `flutter pub get` dijalankan, Flutter akan otomatis mengenali `web/` folder
dan menyiapkan semua yang diperlukan.

## Persyaratan
- Flutter SDK >= 3.13
- Chrome browser (untuk development)
- Jalankan `flutter config --enable-web` jika web belum aktif
