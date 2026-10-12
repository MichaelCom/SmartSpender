import { NavLink, Outlet } from "react-router-dom";

const NAV = [
  { to: "/", label: "Dashboard", icon: "🏠", end: true },
  { to: "/transactions", label: "Transactions", icon: "🧾" },
  { to: "/categories", label: "Categories", icon: "🏷️" },
  { to: "/budgets", label: "Budgets", icon: "🎯" },
  { to: "/reports", label: "Reports", icon: "📊" },
  { to: "/settings", label: "Settings", icon: "⚙️" },
];

export function Layout() {
  return (
    <div className="app">
      <nav className="sidebar">
        <div className="brand">💰 SmartSpender</div>
        {NAV.map((n) => (
          <NavLink
            key={n.to}
            to={n.to}
            end={n.end}
            className={({ isActive }) => `nav-link${isActive ? " active" : ""}`}
          >
            <span>{n.icon}</span>
            <span>{n.label}</span>
          </NavLink>
        ))}
      </nav>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
