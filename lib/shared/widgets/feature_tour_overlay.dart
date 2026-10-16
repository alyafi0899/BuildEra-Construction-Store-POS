import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/feature_tour_provider.dart';

class TourStep {
  final String title;
  final String description;
  final IconData? icon;

  const TourStep({
    required this.title,
    required this.description,
    this.icon,
  });
}

class FeatureTourOverlay extends ConsumerStatefulWidget {
  final Widget child;
  final String tourKey;
  final List<TourStep> steps;

  const FeatureTourOverlay({
    super.key,
    required this.child,
    required this.tourKey,
    required this.steps,
  });

  @override
  ConsumerState<FeatureTourOverlay> createState() => _FeatureTourOverlayState();
}

class _FeatureTourOverlayState extends ConsumerState<FeatureTourOverlay> {
  int _currentStep = 0;
  bool _dismissedThisSession = false;

  @override
  Widget build(BuildContext context) {
    final tourState = ref.watch(featureTourProvider);

    bool isTourDone = false;
    switch (widget.tourKey) {
      case 'cashier':
        isTourDone = tourState.tourCashierDone;
        break;
      case 'payment':
        isTourDone = tourState.tourPaymentDone;
        break;
      case 'products':
        isTourDone = tourState.tourProductsDone;
        break;
      case 'debts':
        isTourDone = tourState.tourDebtsDone;
        break;
      case 'bills':
        isTourDone = tourState.tourBillsDone;
        break;
      case 'settings':
        isTourDone = tourState.tourSettingsDone;
        break;
    }

    if (isTourDone || tourState.isAllSkipped || _dismissedThisSession || widget.steps.isEmpty) {
      return widget.child;
    }

    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;

    return Stack(
      children: [
        widget.child,

        // Semi-transparent backdrop overlay
        Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: 0.78),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Tour Card Dialog Box
                    Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  step.icon ?? Icons.tips_and_updates_rounded,
                                  color: AppTheme.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PANDUAN FITUR (${_currentStep + 1}/${widget.steps.length})',
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      step.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            step.description,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Step Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(widget.steps.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: index == _currentStep ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: index == _currentStep
                                      ? AppTheme.accent
                                      : AppTheme.border,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(featureTourProvider.notifier)
                                      .skipAllTours();
                                  setState(() => _dismissedThisSession = true);
                                },
                                child: const Text(
                                  'LEWATI TOUR',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () {
                                  if (isLast) {
                                    ref
                                        .read(featureTourProvider.notifier)
                                        .markTourDone(widget.tourKey);
                                    setState(() => _dismissedThisSession = true);
                                  } else {
                                    setState(() => _currentStep++);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isLast ? 'SELESAI' : 'LANJUT',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
