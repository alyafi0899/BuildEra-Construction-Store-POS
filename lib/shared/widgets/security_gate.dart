import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// FOR ANDROID MANAGER VERSION: All security gates are disabled to streamline management.
final pinUnlockProvider = Provider<bool>((ref) => true);

void requirePin(BuildContext context, WidgetRef ref, VoidCallback onSuccess) {
  onSuccess(); // Always succeed
}

class PinGate extends StatelessWidget {
  final Widget child;
  const PinGate({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class BlurGate extends StatelessWidget {
  final Widget child;
  const BlurGate({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
