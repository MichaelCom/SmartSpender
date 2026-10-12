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
        <div className="brand">
          <span className="brand-mark">
            <img src="/brand-mark-white.png" alt="" aria-hidden="true" />
          </span>
          <span>SmartSpender</span>
        </div>
        {NAV.map((n) => (
          <NavLink
            key={n.to}
            to={n.to}
            end={n.end}
            className={({ isActive }) => `nav-link${isActive ? " active" : ""}`}
          >
            <span className="nav-ico">{n.icon}</span>
            <span>{n.label}</span>
          </NavLink>
        ))}
        {/* Sidebar footer: gradient avatar + account label. */}
        <div className="side-foot">
          <div className="side-user">
            <div className="avatar">SS</div>
            <div>
              <div className="nm">SmartSpender</div>
              <div className="em">Local account</div>
            </div>
          </div>
        </div>
      </nav>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
