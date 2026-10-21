# Audit Kompatibilitas Printer

## Matriks jalur cetak

| Jenis printer | Platform | Pengaturan yang dipakai | Jalur kode | Status verifikasi |
|---|---|---|---|---|
| Thermal ESC/POS Bluetooth | Android | `printerTransport=bluetooth`, `invoicePrinterUrl` berisi alamat MAC, `receiptWidth`, `receiptMargin`, `autoCut`; `printMethod` tidak menentukan jalur Bluetooth langsung | `InvoiceHelper.printInvoice` / `DebtInvoiceHelper.printDebtInvoice` / `PurchaseInvoiceHelper.printInvoice` menuju `printBluetoothReceipt`, lalu `EscPosDriver` dan `BluetoothPrinterService.printReceipt` | Jalur Android terlihat di kode; hasil cetak fisik tetap perlu diuji pada printer yang digunakan |
| Thermal USB | Windows | `printerTransport=usb`, `printMethod=raw`, `invoicePrinterUrl` berisi target spooler, `receiptWidth`, `receiptMargin`, `autoCut` | Helper transaksi/piutang/pembelian membangun bytes ESC/POS lalu memanggil `WindowsRawSpooler.printRaw`; jalur selain `raw` memakai PDF melalui paket `printing` | Cabang kode terverifikasi; perangkat USB dan format alamat target spooler belum diuji fisik |
| Thermal TCP/Wi-Fi | Windows dan Android | `printerTransport=tcp`, `invoicePrinterUrl` berisi host[:port], `invoiceDesign=fast`, `receiptWidth`, `receiptMargin`, `autoCut`; `printMethod=raw` bukan syarat pada cabang TCP | `InvoiceHelper` dan `DebtInvoiceHelper` membangun ESC/POS, lalu `_printRawTcp`; pembelian menggunakan PDF/dialog cetak, tidak memiliki cabang raw TCP | Jalur kode transaksi/piutang terverifikasi; TCP untuk pembelian dan hasil fisik belum didukung/diverifikasi |
| Thermal USB | Android | `printerTransport=usb`; untuk cabang saat ini `printMethod`, `useFastPrint`, `invoiceDesign` dapat membawa ke PDF tetapi tidak membuat koneksi USB ESC/POS | Tidak ada cabang USB Android di helper struk. Alur jatuh ke PDF `directPrintPdf` atau dialog cetak | Tidak dapat diverifikasi sebagai jalur raw USB; tidak ada implementasi raw USB yang ditemukan |
| Printer label ZPL/TSPL Bluetooth | Android | Bahasa label `zpl`/`tspl` disimpan terpisah dari `printerTransport`; `labelPrinterUrl` berisi MAC | `BarcodeManagementPage` → `BluetoothLabelPrintService` → generator ZPL/TSPL → `BluetoothPrinterService.printRaw`; tiap label dikirim sebagai satu job | Jalur kode Android terverifikasi; hasil fisik harus diuji |
| Printer label biasa / PDF | Windows, Android | Bahasa label `pdf`, `labelPrinterUrl` bila printer dipilih; format/ukuran label berasal dari pengaturan label, bukan `receiptWidth` atau `invoiceDesign` | `BarcodeManagementPage` membangun PDF dan memakai `Printing.directPrintPdf`; format gulungan atau A4 dipilih dari layout label | Jalur pemilihan dan pembuatan PDF terlihat; dialog, ukuran media, dan keluaran fisik bergantung pada driver |
| Printer biasa, nota transaksi/piutang | Windows, Android | `printerTransport=pdf` atau tidak memakai jalur native; `useFastPrint=true` memilih direct PDF, selain itu dialog cetak; `invoiceDesign=classic`/`modern`/`fast` memilih desain PDF; `receiptWidth` dan `receiptMargin` diteruskan ke profil | `InvoiceHelper` / `DebtInvoiceHelper` → PDF melalui `PrintOrchestrator`, lalu `Printing.directPrintPdf` atau `Printing.layoutPdf` | Jalur aplikasi terlihat; ketersediaan printer dan perilaku driver berbeda antar perangkat |
| Printer biasa, A4/A5 pembelian | Windows, Android | `invoiceDesign`, `useFastPrint`, `receiptWidth`, `printerTransport`, dan `printMethod` tidak dipakai oleh `printInvoiceA4`; ukuran kertas mengikuti layout dokumen pembelian | `PurchaseInvoiceHelper.printInvoiceA4` membuat A4 PDF lalu memakai `Printing.layoutPdf` | A4 dikodekan; pilihan/hasil A5 tidak terlihat pada jalur helper. Pencetakan A4/A5 pada Android tidak dapat diverifikasi dari kode saja |

## Arti pengaturan yang ditelusuri

- `printerTransport`: nilai `usb`, `bluetooth`, dan `tcp` dipetakan ke transport ESC/POS; nilai lain menjadi PDF. Nilai ini terutama dipakai oleh helper transaksi dan piutang; pembelian punya cabang Android Bluetooth dan Windows raw, sedangkan pembelian A4 tidak memakai transport.
- `printMethod`: `raw` hanya membuka jalur Windows raw spooler pada helper struk transaksi, piutang, dan pembelian. Bluetooth Android ditangani lebih dahulu dan tetap memakai raw ESC/POS; nilai `raw` bukan pengendali jalur itu. Untuk UI, desain `fast` dipilih saat `raw` dipilih.
- `receiptWidth`: menentukan lebar profil ESC/POS/PDF. Driver ESC/POS memakai 32 karakter/384 dot pada lebar sampai 60 mm dan 48 karakter/576 dot di atasnya. Tidak menentukan ukuran invoice pembelian A4.
- `invoiceDesign`: `classic`/`modern` adalah desain PDF. `fast` membuka jalur ESC/POS TCP pada invoice transaksi/piutang; pembelian tidak memeriksa nilai ini.
- `useFastPrint`: memilih PDF langsung tanpa dialog (`true`) atau dialog sistem (`false`) setelah jalur Bluetooth Android, Windows raw, dan TCP fast yang tersedia tidak digunakan. Pengaturan ini tidak dipakai di `PurchaseInvoiceHelper.printInvoiceA4`.

## Batas verifikasi dan rekomendasi

- Tidak ada implementasi USB raw Android pada helper struk yang diaudit. Jangan menganggap opsi USB sebagai dukungan ESC/POS Android sampai ada jalur transport dan uji perangkat.
- TCP raw hanya terlihat untuk invoice transaksi/piutang ketika desain `fast` dipilih. Jalur pembelian dan format alamat selain `host[:port]` belum diverifikasi.
- `printMethod=raw` di UI menyebut dukungan USB/Bluetooth, tetapi implementasi transaksi/piutang/pembelian raw Windows memakai `WindowsRawSpooler`, sedangkan Android raw langsung hanya terlihat untuk Bluetooth dan label.
- Opsi bahasa ZPL/TSPL hanya mencetak langsung lewat Bluetooth Android; pada platform lain pilihan itu menghasilkan PDF. Pertimbangkan label dukungan platform yang lebih jelas.
- A4 dibuat eksplisit untuk PDF pembelian; A5 tidak terlihat dipilih dalam helper yang diaudit. Uji ukuran media lewat dialog/driver, terutama Android.
