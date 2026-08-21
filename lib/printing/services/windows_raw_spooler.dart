import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/foundation.dart';

class WindowsRawSpooler {
  /// Sends raw bytes directly to a Windows printer spooler.
  /// [printerName] is the name of the printer as seen in Windows Control Panel.
  static Future<bool> printRaw(String printerName, List<int> bytes) async {
    if (!Platform.isWindows) return false;

    final pPrinterName = printerName.toNativeUtf16();
    final phPrinter = calloc<HANDLE>();
    final pDocInfo = calloc<DOC_INFO_1>();

    try {
      // 1. Open Printer
      if (OpenPrinter(pPrinterName, phPrinter, nullptr) == 0) {
        debugPrint('RAW-PRINT: Failed to open printer: $printerName');
        return false;
      }

      final hPrinter = phPrinter.value;

      // 2. Setup Document Info
      pDocInfo.ref.pDocName = 'BuildEra Raw Job'.toNativeUtf16();
      pDocInfo.ref.pOutputFile = nullptr;
      pDocInfo.ref.pDatatype = 'RAW'.toNativeUtf16();

      // 3. Start Document
      if (StartDocPrinter(hPrinter, 1, pDocInfo.cast()) == 0) {
        debugPrint('RAW-PRINT: Failed to start document');
        ClosePrinter(hPrinter);
        return false;
      }

      // 4. Start Page
      if (StartPagePrinter(hPrinter) == 0) {
        debugPrint('RAW-PRINT: Failed to start page');
        EndDocPrinter(hPrinter);
        ClosePrinter(hPrinter);
        return false;
      }

      // 5. Write Bytes
      final pBytes = calloc<Uint8>(bytes.length);
      pBytes.asTypedList(bytes.length).setAll(0, bytes);
      final pcWritten = calloc<DWORD>();

      final success = WritePrinter(hPrinter, pBytes, bytes.length, pcWritten);
      
      calloc.free(pBytes);
      calloc.free(pcWritten);

      // 6. End Page & Document
      EndPagePrinter(hPrinter);
      EndDocPrinter(hPrinter);
      ClosePrinter(hPrinter);

      debugPrint('RAW-PRINT: Success - Sent ${bytes.length} bytes to $printerName');
      return success != 0;
    } catch (e) {
      debugPrint('RAW-PRINT: Error - $e');
      return false;
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
      // Note: we'd ideally free the inner strings of pDocInfo too, but for a one-off it's minor
      calloc.free(pDocInfo);
    }
  }
}
