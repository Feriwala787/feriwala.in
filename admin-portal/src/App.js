import React from 'react';
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Finance from './pages/Finance';
import Shops from './pages/Shops';
import ShopForm from './pages/ShopForm';
import Users from './pages/Users';
import Categories from './pages/Categories';
import Orders from './pages/Orders';
import ShopProducts from './pages/ShopProducts';
import ShopOpsNotice from './pages/ShopOpsNotice';

import Registrations from './pages/Registrations';

function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return (
    <div className="flex items-center justify-center h-screen bg-gray-50">
      <div className="text-center">
        <div className="w-10 h-10 border-4 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
        <p className="text-gray-500 text-sm">Loading...</p>
      </div>
    </div>
  );
  if (!user) return <Navigate to="/login" replace />;
  return children;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<ProtectedRoute><Layout /></ProtectedRoute>}>
        <Route index element={<Dashboard />} />
        <Route path="finance" element={<Finance />} />
        <Route path="products" element={<ShopProducts />} />
        <Route path="shops" element={<Shops />} />
        <Route path="shops/new" element={<ShopForm />} />
        <Route path="shops/:id/edit" element={<ShopForm />} />
        <Route path="users" element={<Users />} />
        <Route path="registrations" element={<Registrations />} />
        <Route path="categories" element={<Categories />} />
        <Route path="orders" element={<Orders />} />
        <Route path="operations" element={<ShopOpsNotice />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <HashRouter>
        <Toaster position="top-right" toastOptions={{ duration: 4000 }} />
        <AppRoutes />
      </HashRouter>
    </AuthProvider>
  );
}
