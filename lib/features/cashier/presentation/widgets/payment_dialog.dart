import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/models/transaction.dart';

import '../../providers/cart_provider.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../../core/utils/invoice_helper.dart';
import '../../../debts/utils/debt_invoice_helper.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../debts/providers/debt_repository.dart';
import '../../../debts/models/customer.dart';
import '../../../debts/models/debt.dart';
import '../../../debts/models/debt_payment.dart';
import '../../../settings/models/store_settings.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context:            context,
        barrierDismissible: true,
        builder:            (_) => const PaymentDialog(),
      );

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  String  _method     = AppConstants.paymentCash;
  final   _amountCtrl = TextEditingController();
  final   _notesCtrl  = TextEditingController();
  final   _shippingFeeCtrl = TextEditingController(text: '0'); // New
  final   ScrollController _scrollController = ScrollController();
  
  // Focus Nodes for Shortcuts
  final _shippingFocus = FocusNode(debugLabel: 'PaymentShippingFocus');
  final _notesFocus = FocusNode(debugLabel: 'PaymentNotesFocus');
  final _payAmountFocus = FocusNode(debugLabel: 'PaymentAmountFocus');

  bool    _processing = false;
  bool    _success    = false;
  Transaction? _tx;

  // Piutang state
  Customer? _selectedCustomer;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  double _paid = 0;

  // Shortcut refinement state
  DateTime? _lastEscPress;
  Timer? _altFocusTimer;
  final _neutralFocusNode = FocusNode(debugLabel: 'PaymentNeutralFocus');

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _shippingFeeCtrl.dispose(); // New
    _scrollController.dispose();
    _shippingFocus.dispose();
    _notesFocus.dispose();
    _payAmountFocus.dispose();
    _neutralFocusNode.dispose();
    _altFocusTimer?.cancel();
    super.dispose();
  }

  double get _shippingFee => double.tryParse(_shippingFeeCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _confirm() async {
    final cart = ref.read(cartProvider);
    final finalTotal = cart.total + _shippingFee;
    
    if (_method == AppConstants.paymentCash && _paid < finalTotal) {
      showError(context, 'Jumlah bayar kurang dari total');
      return;
    }

    if (_method == AppConstants.paymentPiutang) {
      if (_selectedCustomer == null) {
        showError(context, 'Pilih pelanggan untuk transaksi piutang');
        return;
      }
      // For Piutang, we update the cart with customer info before checkout
      ref.read(cartProvider.notifier).setCustomer(_selectedCustomer!.id, _selectedCustomer!.name);
    }

    setState(() => _processing = true);
    try {
      final txId = await ref.read(transactionsActionProvider.notifier).checkout(
        paymentMethod: _method,
        amountPaid:    (_method == AppConstants.paymentCash || _method == AppConstants.paymentPiutang) ? _paid : finalTotal,
        shippingFee:   _shippingFee, // New
        dueDate:       _method == AppConstants.paymentPiutang ? _dueDate : null,
        notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      
      // The transaction is now in the list
      final txList = ref.read(transactionsProvider).asData?.value ?? [];
      final tx     = txList.firstWhereOrNull((t) => t.id == txId);
      
      if (tx == null) throw StateError('Transaction not found');

      setState(() { _success = true; _tx = tx; });
    } catch (e) {
      if (mounted) showError(context, 'Gagal memproses: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    
    // If successful, show success panel without shortcuts to avoid interference
    if (_success) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: SizedBox(
          width: 1200,
          child: _successPanel(context),
        ),
      );
    }

    return Focus(
      autofocus: true,
      debugLabel: 'PaymentFormFocus',
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;

        // 1. Enter to Confirm
        if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
          // If focus is in a multiline field, let it handle Enter normally
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.debugLabel == 'PaymentNotesFocus') {
            return KeyEventResult.ignored;
          }
          _confirm();
          return KeyEventResult.handled;
        }

        // 2. Right Shift for Exact Amount
        if (key == LogicalKeyboardKey.pageDown) {
          final cart = ref.read(cartProvider);
          final total = cart.total + _shippingFee;
          _amountCtrl.text = Formatters.decimal(total);
          setState(() => _paid = total);
          return KeyEventResult.handled;
        }

        // 3. Right Alt to Cycle Payment Methods
        if (key == LogicalKeyboardKey.altRight) {
          final methods = AppConstants.paymentMethods;
          final currentIndex = methods.indexOf(_method);
          final nextIndex = (currentIndex + 1) % methods.length;
          setState(() {
            _method = methods[nextIndex];
            if (_method != AppConstants.paymentCash && _method != AppConstants.paymentPiutang) {
              _amountCtrl.clear();
            }
          });
          
          // Auto neutral focus after 250ms
          _altFocusTimer?.cancel();
          _altFocusTimer = Timer(const Duration(milliseconds: 250), () {
            if (mounted) _neutralFocusNode.requestFocus();
          });

          return KeyEventResult.handled;
        }

        // 4. F1 for Shipping
        if (key == LogicalKeyboardKey.f1) {
          _shippingFocus.requestFocus();
          return KeyEventResult.handled;
        }

        // 5. F2 for Notes
        if (key == LogicalKeyboardKey.f2) {
          _notesFocus.requestFocus();
          return KeyEventResult.handled;
        }

        // 6. Home for Amount
        if (key == LogicalKeyboardKey.pageUp) {
          _payAmountFocus.requestFocus();
          return KeyEventResult.handled;
        }

        // 7. ESC Handling: Single tap to neutralize, Double tap to close
        if (key == LogicalKeyboardKey.escape) {
          final now = DateTime.now();
          if (_lastEscPress != null && 
              now.difference(_lastEscPress!) < const Duration(milliseconds: 500)) {
            // Double tap detected: Close
            if (context.mounted) Navigator.of(context).pop();
          } else {
            // Single tap detected: Neutralize focus
            _neutralFocusNode.requestFocus();
            _lastEscPress = now;
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          // Hidden focus node for neutralization
          Focus(focusNode: _neutralFocusNode, child: const SizedBox.shrink()),
          Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: SizedBox(
              width: 1200, // Increased width for 3-column layout
              child: _formPanel(context, cart),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success ───────────────────────────────────────────────────────────────

  Widget _successPanel(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final tx = _tx!;

    return Focus(
      autofocus: true,
      debugLabel: 'PaymentSuccessFocus',
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;
        
        // 1. Enter to Close
        if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
          // SAFE POP: Ensure context is still valid before popping
          if (context.mounted) Navigator.of(context).pop();
          return KeyEventResult.handled;
        }

        // 2. Shift to Print
        if (key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight) {
          _handlePiutangAction(tx, settings, (c, d, p, s) => DebtInvoiceHelper.printDebtInvoice(c, d, p, s), InvoiceHelper.printInvoice);
          return KeyEventResult.handled;
        }

        // 3. Right Alt to Download
        if (key == LogicalKeyboardKey.altRight) {
          _handlePiutangAction(tx, settings, (c, d, p, s) => DebtInvoiceHelper.downloadDebtInvoice(c, d, p, s), InvoiceHelper.saveInvoice);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 70, height: 70,
            decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Pembayaran Berhasil!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(tx.invoiceNumber, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 32),
          
    // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionBtn(
                icon: Icons.print_rounded, 
                label: 'Print', 
                onTap: () => _handlePiutangAction(tx, settings, (c, d, p, s) => DebtInvoiceHelper.printDebtInvoice(c, d, p, s), InvoiceHelper.printInvoice)
              ),
              const SizedBox(width: 12),
              _ActionBtn(
                icon: Icons.share_rounded, 
                label: 'Share', 
                onTap: () => _handlePiutangAction(tx, settings, (c, d, p, s) async {
                  final pdfBytes = await DebtInvoiceHelper.generateDebtPdf(customer: c, debt: d, payments: p, settings: s);
                  await Printing.sharePdf(bytes: pdfBytes, filename: 'Piutang-${c.name}-${tx.invoiceNumber}.pdf');
                }, InvoiceHelper.shareInvoice)
              ),
              const SizedBox(width: 12),
              _ActionBtn(
                icon: Icons.download_rounded, 
                label: 'Simpan', 
                onTap: () => _handlePiutangAction(tx, settings, (c, d, p, s) => DebtInvoiceHelper.downloadDebtInvoice(c, d, p, s), InvoiceHelper.saveInvoice)
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceAlt, foregroundColor: Colors.white),
              child: const Text('TUTUP'),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _formPanel(BuildContext context, CartState cart) {
    final finalTotal = cart.total + _shippingFee;
    final change = _paid - finalTotal;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Header
      _header(context),

      // Body — 3-column horizontal layout
      Flexible(
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // 1. Column Left: Order Summary
            Expanded(
              flex: 3,
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  child: _orderSummary(context, cart),
                ),
              ),
            ),
            
            const VerticalDivider(width: 1, color: AppTheme.border),

            // 2. Column Middle: Payment Method
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _methodSection(context),
              ),
            ),

            const VerticalDivider(width: 1, color: AppTheme.border),

            // 3. Column Right: Payment Input, Denominations & Suggestions
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _paymentPanel(context, cart, change),
              ),
            ),
          ]),
        ),
      ),

      // Footer
      _footer(context),
    ]);
  }

  Widget _methodSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Metode Pembayaran',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.accent)),
        const SizedBox(height: 16),
        ...AppConstants.paymentMethods.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _methodTileWide(context, m),
        )),
      ],
    );
  }

  Widget _methodTileWide(BuildContext context, String m) {
    final active = _method == m;
    return InkWell(
      onTap: () => setState(() {
        _method = m;
        if (_method != AppConstants.paymentCash && _method != AppConstants.paymentPiutang) {
          _amountCtrl.clear();
        }
      }),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border, width: 1.5),
          boxShadow: active ? [
            BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: active ? Colors.white.withValues(alpha: 0.2) : AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon(m),
                  color: active ? Colors.white : AppTheme.textSecondary,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(m,
                  style: TextStyle(
                    color: active ? Colors.white : AppTheme.textPrimary,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 14,
                  )),
            ),
            if (active)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          const Icon(Icons.payment_rounded, color: AppTheme.accent, size: 22),
          const SizedBox(width: 12),
          Text('Pembayaran', style: Theme.of(context).textTheme.headlineMedium),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppTheme.textMuted),
          ),
        ]),
      );

  Widget _orderSummary(BuildContext context, CartState cart) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ringkasan Order',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppTheme.accent)),
      const SizedBox(height: 12),
      ...cart.items.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.product.name,
                        style:    Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis),
                    if (i.isOverridden)
                      const Text('Harga Override', style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '${Formatters.decimal(i.quantity)} × '
                  '${Formatters.currency(i.soldPrice)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(Formatters.currency(i.subtotal),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 13)),
              ]),
            ]),
          )),
      const Divider(color: AppTheme.border, height: 24),
      _row(context, 'Subtotal Item', Formatters.currency(cart.grossSubtotal)),
      const SizedBox(height: 12),
      ScrollableQtyField(
        controller: _shippingFeeCtrl,
        step: 1000,
        onChanged: (v) => setState(() {}),
        child: TextField(
          controller: _shippingFeeCtrl,
          focusNode: _shippingFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter()],
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Biaya Ongkir (Jika ada)',
            prefixText: 'Rp ',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _confirm(), // Enable enter key to confirm
        ),
      ),
      const SizedBox(height: 12),
      if (cart.itemDiscountTotal > 0)
        _row(context, 'Potongan Item', '− ${Formatters.currency(cart.itemDiscountTotal)}',
            color: AppTheme.success),
      if (cart.transDiscountAmount > 0)
        _row(context, 'Diskon Transaksi', '− ${Formatters.currency(cart.transDiscountAmount)}',
            color: AppTheme.success),
      if (cart.taxEnabled)
        _row(context, 'PPN (11%)', Formatters.currency(cart.taxAmount)),
      const SizedBox(height: 8),
      Row(children: [
        Text('TOTAL',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontSize: 18)),
        const Spacer(),
        Text(Formatters.currency(cart.total + _shippingFee),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.accent,
                  fontSize: 22,
                )),
      ]),
      const SizedBox(height: 16),
      TextField(
        controller: _notesCtrl,
        focusNode: _notesFocus,
        maxLines: 2,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'Keterangan Transaksi',
          hintText: 'Contoh: Nama proyek, nomor PO, dll',
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _paymentPanel(BuildContext context, CartState cart, double change) {
    final settings = ref.watch(settingsProvider);
    final customersAsync = ref.watch(customersProvider);
    final finalTotal = cart.total + _shippingFee;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_method == AppConstants.paymentCash || _method == AppConstants.paymentPiutang) ...[
        if (_method == AppConstants.paymentPiutang) ...[
          // Customer Selection Header with Add Button
          Row(
            children: [
              const Text('Pilih Pelanggan *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showQuickAddCustomer(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Pelanggan Baru', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: customersAsync.when(
              loading: () => const AppLoading(),
              error:   (_, __) => const Text('Gagal memuat data pelanggan'),
              data: (customers) => DropdownButtonFormField<String>(
                initialValue: customers.any((c) => c.id == _selectedCustomer?.id) ? _selectedCustomer?.id : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
                hint: const Text('Pilih dari daftar...', style: TextStyle(fontSize: 13)),
                dropdownColor: AppTheme.surfaceAlt,
                items: customers.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.name} (${c.phone})', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) => setState(() {
                  _selectedCustomer = customers.firstWhereOrNull((c) => c.id == v);
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Due Date Selection
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _dueDate = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Jatuh Tempo *',
                prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
              ),
              child: Text(Formatters.date(_dueDate), style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        ScrollableQtyField(
          controller: _amountCtrl,
          step: 1000,
          onChanged: (v) {
            setState(() => _paid = v);
          },
          child: TextFormField(
            controller:   _amountCtrl,
            focusNode: _payAmountFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            autofocus: true,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize:   28,
                fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              labelText:  _method == AppConstants.paymentPiutang ? 'Jumlah Bayar (DP/Cicilan)' : 'Jumlah Bayar',
              hintText: _method == AppConstants.paymentPiutang ? 'Isi 0 jika belum bayar sama sekali' : 'Ketik nominal bayar...',
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(fontSize: 18, color: AppTheme.textMuted),
            ),
            onChanged: (v) {
              final val = Formatters.parseDecimal(v);
              setState(() => _paid = val);
            },
            onFieldSubmitted: (_) => _confirm(),
          ),
        ),
        
        if (_paid > 0) ...[
          const SizedBox(height: 16),
          // Change / Debt display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_method == AppConstants.paymentCash 
                      ? (change >= 0 ? AppTheme.success : AppTheme.danger)
                      : AppTheme.warning)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (_method == AppConstants.paymentCash 
                          ? (change >= 0 ? AppTheme.success : AppTheme.danger)
                          : AppTheme.warning)
                      .withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Text(_method == AppConstants.paymentCash ? 'Kembalian' : 'Total Piutang',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                _method == AppConstants.paymentCash
                    ? (change >= 0 ? Formatters.currency(change) : '− ${Formatters.currency(-change)}')
                    : Formatters.currency(finalTotal - _paid < 0 ? 0 : finalTotal - _paid),
                style: TextStyle(
                  color: _method == AppConstants.paymentCash
                      ? (change >= 0 ? AppTheme.success : AppTheme.danger)
                      : AppTheme.warning,
                  fontSize:   24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ]),
          ),
        ],

        // Quick cash buttons
        const SizedBox(height: 24),
        const Text('Pecahan Uang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _denomBtn(1000),
            _denomBtn(2000),
            _denomBtn(5000),
            _denomBtn(10000),
            _denomBtn(20000),
            _denomBtn(50000),
            _denomBtn(100000),
            _exactAmountBtn(finalTotal),
          ],
        ),
        
        const SizedBox(height: 24),
        const Text('Saran Nominal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [50000, 100000, 150000, 200000, 500000]
              .where((v) => v >= finalTotal)
              .map((v) => OutlinedButton(
                    onPressed: () {
                      final formatted = Formatters.decimal(v.toDouble());
                      _amountCtrl.text = formatted;
                      setState(() => _paid = v.toDouble());
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: Text(Formatters.currency(v.toDouble()),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ))
              .toList(),
        ),
      ],
      
      if (_method == AppConstants.paymentTransfer) ...[
        // ... (existing transfer panel code, but maybe slightly adjusted for right side)
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accent, size: 22),
                  SizedBox(width: 12),
                  Text('Tujuan Transfer:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 20),
              if (settings.bankAccounts.isEmpty)
                const Text('Belum ada rekening diatur di Pengaturan', 
                  style: TextStyle(color: AppTheme.danger, fontSize: 12, fontStyle: FontStyle.italic))
              else
                ...settings.bankAccounts.map((acc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acc.bankName, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(acc.accountNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text('a/n ${acc.accountHolder}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const Divider(height: 24, color: AppTheme.border),
                    ],
                  ),
                )),
              const Text('Pastikan dana sudah diterima sebelum konfirmasi', 
                style: TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      
      if (_method == AppConstants.paymentQris || _method == AppConstants.paymentDebit)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Container(
            width: double.infinity,
            padding:     const EdgeInsets.all(24),
            decoration:  BoxDecoration(
              color:        AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: AppTheme.border),
            ),
            child: Column(children: [
              if (_method == AppConstants.paymentQris && settings.qrisImagePath != null)
                SizedBox(
                  height: 300,
                  child: AspectRatio(
                    aspectRatio: 5 / 8,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: FutureBuilder<String?>(
                        future: ImageHelper.resolveLocalPath(settings.qrisImagePath),
                        builder: (context, snapshot) {
                          final resolvedPath = snapshot.data;
                          if (resolvedPath != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(File(resolvedPath), fit: BoxFit.cover),
                            );
                          }
                          return Icon(Icons.qr_code_rounded, size: 80, color: AppTheme.textSecondary);
                        },
                      ),
                    ),
                  ),
                )
              else
                Icon(
                  _method == AppConstants.paymentQris
                      ? Icons.qr_code_rounded
                      : Icons.credit_card_rounded,
                  size:  80,
                  color: AppTheme.textSecondary,
                ),
              const SizedBox(height: 16),
              Text(_method == AppConstants.paymentQris
                  ? 'Scan QR untuk membayar'
                  : 'Tap / Insert kartu debit',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(Formatters.currency(finalTotal),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 32)),
            ]),
          ),
        ),
    ]);
  }

  Widget _footer(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal')),
          const Spacer(),
          SizedBox(
            width:  200,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _confirm,
              icon: _processing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_processing ? 'Memproses...' : 'Konfirmasi Bayar'),
            ),
          ),
        ]),
      );

  Widget _row(BuildContext context, String label, String value,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value,
            style: TextStyle(
              color:      color ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }

  IconData _icon(String m) {
    switch (m) {
      case AppConstants.paymentCash:     return Icons.payments_rounded;
      case AppConstants.paymentQris:     return Icons.qr_code_rounded;
      case AppConstants.paymentDebit:    return Icons.credit_card_rounded;
      case AppConstants.paymentTransfer: return Icons.account_balance_rounded;
      default:                           return Icons.payment;
    }
  }

  void _showQuickAddCustomer(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Pelanggan Cepat'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(labelText: 'Nama Lengkap *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor HP *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newCustomer = Customer(
                  id: _uuid.v4(),
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                
                await ref.read(debtRepositoryProvider).saveCustomer(newCustomer);
                setState(() => _selectedCustomer = newCustomer);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Tambah & Pilih'),
          ),
        ],
      ),
    );
  }

  Widget _denomBtn(double amt) {
    return OutlinedButton(
      onPressed: () {
        final current = _paid;
        final newValue = current + amt;
        final formatted = Formatters.decimal(newValue);
        _amountCtrl.text = formatted;
        setState(() => _paid = newValue);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: const BorderSide(color: AppTheme.accent, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(Formatters.currency(amt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _handlePiutangAction(
    Transaction tx, 
    StoreSettings settings, 
    FutureOr<void> Function(Customer, Debt, List<DebtPayment>, StoreSettings) piutangAction,
    FutureOr<void> Function(Transaction, StoreSettings) defaultAction,
  ) async {
    if (tx.paymentMethod != AppConstants.paymentPiutang) {
      await defaultAction(tx, settings);
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
    );

    try {
      final repo = ref.read(debtRepositoryProvider);
      final debts = await repo.getDebts(customerId: tx.customerId);
      final debt = debts.firstWhereOrNull((d) => d.transactionId == tx.id);
      if (debt == null) throw 'Data piutang tidak ditemukan';

      final customer = await _findCustomer(ref, debt.customerId);
      if (customer == null) throw 'Data pelanggan tidak ditemukan';

      final payments = await repo.getPayments(customerId: customer.id, debtId: debt.id);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        await piutangAction(customer, debt, payments, settings);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        showError(context, 'Gagal memproses nota piutang: $e');
        // Fallback to regular invoice
        await defaultAction(tx, settings);
      }
    }
  }

  Future<Customer?> _findCustomer(WidgetRef ref, String customerId) async {
    final customers = await ref.read(customersProvider.future);
    return customers.firstWhereOrNull((c) => c.id == customerId);
  }

  Widget _exactAmountBtn(double total) {
    return ElevatedButton(
      onPressed: () {
        final formatted = Formatters.decimal(total);
        _amountCtrl.text = formatted;
        setState(() => _paid = total);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.success,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Uang Pas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: [
            Icon(icon, color: AppTheme.accent, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
