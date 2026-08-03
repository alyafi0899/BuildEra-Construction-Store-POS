import 'package:flutter/widgets.dart';

// Cashier Page Intents
class EscFocusIntent extends Intent { const EscFocusIntent(); }
class FocusQtyIntent extends Intent { const FocusQtyIntent(); }
class FocusPriceIntent extends Intent { const FocusPriceIntent(); }
class FocusItemDiscIntent extends Intent { const FocusItemDiscIntent(); }
class FocusTransDiscIntent extends Intent { const FocusTransDiscIntent(); }
class FocusCustomerIntent extends Intent { const FocusCustomerIntent(); }
class ToggleTaxIntent extends Intent { const ToggleTaxIntent(); }
class OpenPaymentIntent extends Intent { const OpenPaymentIntent(); }

// Payment Dialog Intents
class ConfirmPaymentIntent extends Intent { const ConfirmPaymentIntent(); }
class ExactAmountIntent extends Intent { const ExactAmountIntent(); }
class FocusShippingIntent extends Intent { const FocusShippingIntent(); }
class FocusNotesIntent extends Intent { const FocusNotesIntent(); }
class FocusPayAmountIntent extends Intent { const FocusPayAmountIntent(); }

// Success Dialog Intents
class PrintInvoiceIntent extends Intent { const PrintInvoiceIntent(); }
class DownloadInvoiceIntent extends Intent { const DownloadInvoiceIntent(); }
class CloseSuccessDialogIntent extends Intent { const CloseSuccessDialogIntent(); }
