import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/utils/trusted_time_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../config/entitlement_config.dart';

class BonusQuotaState {
  final DateTime? grantedAtUtc;
  final DateTime? expiresAtUtc;
  final int amount;
  final int rewardsClaimedToday;
  final String? lastClaimedJakartaDate;

  const BonusQuotaState({
    this.grantedAtUtc,
    this.expiresAtUtc,
    this.amount = 0,
    this.rewardsClaimedToday = 0,
    this.lastClaimedJakartaDate,
  });

  bool get isActive {
    if (expiresAtUtc == null || amount <= 0) return false;
    final nowUtc = TrustedTimeHelper.nowUtc();
    return nowUtc.isBefore(expiresAtUtc!);
  }

  int get activeBonusAmount => isActive ? amount : 0;

  Map<String, dynamic> toMap() => {
        'granted_at_utc': grantedAtUtc?.toIso8601String(),
        'expires_at_utc': expiresAtUtc?.toIso8601String(),
        'amount': amount,
        'rewards_claimed_today': rewardsClaimedToday,
        'last_claimed_jakarta_date': lastClaimedJakartaDate,
      };

  factory BonusQuotaState.fromMap(Map<String, dynamic> map) {
    return BonusQuotaState(
      grantedAtUtc: map['granted_at_utc'] != null ? DateTime.tryParse(map['granted_at_utc'].toString()) : null,
      expiresAtUtc: map['expires_at_utc'] != null ? DateTime.tryParse(map['expires_at_utc'].toString()) : null,
      amount: (map['amount'] as num? ?? 0).toInt(),
      rewardsClaimedToday: (map['rewards_claimed_today'] as num? ?? 0).toInt(),
      lastClaimedJakartaDate: map['last_claimed_jakarta_date']?.toString(),
    );
  }
}

final bonusQuotaProvider = NotifierProvider<BonusQuotaNotifier, BonusQuotaState>(
  BonusQuotaNotifier.new,
);

class BonusQuotaNotifier extends Notifier<BonusQuotaState> {
  Timer? _expirationTimer;

  @override
  BonusQuotaState build() {
    _loadState();
    return const BonusQuotaState();
  }

  String _getTodayJakartaDateString() {
    final nowJ = TrustedTimeHelper.nowJakarta();
    return '${nowJ.year}-${nowJ.month.toString().padLeft(2, '0')}-${nowJ.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadState() async {
    final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
    if (uid == null) return;

    try {
      final box = await LocalDatabase.openBox(uid, 'metadata');
      final raw = box.get('bonus_quota_state');
      if (raw != null && raw is Map) {
        final data = LocalDatabase.sanitize(Map<String, dynamic>.from(raw));
        var loaded = BonusQuotaState.fromMap(data);

        // Check if calendar day changed in Jakarta
        final todayStr = _getTodayJakartaDateString();
        if (loaded.lastClaimedJakartaDate != todayStr) {
          loaded = BonusQuotaState(
            grantedAtUtc: loaded.grantedAtUtc,
            expiresAtUtc: loaded.expiresAtUtc,
            amount: loaded.amount,
            rewardsClaimedToday: 0,
            lastClaimedJakartaDate: todayStr,
          );
        }

        state = loaded;
        _scheduleExpirationCheck();
      }
    } catch (e) {
      debugPrint('BonusQuotaNotifier load error: $e');
    }
  }

  Future<void> _saveState(BonusQuotaState newState) async {
    state = newState;
    _scheduleExpirationCheck();

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    try {
      final box = await LocalDatabase.openBox(uid, 'metadata');
      await box.put('bonus_quota_state', newState.toMap());
    } catch (e) {
      debugPrint('BonusQuotaNotifier save error: $e');
    }
  }

  void _scheduleExpirationCheck() {
    _expirationTimer?.cancel();
    if (state.expiresAtUtc == null) return;

    final nowUtc = TrustedTimeHelper.nowUtc();
    final remaining = state.expiresAtUtc!.difference(nowUtc);
    if (remaining.isNegative) {
      state = BonusQuotaState(
        grantedAtUtc: null,
        expiresAtUtc: null,
        amount: 0,
        rewardsClaimedToday: state.rewardsClaimedToday,
        lastClaimedJakartaDate: state.lastClaimedJakartaDate,
      );
    } else {
      _expirationTimer = Timer(remaining, () {
        state = BonusQuotaState(
          grantedAtUtc: null,
          expiresAtUtc: null,
          amount: 0,
          rewardsClaimedToday: state.rewardsClaimedToday,
          lastClaimedJakartaDate: state.lastClaimedJakartaDate,
        );
      });
    }
  }

  bool canClaimReward() {
    if (state.isActive) return false; // Already has an active bonus
    final todayStr = _getTodayJakartaDateString();
    final claimedToday = state.lastClaimedJakartaDate == todayStr ? state.rewardsClaimedToday : 0;
    return claimedToday < EntitlementConfig.maxRewardsPerDay;
  }

  Future<bool> grantRewardBonus() async {
    if (!canClaimReward()) return false;

    final nowUtc = TrustedTimeHelper.nowUtc();
    final expiresAt = nowUtc.add(EntitlementConfig.rewardBonusDuration);
    final todayStr = _getTodayJakartaDateString();
    final currentClaimed = state.lastClaimedJakartaDate == todayStr ? state.rewardsClaimedToday : 0;

    final newState = BonusQuotaState(
      grantedAtUtc: nowUtc,
      expiresAtUtc: expiresAt,
      amount: EntitlementConfig.rewardBonusTransactions,
      rewardsClaimedToday: currentClaimed + 1,
      lastClaimedJakartaDate: todayStr,
    );

    await _saveState(newState);
    return true;
  }
}
