# Google Play Billing Troubleshooting & Operational Guide

Panduan ini berisi langkah-langkah diagnostik, pengaturan secret yang aman, tabel kode error, dan query SQL untuk memeriksa kesehatan integrasi Google Play Billing pada proyek BuildEra.

---

## 1. Pengaturan Secret secara Aman di Windows PowerShell

Saat mengatur secret `GOOGLE_SERVICE_ACCOUNT_JSON` di PowerShell, penggunaan kutip yang salah dapat menyebabkan karakter newline `\n` pada `private_key` terhapus atau terkonversi secara salah.

### Cara 1: Menggunakan File `.env.secrets` dengan Single Quotes (Direkomendasikan)
1. Buat file lokal `.env.secrets` (jangan dikommit ke repository Git):
   ```env
   GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\nMIIEvgI...\n-----END PRIVATE KEY-----\n","client_email":"..."}'
   ANDROID_PACKAGE_NAME='com.solutivostudio.caltax'
   PLAY_RTDN_TOKEN='secret-rtdn-token'
   RECONCILE_SECRET='secret-reconcile-token'
   ```
2. Jalankan perintah Supabase CLI untuk mengupload secret:
   ```powershell
   supabase secrets set --env-file .env.secrets
   supabase functions deploy verify-play-purchase play-rtdn reconcile-play-subscriptions play-billing-diagnose
   ```
3. Hapus atau pastikan file `.env.secrets` masuk ke `.gitignore`.

### Cara 2: Menggunakan Variant Base64 (`GOOGLE_SERVICE_ACCOUNT_JSON_B64`)
1. Encode isi JSON Service Account Anda ke Base64 di PowerShell:
   ```powershell
   $bytes = [System.Text.Encoding]::UTF8.GetBytes((Get-Content -Raw -Path "service-account.json"))
   $b64 = [Convert]::ToBase64String($bytes)
   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON_B64="$b64" ANDROID_PACKAGE_NAME="com.solutivostudio.caltax" RECONCILE_SECRET="secret-reconcile-token"
   ```

---

## 2. Tabel Kode Error, Arti, dan Cara Perbaikan

Edge Function `verify-play-purchase` mengembalikan struktur error berseri:
```json
{
  "error": "Pesan deskriptif",
  "code": "kode_error_stabil"
}
```

| Kode Error | Kategori | Arti / Penyebab | Cara Perbaikan |
| --- | --- | --- | --- |
| `server_config_missing` | Permanen | Secret `GOOGLE_SERVICE_ACCOUNT_JSON` / `_B64` atau `ANDROID_PACKAGE_NAME` belum diatur di Supabase. | Jalankan `supabase secrets set` untuk mengatur secret yang hilang. |
| `server_config_json` | Permanen | Format JSON Service Account rusak atau `client_email`/`private_key` tidak dapat diparse. | Upload ulang JSON Service Account menggunakan format Base64 atau file `.env.secrets` berpembatas kutip tunggal. |
| `unauthorized` | Permanen | Header `Authorization` tidak ditemukan atau JWT pengguna tidak valid. | Pastikan pengguna telah login di aplikasi Flutter sebelum melakukan verifikasi. |
| `bad_request` | Permanen | Parameter `purchaseToken` atau `productId` kosong, atau `productId` bukan `buildera_monthly` / `buildera_yearly`. | Periksa payload produk yang dikirim oleh aplikasi Flutter. |
| `product_mismatch` | Permanen | `productId` yang dikirim tidak ditemukan pada item transaksi Google Play. | Pastikan ID produk di Google Play Console tepat bernilai `buildera_monthly` atau `buildera_yearly`. |
| `not_bound` | Permanen | `obfuscatedExternalAccountId` dari Google Play atau database tidak cocok dengan ID pengguna yang login. | Pastikan pengguna login dengan akun Google Play / Toko yang sesuai. |
| `bound_other_user` | Permanen | `purchaseToken` sudah pernah terikat ke pengguna lain di database (`play_purchases`). | Transaksi ini milik akun lain; cegah penklaiman ganda. |
| `google_auth` | Permanen | Server menerima HTTP 401/403 dari Google API. Email Service Account belum diberi izin di Google Play Console. | Tambahkan Service Account ke Google Play Console -> Users & permissions dengan izin "View financial data" dan "Manage orders". |
| `google_package_mismatch` | Permanen | Google API mengembalikan `applicationNotFound` atau `purchaseTokenMismatch`. | Pastikan `ANDROID_PACKAGE_NAME` di secret tepat sama dengan Application ID (`com.solutivostudio.caltax`). |
| `google_token_invalid` | Permanen | Google API mengembalikan HTTP 410 (`purchaseTokenNoLongerValid` / `subscriptionNoLongerAvailable`). | Transaksi sudah dibatalkan/hangus oleh Google. User perlu berlangganan ulang. |
| `google_unavailable` | Sementara | Google Play API mengalami gangguan sementara (HTTP 409/429/5xx atau timeout). | Aplikasi akan me-retry secara otomatis. Coba lagi beberapa saat lagi. |
| `db_persist` | Sementara | RPC `apply_play_subscription` di database Postgres mengalami kegagalan. | Jalankan `supabase db push` dan pastikan fungsi `apply_play_subscription` ter-deploy dengan benar. |
| `internal` | Sementara | Uncaught exception pada Edge Function. | Periksa log fungsi pada Supabase Dashboard -> Edge Functions -> Logs. |

---

## 3. Pemakaian Endpoint Diagnosa (`play-billing-diagnose`)

Endpoint ini melakukan pengecekan *read-only* tanpa membocorkan secret atau token pembelian.

### Cara Memanggil via `curl`:
```bash
curl -X POST \
  'https://<project-ref>.supabase.co/functions/v1/play-billing-diagnose' \
  -H 'x-reconcile-secret: <RECONCILE_SECRET>' \
  -H 'Content-Type: application/json'
```

### Contoh Respon Sehat (All Checks OK):
```json
{
  "ok": true,
  "env_present": true,
  "service_account_parse_ok": true,
  "private_key_import_ok": true,
  "oauth_token_ok": true,
  "google_api_ok": true,
  "subscription_product_ids_found": true,
  "health": {
    "has_play_purchases_table": true,
    "apply_play_subscription_overload_count": 1,
    "has_subscription_columns": true,
    "has_play_purchases_dead_columns": true
  },
  "issues": []
}
```

---

## 4. Query SQL Cek Kesehatan Database

Jalankan query SQL berikut di Supabase SQL Editor untuk memverifikasi struktur tabel dan fungsi:

```sql
-- 1. Cek keberadaan tabel play_purchases
SELECT to_regclass('public.play_purchases');

-- 2. Cek jumlah overload apply_play_subscription (HARUS TEPAT 1)
SELECT count(*)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.proname = 'apply_play_subscription';

-- 3. Cek kolom-kolom wajib pada tabel subscriptions
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'subscriptions'
  AND column_name IN ('source', 'play_purchase_token', 'play_state', 'auto_renewing', 'last_verified_at', 'is_trial');

-- 4. Jalankan fungsi diagnostik SQL bawaan
SELECT public.play_billing_health();
```

---

## 5. Izin Service Account di Google Play Console

Agar Edge Function dapat memverifikasi transaksi via Google Android Publisher API, email Service Account (`client_email` di JSON) harus didaftarkan di Google Play Console:

1. Buka [Google Play Console](https://play.google.com/console).
2. Pilih **Users & permissions** (Pengguna & izin) -> **Invite new users**.
3. Masukkan email Service Account (contoh: `buildera-billing@your-project.iam.gserviceaccount.com`).
4. Pada bagian **Account permissions**, centang izin wajib:
   - **View financial data** (Melihat data keuangan)
   - **Manage orders and subscriptions** (Mengelola pesanan dan langganan)
5. Klik **Invite user**.
6. **Catatan Penting**: Propagasi izin dari Google Play Console ke Google API memerlukan waktu **beberapa jam hingga maksimal 24 jam**.

---

## 6. Cara Cancel / Refund Pesanan Uji di Play Console & License Testing

1. **Uji Coba Pembelian Tanpa Biaya (License Testing)**:
   - Di Google Play Console -> **Setup** -> **License testing**.
   - Tambahkan email tester Anda ke daftar License Testers.
   - Pada metode pembayaran tester, pilih **"License test card, always approves"**.
2. **Refund / Pembatalan Pesanan Uji**:
   - Buka Google Play Console -> **Order management** (Manajemen Pesanan).
   - Cari nomor pesanan (Order ID berformat `GPA.xxxx-xxxx-xxxx-xxxxx`).
   - Klik nomor pesanan -> Tekan **Refund** atau **Cancel**.

---

## 7. Peringatan Jendela Acknowledge 3 Hari

Google Play mewajibkan setiap transaksi langganan untuk di-**acknowledge** (diakui) dalam waktu **72 jam (3 hari)** sejak transaksi berhasil.
- Jika transaksi tidak di-acknowledge oleh server/aplikasi dalam 3 hari, Google Play akan **membatalkan transaksi dan mengembalikan dana (*auto-refund*) secara otomatis** kepada pengguna.
- Sistem BuildEra secara otomatis memanggil API `acknowledge` saat verifikasi `verify-play-purchase` atau saat reconciler harian `reconcile-play-subscriptions` berjalan.
