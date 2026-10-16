import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureTourState {
  final bool isLanguageSelected;
  final bool tourCashierDone;
  final bool tourPaymentDone;
  final bool tourProductsDone;
  final bool tourDebtsDone;
  final bool tourBillsDone;
  final bool tourSettingsDone;
  final bool isAllSkipped;

  const FeatureTourState({
    this.isLanguageSelected = false,
    this.tourCashierDone = false,
    this.tourPaymentDone = false,
    this.tourProductsDone = false,
    this.tourDebtsDone = false,
    this.tourBillsDone = false,
    this.tourSettingsDone = false,
    this.isAllSkipped = false,
  });

  FeatureTourState copyWith({
    bool? isLanguageSelected,
    bool? tourCashierDone,
    bool? tourPaymentDone,
    bool? tourProductsDone,
    bool? tourDebtsDone,
    bool? tourBillsDone,
    bool? tourSettingsDone,
    bool? isAllSkipped,
  }) {
    return FeatureTourState(
      isLanguageSelected: isLanguageSelected ?? this.isLanguageSelected,
      tourCashierDone: tourCashierDone ?? this.tourCashierDone,
      tourPaymentDone: tourPaymentDone ?? this.tourPaymentDone,
      tourProductsDone: tourProductsDone ?? this.tourProductsDone,
      tourDebtsDone: tourDebtsDone ?? this.tourDebtsDone,
      tourBillsDone: tourBillsDone ?? this.tourBillsDone,
      tourSettingsDone: tourSettingsDone ?? this.tourSettingsDone,
      isAllSkipped: isAllSkipped ?? this.isAllSkipped,
    );
  }
}

final featureTourProvider =
    NotifierProvider<FeatureTourNotifier, FeatureTourState>(
        FeatureTourNotifier.new);

class FeatureTourNotifier extends Notifier<FeatureTourState> {
  static const _keyLangSelected = 'tour_language_selected';
  static const _keyCashier = 'tour_cashier_done';
  static const _keyPayment = 'tour_payment_done';
  static const _keyProducts = 'tour_products_done';
  static const _keyDebts = 'tour_debts_done';
  static const _keyBills = 'tour_bills_done';
  static const _keySettings = 'tour_settings_done';
  static const _keySkippedAll = 'tour_all_skipped';

  @override
  FeatureTourState build() {
    _loadState();
    return const FeatureTourState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = FeatureTourState(
      isLanguageSelected: prefs.getBool(_keyLangSelected) ?? false,
      tourCashierDone: prefs.getBool(_keyCashier) ?? false,
      tourPaymentDone: prefs.getBool(_keyPayment) ?? false,
      tourProductsDone: prefs.getBool(_keyProducts) ?? false,
      tourDebtsDone: prefs.getBool(_keyDebts) ?? false,
      tourBillsDone: prefs.getBool(_keyBills) ?? false,
      tourSettingsDone: prefs.getBool(_keySettings) ?? false,
      isAllSkipped: prefs.getBool(_keySkippedAll) ?? false,
    );
  }

  Future<void> markLanguageSelected() async {
    state = state.copyWith(isLanguageSelected: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLangSelected, true);
  }

  Future<void> markTourDone(String tourKey) async {
    final prefs = await SharedPreferences.getInstance();
    switch (tourKey) {
      case 'cashier':
        state = state.copyWith(tourCashierDone: true);
        await prefs.setBool(_keyCashier, true);
        break;
      case 'payment':
        state = state.copyWith(tourPaymentDone: true);
        await prefs.setBool(_keyPayment, true);
        break;
      case 'products':
        state = state.copyWith(tourProductsDone: true);
        await prefs.setBool(_keyProducts, true);
        break;
      case 'debts':
        state = state.copyWith(tourDebtsDone: true);
        await prefs.setBool(_keyDebts, true);
        break;
      case 'bills':
        state = state.copyWith(tourBillsDone: true);
        await prefs.setBool(_keyBills, true);
        break;
      case 'settings':
        state = state.copyWith(tourSettingsDone: true);
        await prefs.setBool(_keySettings, true);
        break;
    }
  }

  Future<void> skipAllTours() async {
    state = state.copyWith(
      tourCashierDone: true,
      tourPaymentDone: true,
      tourProductsDone: true,
      tourDebtsDone: true,
      tourBillsDone: true,
      tourSettingsDone: true,
      isAllSkipped: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCashier, true);
    await prefs.setBool(_keyPayment, true);
    await prefs.setBool(_keyProducts, true);
    await prefs.setBool(_keyDebts, true);
    await prefs.setBool(_keyBills, true);
    await prefs.setBool(_keySettings, true);
    await prefs.setBool(_keySkippedAll, true);
  }

  Future<void> resetTours() async {
    state = const FeatureTourState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLangSelected);
    await prefs.remove(_keyCashier);
    await prefs.remove(_keyPayment);
    await prefs.remove(_keyProducts);
    await prefs.remove(_keyDebts);
    await prefs.remove(_keyBills);
    await prefs.remove(_keySettings);
    await prefs.remove(_keySkippedAll);
  }
}
