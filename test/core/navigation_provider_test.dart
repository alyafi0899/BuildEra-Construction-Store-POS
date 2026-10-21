import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/providers/navigation_provider.dart';

void main() {
  test('Android back navigation restores the previous app page', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final navigation = container.read(navigationIndexProvider.notifier);

    navigation.setIndex(1);
    navigation.setIndex(7);
    navigation.goBack();
    expect(container.read(navigationIndexProvider), 1);
    navigation.goBack();
    expect(container.read(navigationIndexProvider), 0);
    expect(navigation.canGoBack, isFalse);
  });

  test('selecting the current page does not create a back history entry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final navigation = container.read(navigationIndexProvider.notifier);

    navigation.setIndex(0);

    expect(navigation.canGoBack, isFalse);
  });
}
