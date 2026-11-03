import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/widgets/tactile_button.dart';

void main() {
  group('TactileButton - Slice 2: Emil Kowalski Tactile Interaction Standards', () {
    testWidgets('renders child with initial scale 1.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TactileButton(
              onPressed: () {},
              child: const Text('Add to Cart'),
            ),
          ),
        ),
      );

      final transitionFinder = find.descendant(
        of: find.byType(TactileButton),
        matching: find.byType(ScaleTransition),
      );
      expect(transitionFinder, findsOneWidget);

      final ScaleTransition transition = tester.widget(transitionFinder);
      expect(transition.scale.value, equals(1.0));
      expect(find.text('Add to Cart'), findsOneWidget);
    });

    testWidgets('scales to 0.97 on tap down and triggers onPressed on tap up', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileButton(
                onPressed: () => pressed = true,
                child: const Text('Checkout'),
              ),
            ),
          ),
        ),
      );

      final transitionFinder = find.descendant(
        of: find.byType(TactileButton),
        matching: find.byType(ScaleTransition),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Checkout')));
      await tester.pump(); // Kick off animation
      await tester.pump(const Duration(milliseconds: 130)); // Advance to completion

      // Assert scale down to 0.97
      final ScaleTransition downTransition = tester.widget(transitionFinder);
      expect(downTransition.scale.value, closeTo(0.97, 0.005));

      // Release gesture
      await gesture.up();
      await tester.pump(); // Kick off rebound
      await tester.pump(const Duration(milliseconds: 130)); // Advance to completion

      final ScaleTransition upTransition = tester.widget(transitionFinder);
      expect(upTransition.scale.value, closeTo(1.0, 0.005));
      expect(pressed, isTrue);
    });

    testWidgets('guarantees accessible minimum touch target of 48x48dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TactileButton(
              onPressed: () {},
              child: const SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TactileButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
