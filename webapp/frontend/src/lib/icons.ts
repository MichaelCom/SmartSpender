/**
 * Maps the mobile Material icon names (stored in category.icon) to an emoji
 * glyph for web rendering. Mirrors the icon set offered by the mobile
 * add_category_screen.dart picker. Unknown names fall back to the default.
 */
const ICON_EMOJI: Record<string, string> = {
  category: "🏷️",
  restaurant: "🍽️",
  directions_car: "🚗",
  shopping_bag: "🛍️",
  movie: "🎬",
  receipt: "🧾",
  local_hospital: "🏥",
  school: "🎓",
  work: "💼",
  computer: "💻",
  trending_up: "📈",
  card_giftcard: "🎁",
  attach_money: "💵",
  home: "🏠",
  fitness_center: "🏋️",
  local_gas_station: "⛽",
  phone: "📱",
  wifi: "📶",
  pets: "🐾",
  child_care: "🍼",
};

/** The icon picker options (name -> emoji), order mirrors the mobile picker. */
export const ICON_OPTIONS: ReadonlyArray<{ name: string; emoji: string }> =
  Object.entries(ICON_EMOJI).map(([name, emoji]) => ({ name, emoji }));

/** Category color palette, exact values from the mobile add_category_screen. */
export const COLOR_OPTIONS: readonly string[] = [
  "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
  "#DDA0DD", "#98D8C8", "#F7DC6F", "#2ECC71", "#3498DB",
  "#9B59B6", "#E74C3C", "#F39C12", "#1ABC9C", "#34495E",
];

export const DEFAULT_ICON = "category";
export const DEFAULT_COLOR = "#FF6B6B";

/** Returns the emoji for a stored icon name (or the default glyph). */
export function iconEmoji(name?: string | null): string {
  if (!name) return ICON_EMOJI[DEFAULT_ICON];
  return ICON_EMOJI[name] ?? ICON_EMOJI[DEFAULT_ICON];
}
