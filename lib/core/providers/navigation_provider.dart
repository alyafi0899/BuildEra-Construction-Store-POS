import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationNotifier extends Notifier<int> {
  final List<int> _history = [];

  @override
  int build() {
    _history.clear();
    return 0;
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
