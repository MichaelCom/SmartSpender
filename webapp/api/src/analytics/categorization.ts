import { Category, Transaction, TxType } from "../types/models";

// Ported from lib/services/insights/categorization_engine.dart (parity).

/** A category suggestion with a confidence signal. */
export interface CategorySuggestion {
  categoryId: number;
  reason: string;
  fromHistory: boolean;
}

/**
 * Minimum number of matching historical precedents before a history-based
 * suggestion is considered confident enough to surface.
 */
export const MIN_HISTORY_MATCHES = 2;

/**
 * Seed keyword -> canonical category-name hints. Matched case-insensitively
 * as substrings of the description. Values are matched against the user's
 * actual category names (case-insensitive); if no such category exists the
 * seed rule is simply skipped. COPIED EXACTLY from the Dart source.
 */
export const SEED_KEYWORDS: Record<string, string> = {
  // Transport
  uber: "Transportation",
  bolt: "Transportation",
  taxi: "Transportation",
  fuel: "Transportation",
  petrol: "Transportation",
  "gas station": "Transportation",
  parking: "Transportation",
  gautrain: "Transportation",
  // Food & Dining
  woolworths: "Food & Dining",
  checkers: "Food & Dining",
  "pick n pay": "Food & Dining",
  spar: "Food & Dining",
  restaurant: "Food & Dining",
  cafe: "Food & Dining",
  coffee: "Food & Dining",
  mcdonald: "Food & Dining",
  kfc: "Food & Dining",
  "uber eats": "Food & Dining",
  "mr d": "Food & Dining",
  grocery: "Food & Dining",
  groceries: "Food & Dining",
  // Entertainment
  netflix: "Entertainment",
  spotify: "Entertainment",
  showmax: "Entertainment",
  disney: "Entertainment",
  cinema: "Entertainment",
  movie: "Entertainment",
  "youtube premium": "Entertainment",
  // Bills & Utilities
  electricity: "Bills & Utilities",
  eskom: "Bills & Utilities",
  water: "Bills & Utilities",
  rent: "Bills & Utilities",
  vodacom: "Bills & Utilities",
  mtn: "Bills & Utilities",
  telkom: "Bills & Utilities",
  internet: "Bills & Utilities",
  insurance: "Bills & Utilities",
  // Healthcare
  pharmacy: "Healthcare",
  clicks: "Healthcare",
  "dis-chem": "Healthcare",
  doctor: "Healthcare",
  hospital: "Healthcare",
  dentist: "Healthcare",
  // Shopping
  takealot: "Shopping",
  amazon: "Shopping",
  mall: "Shopping",
  clothing: "Shopping",
  // Income
  salary: "Salary",
  payroll: "Salary",
};

const STOP_WORDS = new Set([
  "the",
  "and",
  "for",
  "payment",
  "purchase",
  "from",
  "with",
]);

/**
 * Splits a lowercased string into alphanumeric tokens of length >= 3, dropping
 * very common noise words.
 */
function tokens(s: string): Set<string> {
  const out = new Set<string>();
  for (const t of s.split(/[^a-z0-9]+/)) {
    if (t.length >= 3 && !STOP_WORDS.has(t)) out.add(t);
  }
  return out;
}

/** True if the two token sets share at least one token. */
function shareSignificantToken(a: Set<string>, b: Set<string>): boolean {
  for (const t of a) {
    if (b.has(t)) return true;
  }
  return false;
}

/**
 * Returns a suggestion for [description] given the user's [categories] and
 * transaction [history], or null when nothing is confident enough.
 *
 * 1. History: among past transactions sharing a significant token with
 *    [description], pick the most-used category if it has at least
 *    MIN_HISTORY_MATCHES precedents.
 * 2. Seed rules: otherwise, if a seed keyword appears in [description] and maps
 *    to an existing category, suggest that (longer keywords first).
 * 3. Else null.
 */
export function suggestCategory(params: {
  description: string;
  categories: Category[];
  history: Transaction[];
  type?: TxType | null;
}): CategorySuggestion | null {
  const { description, categories, history, type = null } = params;
  const desc = description.trim().toLowerCase();
  if (desc === "") return null;

  const byId = new Map<number, Category>();
  for (const c of categories) {
    if (c.id != null) byId.set(c.id, c);
  }
  const typeOk = (categoryId: number): boolean => {
    if (type == null) return true;
    const c = byId.get(categoryId);
    return c != null && c.type === type;
  };

  // --- 1. History ---
  const descTokens = tokens(desc);
  const counts = new Map<number, number>();
  for (const tx of history) {
    const cid = tx.categoryId;
    if (cid == null || !byId.has(cid) || !typeOk(cid)) continue;
    const txDesc = (tx.description ?? "").toLowerCase();
    if (txDesc === "") continue;
    if (shareSignificantToken(descTokens, tokens(txDesc))) {
      counts.set(cid, (counts.get(cid) ?? 0) + 1);
    }
  }
  if (counts.size > 0) {
    // Reduce to the max-count entry; ties keep the earlier (first-seen) entry,
    // mirroring Dart's `reduce((a, b) => a.value >= b.value ? a : b)`.
    let best: { key: number; value: number } | null = null;
    for (const [key, value] of counts) {
      if (best == null) {
        best = { key, value };
      } else if (!(best.value >= value)) {
        best = { key, value };
      }
    }
    if (best != null && best.value >= MIN_HISTORY_MATCHES) {
      const name = byId.get(best.key)?.name ?? "this category";
      return {
        categoryId: best.key,
        reason: `You usually tag similar transactions as ${name}`,
        fromHistory: true,
      };
    }
  }

  // --- 2. Seed rules ---
  // Longer keywords first so 'uber eats' beats 'uber'.
  const keywords = Object.keys(SEED_KEYWORDS).sort(
    (a, b) => b.length - a.length
  );
  for (const kw of keywords) {
    if (!desc.includes(kw)) continue;
    const targetName = SEED_KEYWORDS[kw].toLowerCase();
    for (const c of categories) {
      if (c.id == null) continue;
      if (c.name.toLowerCase() === targetName && typeOk(c.id)) {
        return {
          categoryId: c.id,
          reason: `'${kw}' usually means ${c.name}`,
          fromHistory: false,
        };
      }
    }
  }

  return null;
}
