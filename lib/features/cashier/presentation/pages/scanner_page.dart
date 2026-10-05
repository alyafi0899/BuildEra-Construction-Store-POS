import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/cart_provider.dart';
import '../../providers/scanner_controller.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    Future.microtask(
        () => ref.read(scannerControllerProvider.notifier).reset());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _scannerController.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _scannerController.stop();
        break;
      default:
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null) {
        final result = ref
            .read(scannerControllerProvider.notifier)
            .onBarcodeScanned(code);

        if (result == ScanResult.added) {
          // Success feedback: audio + haptic
          HapticFeedback.lightImpact();
          SystemSound.play(SystemSoundType.click);
        } else if (result == ScanResult.notFound) {
          // Failure feedback
          HapticFeedback.heavyImpact();
          _showNotFoundSnackbar(code);
        }
      }
    }
  }

  void _showNotFoundSnackbar(String code) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Produk dengan barcode $code tidak ditemukan.'),
        backgroundColor: AppTheme.danger,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget buildCameraPanel({required bool isPortrait}) {
      return Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              if (error.errorCode ==
                  MobileScannerErrorCode.permissionDenied) {
                return _PermissionDeniedView(
                    onRetry: () => _scannerController.start());
              }
              return _ErrorView(
                  error: error.errorDetails?.message ?? 'Kesalahan kamera',
                  onRetry: () => _scannerController.start());
            },
          ),
          // Aim reticle overlay
          _ScannerOverlay(isPortrait: isPortrait),
          // Top Controls Bar (Back, Torch, Switch Camera)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      tooltip: 'Kembali ke Kasir',
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        await _scannerController.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                      icon: Icon(
                        _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isTorchOn ? Colors.amber : Colors.white,
                      ),
                      tooltip: 'Senter Kamera',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => _scannerController.switchCamera(),
                      icon: const Icon(Icons.cameraswitch_rounded,
                          color: Colors.white),
                      tooltip: 'Ganti Kamera',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxWidth < 700 ||
              constraints.maxHeight > constraints.maxWidth;

          if (isPortrait) {
            return Column(
              children: [
                // Top 50%: Camera preview
                Expanded(
                  flex: 1,
                  child: buildCameraPanel(isPortrait: true),
                ),
                // Bottom 50%: Scanned Cart List & Actions
                const Expanded(
                  flex: 1,
                  child: _ScannerCartPanel(),
                ),
              ],
            );
          }

          return Row(
            children: [
              // Left 50%: Camera preview
              Expanded(
                flex: 1,
                child: buildCameraPanel(isPortrait: false),
              ),
              // Right 50%: Scanned Cart List & Actions
              const Expanded(
                flex: 1,
                child: _ScannerCartPanel(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScannerCartPanel extends ConsumerWidget {
  const _ScannerCartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_rounded,
                    color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                const Text('Hasil Scan',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                if (cart.itemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${cart.itemCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                const Spacer(),
                if (!cart.isEmpty)
                  TextButton.icon(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Kosongkan',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded,
                              size: 40, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text('Belum ada produk di-scan',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary)),
                          SizedBox(height: 4),
                          Text('Arahkan kamera ke barcode / QR produk',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                    Formatters.currency(item.soldPrice),
                                    style: const TextStyle(
                                        fontSize: 11, color: AppTheme.accent),
                                  ),
                                ],
                              ),
                            ),
                            // Qty controls
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(
                                          item.id, item.quantity - 1),
                                  icon: const Icon(Icons.remove_circle_outline,
                                      size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    Formatters.decimal(item.quantity),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(
                                          item.id, item.quantity + 1),
                                  icon: const Icon(Icons.add_circle_outline,
                                      size: 20, color: AppTheme.accent),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // Delete item
                            IconButton(
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .removeItem(item.id),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppTheme.danger),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Total & Primary Action Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL (${cart.itemCount} Item)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            fontSize: 11)),
                    Text(Formatters.currency(cart.total),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accent,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                    label: const Text('PROSES / LIHAT KERANJANG'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final bool isPortrait;
  const _ScannerOverlay({required this.isPortrait});

  @override
  Widget build(BuildContext context) {
    final boxWidth = isPortrait ? 260.0 : 360.0;
    final boxHeight = isPortrait ? 180.0 : 220.0;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.45), BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  height: boxHeight,
                  width: boxWidth,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            height: boxHeight,
            width: boxWidth,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Aim reticle center crosshair indicator
                Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.6),
                          width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: isPortrait ? 12 : 24,
          left: 0,
          right: 0,
          child: const Column(
            children: [
              Text(
                'Arahkan Barcode / QR ke Kotak Tengah',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              ),
              SizedBox(height: 2),
              Text(
                'Scan berjalan otomatis terus-menerus',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionDeniedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_rounded,
              size: 56, color: AppTheme.danger),
          const SizedBox(height: 16),
          const Text('Izin Kamera Ditolak',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Mohon berikan izin kamera untuk menggunakan scanner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: AppTheme.danger),
          const SizedBox(height: 16),
          const Text('Kamera Gagal Dimulai',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
