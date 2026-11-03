import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/store_admin.dart';
import 'store_admins_provider.dart';
import '../../../core/security/pin_hasher.dart';

class ActiveCashierState {
  final String? id; // null for Owner
  final String name;
  final String role; // 'owner' or 'cashier'
  final bool canEditPrice;
  final bool canGiveDiscount;
  final bool canVoid;
  final DateTime? lastActivity;
  final bool isSessionActive;

  const ActiveCashierState({
    this.id,
    required this.name,
    this.role = 'owner',
    this.canEditPrice = true,
    this.canGiveDiscount = true,
    this.canVoid = true,
    this.lastActivity,
    this.isSessionActive = false,
  });

  bool get isOwner => id == null || role == 'owner';

  factory ActiveCashierState.owner(String ownerName) {
    return ActiveCashierState(
      id: null,
      name: ownerName.isEmpty ? 'Pemilik' : ownerName,
      role: 'owner',
      canEditPrice: true,
      canGiveDiscount: true,
      canVoid: true,
      lastActivity: DateTime.now(),
      isSessionActive: true,
    );
  }

  factory ActiveCashierState.admin(StoreAdmin admin) {
    return ActiveCashierState(
      id: admin.id,
      name: admin.name,
      role: admin.role,
      canEditPrice: admin.canEditPrice,
      canGiveDiscount: admin.canGiveDiscount,
      canVoid: admin.canVoid,
      lastActivity: DateTime.now(),
      isSessionActive: true,
    );
  }

  factory ActiveCashierState.inactive(String ownerName) {
    return ActiveCashierState(
      id: null,
      name: ownerName.isEmpty ? 'Pemilik' : ownerName,
      role: 'owner',
      canEditPrice: true,
      canGiveDiscount: true,
      canVoid: true,
      lastActivity: null,
      isSessionActive: false,
    );
  }

  ActiveCashierState copyWith({
    String? id,
    String? name,
    String? role,
    bool? canEditPrice,
    bool? canGiveDiscount,
    bool? canVoid,
    DateTime? lastActivity,
    bool? isSessionActive,
  }) {
    return ActiveCashierState(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      canEditPrice: canEditPrice ?? this.canEditPrice,
      canGiveDiscount: canGiveDiscount ?? this.canGiveDiscount,
      canVoid: canVoid ?? this.canVoid,
      lastActivity: lastActivity ?? this.lastActivity,
      isSessionActive: isSessionActive ?? this.isSessionActive,
    );
  }
}

/// Provider for Idle Timeout in minutes (0 = Off, 15, 30, 60). Default: 30.
final autoLockTimeoutProvider = NotifierProvider<AutoLockTimeoutNotifier, int>(
  AutoLockTimeoutNotifier.new,
);

class AutoLockTimeoutNotifier extends Notifier<int> {
  static const String _prefKey = 'auto_lock_timeout_minutes';

  @override
  int build() {
    _load();
    return 30; // Default 30 minutes
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt(_prefKey) ?? 30;
    } catch (_) {}
  }

  Future<void> setTimeoutMinutes(int minutes) async {
    state = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, minutes);
    } catch (_) {}
  }
}

final activeCashierProvider = NotifierProvider<ActiveCashierNotifier, ActiveCashierState>(
  ActiveCashierNotifier.new,
);

class ActiveCashierNotifier extends Notifier<ActiveCashierState> {
  static const String _attemptsKeyPrefix = 'cashier_wrong_attempts_';
  static const String _lockedUntilKeyPrefix = 'cashier_locked_until_';

  @override
  ActiveCashierState build() {
    final settings = ref.watch(settingsProvider);
    final ownerName = settings.ownerName.isEmpty ? 'Pemilik' : settings.ownerName;
    return ActiveCashierState.inactive(ownerName);
  }

  /// Returns true if multi-cashier mode is active (at least 1 active admin exists)
  bool get isMultiCashierMode {
    final adminsState = ref.read(storeAdminsProvider);
    final admins = adminsState.value ?? [];
    return admins.any((a) => a.isActive);
  }

  void touchActivity() {
    final now = DateTime.now();
    if (!state.isSessionActive) return;

    final timeoutMin = ref.read(autoLockTimeoutProvider);
    if (timeoutMin > 0 && state.lastActivity != null) {
      final diff = now.difference(state.lastActivity!);
      if (diff.inMinutes >= timeoutMin && isMultiCashierMode) {
        endSession();
        return;
      }
    }

    state = state.copyWith(lastActivity: now);
  }

  void endSession() {
    final settings = ref.read(settingsProvider);
    final ownerName = settings.ownerName.isEmpty ? 'Pemilik' : settings.ownerName;
    state = ActiveCashierState.inactive(ownerName);
  }

  Future<Duration?> getRemainingLockout(String targetKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockedUntilMs = prefs.getInt('$_lockedUntilKeyPrefix$targetKey') ?? 0;
      if (lockedUntilMs == 0) return null;

      final lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);
      final now = DateTime.now();
      if (now.isBefore(lockedUntil)) {
        return lockedUntil.difference(now);
      } else {
        // Lockout expired, reset wrong attempts
        await prefs.remove('$_lockedUntilKeyPrefix$targetKey');
        await prefs.remove('$_attemptsKeyPrefix$targetKey');
      }
    } catch (_) {}
    return null;
  }

  Future<void> _recordWrongAttempt(String targetKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentAttempts = (prefs.getInt('$_attemptsKeyPrefix$targetKey') ?? 0) + 1;
      await prefs.setInt('$_attemptsKeyPrefix$targetKey', currentAttempts);

      if (currentAttempts >= 5) {
        // Lockout scaling: 5 attempts = 5 min, 10 attempts = 10 min, 15+ attempts = 15 min
        int lockMinutes = 5;
        if (currentAttempts >= 15) {
          lockMinutes = 15;
        } else if (currentAttempts >= 10) {
          lockMinutes = 10;
        }
        final lockedUntil = DateTime.now().add(Duration(minutes: lockMinutes));
        await prefs.setInt('$_lockedUntilKeyPrefix$targetKey', lockedUntil.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  Future<void> _resetWrongAttempts(String targetKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_attemptsKeyPrefix$targetKey');
      await prefs.remove('$_lockedUntilKeyPrefix$targetKey');
    } catch (_) {}
  }

  /// Verifies PIN and starts session for Owner or StoreAdmin
  Future<bool> verifyAndStartSession({
    StoreAdmin? admin,
    required String pin,
  }) async {
    final targetKey = admin?.id ?? 'owner';

    final lockout = await getRemainingLockout(targetKey);
    if (lockout != null) {
      final minStr = (lockout.inSeconds / 60).ceil();
      throw 'Akun ini terkunci sementara selama $minStr menit karena 5x kesalahan PIN.';
    }

    if (admin == null) {
      // Owner verification
      final settings = ref.read(settingsProvider);
      final correctPin = settings.securityPin;
      if (correctPin == null || correctPin.isEmpty) {
        // Owner has no PIN configured
        state = ActiveCashierState.owner(settings.ownerName);
        await _resetWrongAttempts(targetKey);
        return true;
      }

      if (pin == correctPin) {
        state = ActiveCashierState.owner(settings.ownerName);
        await _resetWrongAttempts(targetKey);
        return true;
      } else {
        await _recordWrongAttempt(targetKey);
        throw 'PIN Pemilik salah';
      }
    } else {
      // Admin verification using PinHasher
      final isValid = await PinHasher.verifyPin(
        pin: pin,
        storedHash: admin.pinHash,
        storedSalt: admin.pinSalt,
        iterations: admin.pinIterations,
      );

      if (isValid) {
        state = ActiveCashierState.admin(admin);
        await _resetWrongAttempts(targetKey);
        return true;
      } else {
        await _recordWrongAttempt(targetKey);
        throw 'PIN Kasir "${admin.name}" salah';
      }
    }
  }
}
