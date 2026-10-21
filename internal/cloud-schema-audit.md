# Audit Skema Cloud BuildEra

Audit ini membandingkan akses Supabase dan antrean sinkronisasi pada kode dengan migrasi yang tersimpan di `supabase/migrations/`. Daftar kolom adalah payload yang dikirim kode, bukan bukti bahwa kolom tersebut benar-benar ada di database produksi. Kolom relasional yang ditambahkan oleh `sync_provider.dart` dicantumkan terpisah.

## Query verifikasi untuk SQL Editor

Jalankan query berikut pada proyek Supabase yang digunakan aplikasi:

```sql
select table_name
from information_schema.tables
where table_schema = 'public';
```

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('transactions', 'transaction_items', 'users')
order by table_name, ordinal_position;
```

Simpan hasil query kedua, khususnya tipe `transactions.id`, `transaction_items.transaction_id`, dan `transaction_items.id`, sebelum menerapkan migrasi `transaction_items`.

## Tabel yang ditulis atau dipakai alur sinkronisasi

| Tabel/koleksi | Operasi dan kolom yang dikirim kode | Bukti migrasi dalam repo | Kepastian / catatan |
|---|---|---|---|
| `users` | SELECT memakai `id`; upsert menyertakan `id`, field `StoreSettings.toMap()` selain `logo_url` dan `qris_image_path`, serta `updated_at`. Field settings mencakup `business_name`, `owner_name`, `phone`, `email`, `login_email`, `address`, `description`, `bank_accounts`, `security_pin`, `lock_analytics_page`, `lock_products_page`, `lock_inventory_page`, `receipt_width`, `receipt_margin`, `use_fast_print`, `printer_auto_cut`, `printer_transport`, `invoice_design`, `print_method`, `invoice_printer_url`, `label_printer_url`, dan seluruh `enable_*`. | Tidak dibuat; beberapa migrasi mengubah `public.users`. | Skema dasar dan tipe kolom berasal dari proyek yang sudah ada dan perlu dicocokkan pada database aktual. `printer_auto_cut` ditambahkan oleh migrasi 20261019135800. |
| `transactions` | Upsert: `id`, `invoice_number`, `customer_id`, `customer_name`, `cashier_name`, `subtotal`, `item_discount_total`, `trans_discount_value`, `trans_discount_type`, `trans_discount_amount`, `tax_rate`, `tax_amount`, `shipping_fee`, `total`, `payment_method`, `amount_paid`, `change_amount`, `notes`, `created_at`, `updated_at`, ditambah `user_id`. SELECT mengambil kolom tabel dan mencoba embed `transaction_items`. | Tidak dibuat di migrasi repo. | Tabel dilaporkan sudah ada di database nyata, tetapi definisi dan tipe kolom belum tersedia dalam repo. |
| `transaction_items` | Upsert: `id`, `transaction_id`, `product_id`, `product_name`, `unit_name`, `conversion_rate`, `quantity`, `cost_price`, `original_price`, `sold_price`, `discount_value`, `discount_type`, `subtotal`, ditambah `user_id`. Penghapusan berdasarkan `id` dan `user_id`. | Tidak ditemukan migrasi pembuat tabel sebelum migrasi baru yang disiapkan pada tahap berikutnya. | **Tabel yang dipakai tetapi tidak dibuat migrasi sebelumnya.** Tipe kolom ID perlu diverifikasi dengan query di atas. |
| `products` | Upsert payload model: `id`, `name`, `category`, `barcode`, `description`, `cost_price`, `base_price`, `base_unit`, `default_unit_name`, `stock`, `image_path`, `financials`, `created_at`, `updated_at`; `units` dikeluarkan sebelum upsert. `user_id` ditambahkan. `image_path` lokal dihapus dari payload. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `product_units` | Upsert anak dari `units`: `id`, `product_id`, `unit_name`, `conversion_rate`, `sell_price`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `purchases` | Upsert payload model: `id`, `invoice_number`, `supplier_id`, `supplier_name`, `staff_name`, `subtotal`, `shipping_fee`, `total`, `payment_method`, `amount_paid`, `payment_status`, `notes`, `created_at`, `updated_at`; `items` dikeluarkan sebelum upsert. `user_id` ditambahkan. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `purchase_items` | Upsert anak dari `items`: `id`, `purchase_id`, `product_id`, `product_name`, `unit_name`, `conversion_rate`, `quantity`, `purchase_price`, `subtotal`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `customers` | `id`, `name`, `phone`, `address`, `notes`, `created_at`, `updated_at`, `is_active`, `total_outstanding`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `debts` | Upsert penuh dapat mengirim `id`, `transaction_id`, `customer_id`, `customer_name`, `invoice_number`, `total_amount`, `paid_amount`, `remaining_balance`, `due_date`, `created_at`, `updated_at`, `status`, `notes`; update pembayaran juga mengirim subset `paid_amount`, `remaining_balance`, `status`, `updated_at`. `user_id` ditambahkan. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `debt_payments` | `id`, `debt_id`, `customer_id`, `amount`, `created_at`, `notes`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `suppliers` | `id`, `name`, `phone`, `address`, `created_at`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `shipping_services` | `id`, `name`, `phone`, `created_at`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `restock_history` | `id`, `product_id`, `product_name`, `quantity_added`, `unit_name`, `supplier_price`, `shipping_cost`, `total_cost_per_unit`, `selling_price`, `supplier_paid_amount`, `shipping_paid_amount`, `supplier_name`, `supplier_payment_status`, `shipping_service_name`, `shipping_payment_status`, `created_at`, `notes`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `bill_payments` | `id`, `bill_id`, `amount`, `notes`, `created_at`, `is_initial_bill`, `is_for_supplier`, ditambah `user_id`. | Tidak dibuat di migrasi repo. | Tipe dan keberadaan kolom belum dapat dipastikan. |
| `barcode_history` | Payload utama `id`, `barcode`, `product_name`, `product_id`, `used_at`, `status`, ditambah `user_id`; jalur kompatibilitas juga mencoba variasi field camelCase. | Dibuat oleh `20260926050000_create_barcode_history_table.sql`. | Kolom snake_case ditetapkan migrasi. Variasi camelCase hanya fallback yang masih ada pada kode. |
| `sync_metadata` | `user_id`, `last_update`, `updated_by_session`. | Tidak dibuat; migrasi hanya mengubah constraint pada tabel tersebut. | Skema dasarnya perlu diverifikasi. |
| `customer_display` | SELECT memakai `user_id`; upsert mengirim `user_id`, `cart_data`, `updated_at`. | Tidak dibuat; migrasi hanya mengubah constraint pada tabel tersebut. | Skema dasar perlu diverifikasi. |
| `subscriptions` | Dibaca oleh subscription repository; migrasi menambahkan kolom subscription. Tidak ada upsert tabel ini pada jalur repository tersebut. | Tidak dibuat di migrasi repo; beberapa migrasi mengubahnya. | Tabel dasar diasumsikan sudah dibuat di luar migrasi repo. |
| `subscription_history` | Dibaca oleh subscription repository; tidak ada upsert klien pada jalur repository tersebut. | Dibuat oleh `20260907044758_create_subscription_history_table.sql`. | Migrasi mendefinisikan kolom, tetapi operasi tulis yang diizinkan adalah service role. |
| `play_purchases` | Tidak ditemukan pada jalur antrean sinkronisasi aplikasi. | Dibuat oleh `20260926060000_create_play_purchases_and_secure_subscriptions.sql`. | Tabel pemrosesan server/Play Billing. |

Selain tabel relasional, produk memakai bucket Storage `products`; itu bukan tabel `public` dan tidak dibahas sebagai tabel SQL.

## Temuan penting

- `transactions` dan `transaction_items` dipakai saat bootstrap, penyimpanan, penghapusan, dan sinkronisasi transaksi. Migrasi repo tidak membuat salah satu tabel tersebut; `transactions` diketahui sudah ada di database nyata, sedangkan `transaction_items` belum memiliki migrasi di repo.
- Kode mengirim ID transaksi sebagai string UUID v4 (`Uuid().v4()`), tetapi ini **tidak membuktikan** tipe kolom `transactions.id` di database. Tipe aktual `transactions.id` dan tipe relasi anak harus diperiksa sebelum migrasi diterapkan.
- Daftar payload menunjukkan kolom yang dikirim kode. Untuk tabel yang tak dibuat migrasi di repo, audit ini **tidak menebak** tipe SQL atau memastikan payload lengkap cocok dengan skema cloud.
- Migrasi repo membuat `subscription_history`, `barcode_history`, dan `play_purchases`. Migrasi lainnya sebagian besar mengubah `users`, `subscriptions`, `sync_metadata`, atau tabel yang diasumsikan sudah tersedia.

## Asumsi migrasi tahap berikutnya

Karena hasil query SQL Editor belum disertakan, migrasi `transaction_items` akan ditulis dengan asumsi kolom kunci bertipe UUID (ID aplikasi dibentuk dari UUID v4). Asumsi ini diberi penanda **MASIH PERLU DIVERIFIKASI** dan harus dicocokkan dengan tipe `transactions.id` dan kolom pada hasil query sebelum menjalankan `supabase db push`.
