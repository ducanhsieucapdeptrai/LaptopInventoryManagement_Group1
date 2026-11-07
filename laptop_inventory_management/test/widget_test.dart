import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laptop_inventory_management_group1/main.dart';

void main() {
  testWidgets('App launches successfully smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LaptopInventoryApp()));

    // Verify app starts and finds title or elements
    expect(find.byType(LaptopInventoryApp), findsOneWidget);
  });
}
