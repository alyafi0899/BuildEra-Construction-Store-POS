enum PrinterTransport {
  escposBluetooth,
  escposUsb,
  escposTcpIp,
  officePdf,
  tspl,
  zpl,
}

class ReceiptLine {
  final String text;
  final bool isBold;
  final bool isCentered;
  final int fontSize;

  const ReceiptLine({
    required this.text,
    this.isBold = false,
    this.isCentered = false,
    this.fontSize = 8,
  });
}

class ReceiptDocument {
  final String title;
  final List<ReceiptLine> lines;
  final String? qrCode;
  final String? barcode;
  final Map<String, dynamic> metadata;

  const ReceiptDocument({
    required this.title,
    required this.lines,
    this.qrCode,
    this.barcode,
    this.metadata = const {},
  });
}

class LabelLine {
  final String text;
  final bool isBold;
  final bool isCentered;
  final int fontSize;

  const LabelLine({
    required this.text,
    this.isBold = false,
    this.isCentered = false,
    this.fontSize = 8,
  });
}

class LabelDocument {
  final String title;
  final List<LabelLine> lines;
  final String? barcode;
  final Map<String, dynamic> metadata;

  const LabelDocument({
    required this.title,
    required this.lines,
    this.barcode,
    this.metadata = const {},
  });
}

class PrintResult {
  final bool success;
  final String message;
  final String? payload;
  final List<int>? bytes;
  final String? previewText;

  const PrintResult({
    required this.success,
    required this.message,
    this.payload,
    this.bytes,
    this.previewText,
  });
}
