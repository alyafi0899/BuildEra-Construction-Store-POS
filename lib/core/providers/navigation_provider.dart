import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final navigationIndexProvider = NotifierProvider<NavigationNotifier, int>(NavigationNotifier.new);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsedNotifier, bool>(SidebarCollapsedNotifier.new);
