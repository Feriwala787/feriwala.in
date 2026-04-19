import React, { useEffect, useState } from 'react';
import api from '../services/api';
import toast from 'react-hot-toast';
import { format } from 'date-fns';
import { useAuth } from '../context/AuthContext';

export default function Orders() {
  const { user } = useAuth();
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchOrders();
  }, [user?.role, user?.shopId]);

  const fetchOrders = async () => {
    try {
      const allOrders = [];

      if (user?.role === 'shop_admin' && user?.shopId) {
        const res = await api.get(`/orders/shop/${user.shopId}`, { params: { limit: 50 } });
        allOrders.push(...(res.data.data || []).map((order) => ({ ...order, shopName: user.shopName || 'My Shop' })));
      } else {
        const shopsRes = await api.get('/admin/shops');
        for (const shop of shopsRes.data.data.slice(0, 10)) {
          try {
            const res = await api.get(`/orders/shop/${shop.id}`, { params: { limit: 10 } });
            allOrders.push(...res.data.data.map((order) => ({ ...order, shopName: shop.name })));
          } catch (e) {
            // ignore individual shop fetch failures
          }
        }
      }

      allOrders.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
      setOrders(allOrders);
    } catch (err) {
      toast.error('Failed to load orders');
    } finally {
      setLoading(false);
    }
  };

  const statusColor = (status) => {
    const colors = {
      pending: 'bg-yellow-100 text-yellow-800',
      confirmed: 'bg-blue-100 text-blue-800',
      preparing: 'bg-indigo-100 text-indigo-800',
      ready_for_pickup: 'bg-purple-100 text-purple-800',
      out_for_delivery: 'bg-orange-100 text-orange-800',
      delivered: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-800',
      returned: 'bg-gray-100 text-gray-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  if (user?.role === 'shop_admin') {
    return (
      <div className="bg-amber-50 border border-amber-100 rounded-xl p-6">
        <h2 className="text-2xl font-bold text-amber-900">Orders move to mobile app</h2>
        <p className="text-sm text-amber-800 mt-2">
          To keep shop operations fast, order receiving and live status updates are handled in the shop mobile app with notifications.
          Use the web portal for product listing and catalog management.
        </p>
      </div>
    );
  }

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-800 mb-6">{user?.role === 'shop_admin' ? 'My Shop Orders' : 'Recent Orders'}</h2>

      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : (
        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px]">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Order #</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Shop</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Total</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Payment</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {orders.map((order) => (
                  <tr key={order.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 font-medium text-gray-900">{order.orderNumber}</td>
                    <td className="px-6 py-4 text-gray-500">{order.shopName || '-'}</td>
                    <td className="px-6 py-4 text-gray-900 font-medium">₹{order.total}</td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${statusColor(order.status)}`}>
                        {order.status?.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-gray-500">{order.paymentMethod?.toUpperCase()}</td>
                    <td className="px-6 py-4 text-gray-500">
                      {order.createdAt ? format(new Date(order.createdAt), 'dd MMM yyyy, HH:mm') : '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {orders.length === 0 && <p className="text-center py-8 text-gray-500">No orders yet</p>}
        </div>
      )}
    </div>
  );
}
