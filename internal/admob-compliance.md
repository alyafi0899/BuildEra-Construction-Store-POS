# Panduan Kepatuhan AdMob & Google Play Console (BuildEra)

Dokumen ini berisi panduan langkah manual untuk Pemilik Toko / Pengembang dalam mengonfigurasi AdMob dan Google Play Console agar sesuai dengan kebijakan resmi Google.

---

## ⚠️ PERINGATAN PENTING
> **JANGAN PERNAH MENGKLIK IKLAN PRODUKSI DI PERANGKAT SENDIRI!**  
> Mengklik iklan sendiri pada build release/produksi dapat menyebabkan akun AdMob Anda disuspensi atau dibanned permanen karena dianggap sebagai trafik tidak valid (*invalid traffic*). Selalu gunakan ID Iklan Uji (*Test Ads*) saat pengembangan dan pengujian internal.

---

## 1. Konfigurasi Google Play Console

1. **App Content -> Ads**:
   - Buka Google Play Console -> Pilih aplikasi **BuildEra** -> Menu **App content**.
   - Pada bagian **Ads**, pilih **"Yes, my app contains ads"**.

2. **Deklarasi Advertising ID (IDI)**:
   - Pada menu **App content** -> **Advertising ID**.
   - Pilih **Yes**, aplikasi menggunakan Advertising ID untuk penayangan iklan dan analitik AdMob.
   - Pilih alasan: **Advertising or marketing**.

3. **Deklarasi Data Safety (Keamanan Data)**:
   - Pada menu **App content** -> **Data safety**.
   - Isikan deklarasi untuk AdMob:
     - **Device or other IDs**: Dikumpulkan (*Collected*) dan Dibagikan (*Shared*) untuk tujuan *Advertising / Marketing* dan *Analytics*.
     - **Location (Coarse location)**: Dikumpulkan oleh SDK iklan jika diizinkan untuk *Advertising / Marketing*.

---

## 2. Konfigurasi Konsol Google AdMob

1. **Pesan Consent GDPR & UMP**:
   - Buka Konsol AdMob (https://admob.google.com).
   - Masuk ke menu **Privacy & messaging** -> **GDPR**.
   - Buat dan publikasikan pesan persetujuan (*consent message*) untuk pengguna di kawasan Eropa/EEA dan UK.

2. **Penautan Aplikasi ke Listing Google Play**:
   - Di AdMob Console -> Menu **Apps** -> **App settings**.
   - Tautkan aplikasi dengan listing resmi BuildEra di Google Play Store setelah aplikasi dipublikasikan.

3. **Menyiapkan File `app-ads.txt`**:
   - Buat file bernama `app-ads.txt` pada direktori akar domain situs web pengembang Anda (contoh: `https://solutivo.com/app-ads.txt`).
   - Masukkan baris berikut:
     ```text
     google.com, pub-3908012989174014, DIRECT, f08c47fec0942fa0
     ```
   - *Catatan*: Hindari penggunaan subdomain gratis seperti `workers.dev` untuk verifikasi `app-ads.txt` yang stabil.

---

## 3. Pendaftaran Perangkat Uji (*Test Device*)

Untuk menguji iklan produksi secara aman tanpa risiko pembekuan akun:
1. Jalankan aplikasi build debug pada perangkat HP Anda.
2. Buka `logcat` Android Studio / terminal dan cari log bertuliskan:
   ```text
   Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("YOUR_DEVICE_HASH_ID"))
   ```
3. Salin `YOUR_DEVICE_HASH_ID` tersebut.
4. Buka Konsol AdMob -> **Settings** -> **Test devices** -> **Add test device**, lalu masukkan ID hash HP Anda.

---

## 4. Checklist Uji Sebelum Rilis
- [x] Mode Debug menggunakan Test Ad Unit ID resmi Google (`ca-app-pub-3940256099942544/...`).
- [x] Mode Release/Production menggunakan Ad Unit ID milik akun Anda (`ca-app-pub-3908012989174014/...`).
- [x] Akun Premium tidak memuat SDK AdMob dan tidak menampilkan iklan.
- [x] Tombol reward terbukti memberikan bonus +10 transaksi hanya saat callback `onUserEarnedReward` dipanggil.
