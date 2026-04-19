import React from 'react';
import { useAuth } from '../context/AuthContext';

export default function ShopOpsNotice() {
  const { user } = useAuth();

  if (user?.role !== 'shop_admin') {
    return (
      <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
        <h2 className="text-2xl font-bold text-gray-800">Operations guidance</h2>
        <p className="text-sm text-gray-600 mt-2">This section is intended for shop owners using the mobile app operations flow.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-blue-50 border border-blue-100 rounded-xl p-6">
        <h2 className="text-2xl font-bold text-blue-900">Use mobile app for live operations</h2>
        <p className="text-sm text-blue-800 mt-2">
          Product listing stays on this web portal. Order receiving, order status updates, and other real-time operations should be
          handled in the shop mobile app with notifications.
        </p>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
        <h3 className="text-lg font-semibold text-gray-800 mb-3">Recommended split</h3>
        <ul className="list-disc list-inside space-y-2 text-gray-700 text-sm">
          <li><strong>Web portal:</strong> Create and maintain product catalog, pricing, stock, and media.</li>
          <li><strong>Shop app:</strong> Receive new orders in real-time with notifications and process order workflow.</li>
          <li><strong>Shop app:</strong> Handle pickup-ready, out-for-delivery handoff, and quick operational tasks.</li>
        </ul>
      </div>
    </div>
  );
}
