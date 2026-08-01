import 'print_document.dart';

class PrinterProfile {
  final String id;
  final String name;
  final PrinterTransport transport;
  final String? address;
  final double paperWidthMm;
  final double paperHeightMm;
  final double marginMm;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> defaults;

  const PrinterProfile({
    required this.id,
    required this.name,
    required this.transport,
    this.address,
    this.paperWidthMm = 80,
    this.paperHeightMm = 0,
    this.marginMm = 2,
    this.capabilities = const {},
    this.defaults = const {},
  });
}
