import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppPageIndices {
  AppPageIndices._();

  static const int cashier = 0;
  static const int products = 1;
  static const int transactions = 2;
  static const int debts = 3;
  static const int customers = 4;
  static const int analytics = 5;
  static const int barcodes = 6;
  static const int settings = 7;
  static const int bills = 8;
  static const int customerDisplay = 9;
  static const int purchase = 10;
  static const int purchaseHistory = 11;
  static const int home = 12;
}

class NavigationNotifier extends Notifier<int> {
  final List<int> _history = [];

  @override
  int build() {
    _history.clear();
    return AppPageIndices.home;
  }

  bool get canGoBack => _history.isNotEmpty;

  void setIndex(int index) {
    if (index == state) return;
    _history.add(state);
    state = index;
  }

  void goBack() {
    while (_history.isNotEmpty) {
      final previousIndex = _history.removeLast();
      if (previousIndex != state) {
        state = previousIndex;
        return;
      }
    }
  }
}

final navigationIndexProvider = NotifierProvider<NavigationNotifier, int>(NavigationNotifier.new);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
  }

  void collapse() {
    state = true;
  }

  void expand() {
    state = false;
  }
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsedNotifier, bool>(SidebarCollapsedNotifier.new);
