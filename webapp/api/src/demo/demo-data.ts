import type { BackupDoc } from "../db/apply-backup";

// Deterministic-ish PRNG so demo data is varied but reproducible per call seed.
function makeRng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 0xffffffff;
  };
}

const EXPENSE_CATEGORIES = [
  { name: "Food & Dining", icon: "restaurant", color: "#F44336" },
  { name: "Transportation", icon: "directions_car", color: "#3F51B5" },
  { name: "Shopping", icon: "shopping_bag", color: "#E91E63" },
  { name: "Entertainment", icon: "movie", color: "#9C27B0" },
  { name: "Bills & Utilities", icon: "receipt", color: "#607D8B" },
  { name: "Healthcare", icon: "local_hospital", color: "#4CAF50" },
  { name: "Education", icon: "school", color: "#FF9800" },
  { name: "Groceries", icon: "local_grocery_store", color: "#8BC34A" },
];

const INCOME_CATEGORIES = [
  { name: "Salary", icon: "work", color: "#2196F3" },
  { name: "Investment", icon: "trending_up", color: "#FF9800" },
  { name: "Side Business", icon: "store", color: "#009688" },
];

const DESCRIPTIONS: Record<string, string[]> = {
  "Food & Dining": ["Lunch out", "Dinner", "Coffee", "Takeout", "Brunch"],
  Transportation: ["Fuel", "Uber ride", "Parking", "Car service", "Bus fare"],
  Shopping: ["Clothes", "Electronics", "Homeware", "Gift", "Shoes"],
  Entertainment: ["Netflix", "Cinema", "Concert", "Game", "Streaming"],
  "Bills & Utilities": ["Electricity", "Water", "Internet", "Phone", "Insurance"],
  Healthcare: ["Pharmacy", "Doctor visit", "Dentist", "Vitamins", "Checkup"],
  Education: ["Course fee", "Books", "Workshop", "Subscription", "Supplies"],
  Groceries: ["Woolworths", "Checkers", "Pick n Pay", "Spar", "Market"],
  Salary: ["Monthly salary"],
  Investment: ["Dividend", "Interest"],
  "Side Business": ["Freelance", "Consulting", "Sales"],
};

const EXPENSE_RANGE: Record<string, [number, number]> = {
  "Food & Dining": [40, 350],
  Transportation: [60, 900],
  Shopping: [100, 2500],
  Entertainment: [50, 600],
  "Bills & Utilities": [200, 2500],
  Healthcare: [80, 1500],
  Education: [150, 3000],
  Groceries: [150, 2000],
};

const BUDGET_AMOUNT: Record<string, number> = {
  "Food & Dining": 3000,
  Transportation: 2500,
  Shopping: 4000,
  Entertainment: 1500,
  "Bills & Utilities": 5000,
  Groceries: 6000,
};

/**
 * Builds a realistic demo backup document (schemaVersion 2): categories, ~6
 * months of income + expense transactions, monthly budgets for the current
 * month, and a couple of recurring rules. Fed through the shared applyBackup.
 */
export function buildDemoBackup(now: Date = new Date()): BackupDoc {
  const rng = makeRng(Math.floor(now.getTime() / 1000));
  const iso = (d: Date) => d.toISOString();
  const pick = <T>(arr: T[]) => arr[Math.floor(rng() * arr.length)];
  const amount = (lo: number, hi: number) =>
    Math.round((lo + rng() * (hi - lo)) * 100) / 100;

  const categories: any[] = [];
  let catId = 1;
  const expenseIds: Record<string, number> = {};
  const incomeIds: Record<string, number> = {};

  for (const c of EXPENSE_CATEGORIES) {
    const id = catId++;
    expenseIds[c.name] = id;
    categories.push({
      id,
      name: c.name,
      type: "expense",
      color: c.color,
      icon: c.icon,
      createdAt: iso(now),
    });
  }
  for (const c of INCOME_CATEGORIES) {
    const id = catId++;
    incomeIds[c.name] = id;
    categories.push({
      id,
      name: c.name,
      type: "income",
      color: c.color,
      icon: c.icon,
      createdAt: iso(now),
    });
  }

  const transactions: any[] = [];
  let txId = 1;

  // 6 months of history (including the current month).
  for (let monthOffset = 5; monthOffset >= 0; monthOffset--) {
    const monthDate = new Date(now.getFullYear(), now.getMonth() - monthOffset, 1);
    const year = monthDate.getFullYear();
    const month = monthDate.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    // For the current month, don't create transactions in the future.
    const maxDay =
      monthOffset === 0 ? Math.min(now.getDate(), daysInMonth) : daysInMonth;

    // Income: salary on the 1st + an occasional extra.
    transactions.push({
      id: txId++,
      amount: amount(28000, 32000),
      description: "Monthly salary",
      categoryId: incomeIds["Salary"],
      date: iso(new Date(year, month, 1)),
      type: "income",
      createdAt: iso(new Date(year, month, 1)),
    });
    if (rng() > 0.5) {
      transactions.push({
        id: txId++,
        amount: amount(500, 3000),
        description: pick(DESCRIPTIONS[pick(["Investment", "Side Business"])]),
        categoryId: rng() > 0.5 ? incomeIds["Investment"] : incomeIds["Side Business"],
        date: iso(new Date(year, month, 1 + Math.floor(rng() * maxDay))),
        type: "income",
        createdAt: iso(now),
      });
    }

    // Expenses: 15-28 per month.
    const count = 15 + Math.floor(rng() * 14);
    for (let i = 0; i < count; i++) {
      const cat = pick(EXPENSE_CATEGORIES);
      const [lo, hi] = EXPENSE_RANGE[cat.name] ?? [50, 500];
      transactions.push({
        id: txId++,
        amount: amount(lo, hi),
        description: pick(DESCRIPTIONS[cat.name] ?? ["Expense"]),
        categoryId: expenseIds[cat.name],
        date: iso(new Date(year, month, 1 + Math.floor(rng() * maxDay))),
        type: "expense",
        createdAt: iso(now),
      });
    }
  }

  // Budgets for the current month.
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  const budgets: any[] = [];
  let budgetId = 1;
  for (const [name, amt] of Object.entries(BUDGET_AMOUNT)) {
    if (expenseIds[name] == null) continue;
    budgets.push({
      id: budgetId++,
      categoryId: expenseIds[name],
      amount: amt,
      period: "monthly",
      startDate: iso(monthStart),
      endDate: iso(monthEnd),
      createdAt: iso(monthStart),
      description: `${name} budget`,
    });
  }

  // A couple of recurring rules.
  const recurring: any[] = [
    {
      id: 1,
      amount: 199,
      description: "Streaming subscription",
      categoryId: expenseIds["Entertainment"],
      type: "expense",
      frequency: "monthly",
      startDate: iso(new Date(now.getFullYear(), now.getMonth() - 5, 1)),
      endDate: null,
      lastGeneratedDate: iso(monthStart),
      createdAt: iso(now),
    },
    {
      id: 2,
      amount: 30000,
      description: "Monthly salary",
      categoryId: incomeIds["Salary"],
      type: "income",
      frequency: "monthly",
      startDate: iso(new Date(now.getFullYear(), now.getMonth() - 5, 1)),
      endDate: null,
      lastGeneratedDate: iso(monthStart),
      createdAt: iso(now),
    },
  ];

  return {
    schemaVersion: 2,
    categories,
    transactions,
    budgets,
    recurring,
  };
}
