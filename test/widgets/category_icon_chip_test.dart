import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_spender/widgets/redesign/category_icon_chip.dart';

void main() {
  group('categoryIconIsEmoji', () {
    test('returns false for known Material icon names', () {
      expect(categoryIconIsEmoji('restaurant'), isFalse);
      expect(categoryIconIsEmoji('category'), isFalse);
      expect(categoryIconIsEmoji('directions_car'), isFalse);
    });

    test('returns false for null / empty', () {
      expect(categoryIconIsEmoji(null), isFalse);
      expect(categoryIconIsEmoji(''), isFalse);
    });

    test('returns true for emoji glyphs (as stored by the demo seeder)', () {
      expect(categoryIconIsEmoji('🍽️'), isTrue);
      expect(categoryIconIsEmoji('🚗'), isTrue);
      expect(categoryIconIsEmoji('💰'), isTrue);
    });

    test('returns false for an unknown plain-ascii name', () {
      // Not an emoji and not a known name → treated as a (fallback) icon name,
      // not rendered as text.
      expect(categoryIconIsEmoji('unknown_name'), isFalse);
    });
  });

  group('CategoryIconChip', () {
    testWidgets('renders an emoji glyph as text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconChip(colorHex: '#43a047', iconName: '🍽️'),
          ),
        ),
      );

      expect(find.text('🍽️'), findsOneWidget);
    });

    testWidgets('renders a Material icon for a known name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconChip(colorHex: '#43a047', iconName: 'restaurant'),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('falls back to the generic category icon for null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CategoryIconChip(colorHex: '#43a047')),
        ),
      );

      expect(find.byIcon(Icons.category), findsOneWidget);
    });
  });
}
