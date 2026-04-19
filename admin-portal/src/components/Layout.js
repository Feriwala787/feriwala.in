import React from 'react';
import { Outlet, Link, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const navByRole = {
  admin: [
    { path: '/', label: 'Dashboard', icon: '📊' },
    { path: '/shops', label: 'Shops', icon: '🏪' },
    { path: '/users', label: 'Users', icon: '👥' },
    { path: '/categories', label: 'Categories', icon: '📂' },
    { path: '/orders', label: 'Orders', icon: '📦' },
  ],
  shop_admin: [
    { path: '/', label: 'Overview', icon: '📊' },
    { path: '/products', label: 'My Products', icon: '🛍️' },
    { path: '/operations', label: 'App Operations', icon: '📱' },
    { path: '/categories', label: 'Categories', icon: '📂' },
  ],
};

export default function Layout() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const navItems = navByRole[user?.role] || navByRole.admin;
  const portalLabel = user?.role === 'shop_admin' ? 'Shop Owner Portal' : 'Admin Portal';

  return (
    <div className="min-h-screen bg-gray-100 md:flex">
      <aside className="bg-feriwala-dark text-white md:w-64 md:min-h-screen">
        <div className="p-6 border-b border-gray-700">
          <h1 className="text-2xl font-bold text-primary-400">🛒 Feriwala</h1>
          <p className="text-sm text-gray-400 mt-1">{portalLabel}</p>
        </div>

        <nav className="p-4 flex gap-2 overflow-x-auto md:block md:space-y-1 md:overflow-visible">
          {navItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`flex items-center whitespace-nowrap px-4 py-3 rounded-lg transition-colors ${
                location.pathname === item.path
                  ? 'bg-primary-600 text-white'
                  : 'text-gray-300 hover:bg-gray-700'
              }`}
            >
              <span className="mr-3">{item.icon}</span>
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="p-4 border-t border-gray-700 md:mt-auto">
          <div className="flex items-center justify-between gap-3">
            <div className="min-w-0">
              <p className="text-sm font-medium truncate">{user?.name}</p>
              <p className="text-xs text-gray-400 truncate">{user?.email}</p>
            </div>
            <button onClick={logout} className="text-gray-400 hover:text-white text-sm">
              Logout
            </button>
          </div>
        </div>
      </aside>

      <main className="flex-1 overflow-auto">
        <div className="p-4 md:p-8">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
