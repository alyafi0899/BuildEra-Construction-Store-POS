class LabelTemplateSettings {
  final String templateId;
  final double paperWidthMm;
  final double paperHeightMm;
  final double paperMarginMm;
  final double labelWidthMm;
  final double labelHeightMm;
  final double horizontalGapMm;
  final double verticalGapMm;
  final double labelPaddingMm;
  final int columns;
  final double barcodeWidthMm;
  final double barcodeHeightMm;
  final double storeNameFontSize;
  final double productNameFontSize;
  final double barcodeNumberFontSize;
  final double priceFontSize;

  const LabelTemplateSettings({
    this.templateId = 'default',
    this.paperWidthMm = 210,
    this.paperHeightMm = 297,
    this.paperMarginMm = 10,
    this.labelWidthMm = 40,
    this.labelHeightMm = 30,
    this.horizontalGapMm = 2,
    this.verticalGapMm = 2,
    this.labelPaddingMm = 2,
    this.columns = 4,
    this.barcodeWidthMm = 35,
    this.barcodeHeightMm = 12,
    this.storeNameFontSize = 7,
    this.productNameFontSize = 8,
    this.barcodeNumberFontSize = 6,
    this.priceFontSize = 8,
  });
}
