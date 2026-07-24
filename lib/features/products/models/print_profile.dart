class PrintProfile {
  final String id;
  final String name;
  final double paperWidth;
  final double paperHeight;
  final double labelWidth;
  final double labelHeight;
  final double barcodeHeight;
  final double paperMargin;
  final double labelMargin;
  final double labelPadding;
  final int columnCount;
  final double fontSizeName;
  final double fontSizeBarcode;
  final double fontSizePrice;
  final double fontSizeStoreName; // New field
  final double barcodeWidth;
  final bool isRollMode;

  PrintProfile({
    required this.id,
    required this.name,
    this.paperWidth = 210,
    this.paperHeight = 297,
    this.labelWidth = 40,
    this.labelHeight = 30,
    this.barcodeHeight = 12,
    this.barcodeWidth = 35,
    this.paperMargin = 10,
    this.labelMargin = 2,
    this.labelPadding = 2,
    this.columnCount = 4,
    this.fontSizeName = 8,
    this.fontSizeBarcode = 7,
    this.fontSizePrice = 8,
    this.fontSizeStoreName = 7,
    this.isRollMode = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'paper_width': paperWidth,
        'paper_height': paperHeight,
        'label_width': labelWidth,
        'label_height': labelHeight,
        'barcode_height': barcodeHeight,
        'barcode_width': barcodeWidth,
        'paper_margin': paperMargin,
        'label_margin': labelMargin,
        'label_padding': labelPadding,
        'column_count': columnCount,
        'font_size_name': fontSizeName,
        'font_size_barcode': fontSizeBarcode,
        'font_size_price': fontSizePrice,
        'font_size_store_name': fontSizeStoreName,
        'is_roll_mode': isRollMode,
      };

  factory PrintProfile.fromMap(Map<String, dynamic> m) => PrintProfile(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        paperWidth: (m['paper_width'] ?? 210).toDouble(),
        paperHeight: (m['paper_height'] ?? 297).toDouble(),
        labelWidth: (m['label_width'] ?? 40).toDouble(),
        labelHeight: (m['label_height'] ?? 30).toDouble(),
        barcodeHeight: (m['barcode_height'] ?? 12).toDouble(),
        barcodeWidth: (m['barcode_width'] ?? 35).toDouble(),
        paperMargin: (m['paper_margin'] ?? 10).toDouble(),
        labelMargin: (m['label_margin'] ?? 2).toDouble(),
        labelPadding: (m['label_padding'] ?? 2).toDouble(),
        columnCount: (m['column_count'] ?? 4).toInt(),
        fontSizeName: (m['font_size_name'] ?? 8).toDouble(),
        fontSizeBarcode: (m['font_size_barcode'] ?? 7).toDouble(),
        fontSizePrice: (m['font_size_price'] ?? 8).toDouble(),
        fontSizeStoreName: (m['font_size_store_name'] ?? 7).toDouble(),
        isRollMode: m['is_roll_mode'] ?? false,
      );
}
