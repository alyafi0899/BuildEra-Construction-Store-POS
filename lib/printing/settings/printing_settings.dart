class PrintingSettings {
  final bool enablePreview;
  final bool autoCut;
  final bool useFallbackPdf;

  const PrintingSettings({
    this.enablePreview = true,
    this.autoCut = true,
    this.useFallbackPdf = false,
  });
}
