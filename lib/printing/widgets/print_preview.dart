import 'package:flutter/material.dart';
import '../models/label_template.dart';
import '../models/print_document.dart';
import '../services/preview_service.dart';

class PrintPreviewWidget extends StatelessWidget {
  final ReceiptDocument? receipt;
  final LabelDocument? label;
  final LabelTemplateSettings? settings;

  const PrintPreviewWidget(
      {super.key, this.receipt, this.label, this.settings});

  @override
  Widget build(BuildContext context) {
    final preview = switch ((receipt != null, label != null)) {
      (true, false) => PreviewService().renderReceiptPreview(receipt!),
      (false, true) => PreviewService().renderLabelPreview(
          label!, settings ?? const LabelTemplateSettings()),
      _ => 'No preview content',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SelectableText(preview),
    );
  }
}
