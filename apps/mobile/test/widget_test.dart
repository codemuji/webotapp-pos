import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('GroceryPosMobileApp launches and displays Counter POS title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GroceryPosMobileApp(),
      ),
    );

    expect(find.text('Counter POS'), findsWidgets);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Cart is empty'), findsOneWidget);
  });
}
