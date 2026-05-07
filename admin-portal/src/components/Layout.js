import React, { useState } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const adminNav = [
  { path: '/', label: 'Dashboard', icon: '📊' },
  { path: '/finance', label: 'Finance', icon: '💰' },
  { path: '/shops', label: 'Shops', icon: '🏪' },
  { path: '/users', label: 'Users', icon: '👥' },
  { path: '/orders', label: 'Orders', icon: '📦' },
  { path: '/categories', label: 'Categories', icon: '📂' },
];

const shopAdminNav = [
  { path: '/', label: 'Overview', icon: '📊' },
  { path: '/products', label: 'My Products', icon: '🛍️' },
  { path: '/operations', label: 'App Operations', icon: '📱' },
  { path: '/categories', label: 'Categories', icon: '📂' },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const navItems = user?.role === 'admin' ? adminNav : shopAdminNav;
  const isAdmin = user?.role === 'admin';

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Mobile overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 bg-black/50 z-20 md:hidden" onClick={() => setSidebarOpen(false)} />
      )}

      {/* Sidebar */}
      <aside className={`fixed md:static inset-y-0 left-0 z-30 w-64 bg-gray-900 text-white flex flex-col transform transition-transform duration-200 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}`}>
        <div className="p-5 border-b border-gray-700">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-orange-500 rounded-lg flex items-center justify-center text-white font-bold text-lg">F</div>
            <div>
              <h1 className="text-base font-bold text-white">Feriwala</h1>
              <p className="text-xs text-gray-400">{isAdmin ? 'Admin Portal' : 'Shop Portal'}</p>
            </div>
          </div>
        </div>

        <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
          {navItems.map(item => {
            const active = location.pathname === item.path;
            return (
              <Link key={item.path} to={item.path} onClick={() => setSidebarOpen(false)}
                className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ${active ? 'bg-orange-500 text-white' : 'text-gray-300 hover:bg-gray-800 hover:text-white'}`}>
                <span className="text-base">{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-gray-700">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-8 h-8 bg-orange-500 rounded-full flex items-center justify-center text-white text-sm font-bold">
              {(user?.name || 'A')[0].toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-medium text-white truncate">{user?.name}</p>
              <p className="text-xs text-gray-400 truncate">{user?.email}</p>
            </div>
          </div>
          <button onClick={handleLogout}
            className="w-full text-sm text-gray-400 hover:text-white hover:bg-gray-800 py-2 px-3 rounded-lg transition-colors text-left">
            🚪 Logout
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top bar */}
        <header className="bg-white border-b border-gray-200 px-4 py-3 flex items-center gap-4 md:hidden">
          <button onClick={() => setSidebarOpen(true)} className="text-gray-600 hover:text-gray-900">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          <span className="font-semibold text-gray-900">Feriwala {isAdmin ? 'Admin' : 'Shop'}</span>
        </header>

        <main className="flex-1 overflow-auto p-4 md:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
