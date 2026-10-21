# Checklist Uji Fisik Printer BuildEra

Jalankan langkah berikut sesuai urutan. Jangan menganggap koneksi Bluetooth berhasil sebagai bukti data sudah tercetak. Catat perangkat, OS, model printer, koneksi, lebar kertas, dan hasil setiap pengujian.

## Urutan uji wajib

1. [ ] Pastikan migrasi `printer_auto_cut` dan `transaction_items` sudah diterapkan dengan `supabase db push`. Sebelum menerapkan migrasi `transaction_items`, cocokkan tipe `transactions.id` dengan asumsi UUID dalam migrasi. Pastikan kolom pengaturan printer (`printer_auto_cut`, `printer_transport`, dan kolom `printer_*` lain yang dipakai aplikasi) tersedia pada `public.users`.
2. [ ] Pilih koneksi Bluetooth dan printer di BuildEra, simpan gambar QRIS, tutup lalu buka ulang aplikasi, dan pastikan pilihan printer tetap tersimpan. Ini memverifikasi persistensi pengaturan printer.
3. [ ] Cetak struk berurutan: tunai terlebih dahulu, lalu transfer/debit, kemudian QRIS, dan terakhir piutang.
4. [ ] Bila cetak macet, matikan lalu nyalakan printer kembali, sambungkan ulang, lalu ganti **Mode gambar** dan ulangi cetak.
5. [ ] Jalankan **Cetak Uji Gambar** dari BuildEra.
6. [ ] Pindai QR dari hasil cetak menggunakan aplikasi pembayaran dan pastikan QR dapat dibaca.
7. [ ] Setelah migrasi `transaction_items` diterapkan, periksa log dan pastikan tidak ada error `PGRST205`.

## Persiapan perangkat

- [ ] Tutup aplikasi lain yang sedang memakai printer Bluetooth (misalnya Thermer).
- [ ] Pastikan printer menyala, kertas terpasang, dan berada dekat ponsel/komputer.
- [ ] Pair printer dari pengaturan Bluetooth Android; coba PIN `0000` atau `1234` bila diminta.
- [ ] Izinkan BuildEra memakai izin **Perangkat sekitar** pada Android.
- [ ] Cetak uji dari BuildEra sesuai langkah 5 di atas.

| Perangkat / OS | Model printer | Koneksi | Kertas | Hasil awal / catatan |
|---|---|---|---|---|
|  |  |  |  |  |

## Skenario struk

Jalankan skenario pada kertas 58 mm dan 80 mm, dengan urutan yang ditetapkan pada langkah 3:

- [ ] Tunai: item, harga, qty, total, tanggal, nomor struk, kasir, nama toko/alamat, dan waktu cetak terbaca.
- [ ] Debit dan Transfer Bank: daftar rekening toko tercetak.
- [ ] QRIS: teks petunjuk dan gambar QR tercetak.
- [ ] Piutang: judul tagihan, tanggal dibuat, jumlah dibayar, sisa, rekening, QRIS, riwayat pembayaran, dan footer terbaca.
- [ ] Logo tercetak dengan jelas dan tidak terlalu besar/terpotong.
- [ ] Nama produk yang memuat tanda hubung panjang dan kutip melengkung tercetak dengan karakter pengganti yang wajar.
- [ ] Cetak struk dengan 30 item atau lebih; pastikan tidak ada bagian yang hilang atau terpotong.
- [ ] Uji AutoCut aktif dan pastikan kertas terpotong setelah struk selesai.
- [ ] Uji AutoCut nonaktif dan pastikan printer tidak menerima perintah potong otomatis.

## Kegagalan dan pemulihan

- [ ] Matikan printer saat pengiriman cetak berlangsung; BuildEra harus menampilkan pesan gagal yang jelas, bukan laporan berhasil.
- [ ] Bila macet, ikuti langkah 4 pada urutan wajib: nyalakan ulang printer, sambungkan ulang, ganti Mode gambar, lalu uji cetak kembali.
- [ ] Pastikan aplikasi lain tidak mengambil koneksi Bluetooth selama pengiriman.

## Printer label

- [ ] Pilih printer label Bluetooth dan cetak uji dalam bahasa ZPL.
- [ ] Cetak uji dalam bahasa TSPL.
- [ ] Pastikan nama produk, barcode, harga, dan batas ukuran label sesuai.
- [ ] Pastikan beberapa label dicetak sebagai job terpisah tanpa tertukar atau terpotong.

## Hasil pengujian

| Skenario | 58 mm | 80 mm | Catatan / tindakan |
|---|---|---|---|
| Persistensi pengaturan printer setelah aplikasi dibuka ulang |  |  |  |
| Cetak uji gambar |  |  |  |
| Tunai |  |  |  |
| Debit / Transfer Bank |  |  |  |
| QRIS dapat dipindai |  |  |  |
| Piutang |  |  |  |
| Logo |  |  |  |
| 30+ item |  |  |  |
| AutoCut aktif / nonaktif |  |  |  |
| Printer dimatikan saat cetak |  |  |  |
| Label ZPL / TSPL |  |  |  |
| Tidak ada PGRST205 setelah migrasi |  |  |  |
