import 'package:flutter/material.dart';

/// Resolves a stored category hex colour string to a [Color].
///
/// Accepts `#RRGGBB`, `RRGGBB`, `#AARRGGBB`, or `AARRGGBB`. Falls back to a
/// neutral grey when the string is null or unparseable. This is the single
/// source of truth for category colour parsing across the app.
Color categoryColorFromHex(String? hex, {Color fallback = const Color(0xFF9E9E9E)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceFirst('#', '').trim();
  final withAlpha = cleaned.length == 6 ? 'ff$cleaned' : cleaned;
  final value = int.tryParse(withAlpha, radix: 16);
  if (value == null) return fallback;
  return Color(value);
}

/// Maps a stored category icon name to its [IconData].
///
/// This is the single source of truth for the icon-name → [IconData] mapping;
/// screens must not keep their own copies. The keys match the names persisted
/// by the add-category flow (see [categoryIconChoices]).
IconData categoryIconFromName(String? name) {
  return _iconByName[name] ?? Icons.category;
}

const Map<String, IconData> _iconByName = {
  'category': Icons.category,
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'movie': Icons.movie,
  'receipt': Icons.receipt,
  'local_hospital': Icons.local_hospital,
  'school': Icons.school,
  'work': Icons.work,
  'computer': Icons.computer,
  'trending_up': Icons.trending_up,
  'card_giftcard': Icons.card_giftcard,
  'attach_money': Icons.attach_money,
  'home': Icons.home,
  'fitness_center': Icons.fitness_center,
  'local_gas_station': Icons.local_gas_station,
  'phone': Icons.phone,
  'wifi': Icons.wifi,
  'pets': Icons.pets,
  'child_care': Icons.child_care,
};

/// The ordered list of icon choices offered by the add-category picker.
///
/// Order matches the historical picker so existing categories keep their
/// position. Single source of truth — the add-category screen builds its grid
/// from this list.
const List<String> categoryIconChoices = [
  'category',
  'restaurant',
  'directions_car',
  'shopping_bag',
  'movie',
  'receipt',
  'local_hospital',
  'school',
  'work',
  'computer',
  'trending_up',
  'card_giftcard',
  'attach_money',
  'home',
  'fitness_center',
  'local_gas_station',
  'phone',
  'wifi',
  'pets',
  'child_care',
];

/// The ordered palette of category colour swatches offered by the picker.
///
/// Single source of truth — the add-category screen builds its swatch row from
/// this list.
const List<String> categoryColorChoices = [
  '#FF6B6B',
  '#4ECDC4',
  '#45B7D1',
  '#96CEB4',
  '#FFEAA7',
  '#DDA0DD',
  '#98D8C8',
  '#F7DC6F',
  '#2ECC71',
  '#3498DB',
  '#9B59B6',
  '#E74C3C',
  '#F39C12',
  '#1ABC9C',
  '#34495E',
];

/// A rounded, colour-filled square containing a category's icon.
///
/// Matches the mockup `.m-ic` chip: a rounded square filled with the category's
/// colour, with a white glyph. Used as the leading element of transaction,
/// category, budget and recurring list rows.
class CategoryIconChip extends StatelessWidget {
  const CategoryIconChip({
    super.key,
    this.colorHex,
    this.iconName,
    this.size = 42,
    this.radius = 13,
    this.iconSize,
  });

  /// Stored category colour hex, e.g. `#43a047`. Null → neutral grey.
  final String? colorHex;

  /// Stored category icon name, e.g. `shopping_bag`. Null → generic category.
  final String? iconName;

  /// Overall width/height of the chip.
  final double size;

  /// Corner radius.
  final double radius;

  /// Glyph size; defaults to ~45% of [size].
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFromHex(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        categoryIconFromName(iconName),
        color: Colors.white,
        size: iconSize ?? size * 0.45,
      ),
    );
  }
}
