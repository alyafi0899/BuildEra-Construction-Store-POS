// lib/data/hive/hive_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sentinel provider — HiveService is a static class, no instance needed.
// This provider is kept for consistency in case future DI is needed.
final hiveInitializedProvider = Provider<bool>((_) => true);
