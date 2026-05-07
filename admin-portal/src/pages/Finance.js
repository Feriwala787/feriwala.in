import React, { useEffect, useState } from 'react';
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, LineChart, Line } from 'recharts';
import api from '../services/api';
import toast from 'react-hot-toast';

const fmt = (v) => `₹${Number(v || 0).toLocaleString('en-IN')}`;

export default function Finance() {
  const [finance, setFinance] = useState(null);
  const [shopFinance, setShopFinance] = useState([]);
  const [period, setPeriod] = useState('30d');
  const [loading, setLoading] = useState(true);
  const [shops, setShops] = useState([]);

  useEffect(() => {
    setLoading(true);
    Promise.all([
      api.get(`/admin/finance?period=${period}`),
      api.get('/admin/shops'),
    ]).then(([finRes, shopRes]) => {
      setFinance(finRes.data.data);
      setShops(shopRes.data.data || []);
    }).catch(() => toast.error('Failed to load finance data'))
      .finally(() => setLoading(false));
  }, [period]);

  useEffect(() => {
    if (shops.length === 0) return;
    Promise.all(
      shops.slice(0, 10).map(s =>
        api.get(`/admin/finance?period=${period}&shopId=${s.id}`)
          .then(r => ({ ...r.data.data, shopName: s.name, shopId: s.id }))
          .catch(() => null)
      )
    ).then(results => setShopFinance(results.filter(Boolean)));
  }, [shops, period]);

  const exportCSV = () => {
    if (!finance?.daily) return;
    const rows = [['Date', 'Revenue', 'Orders', 'Cancelled']];
    finance.daily.forEach(d => rows.push([d.date, d.revenue, d.orders, d.cancelled]));
    const csv = rows.map(r => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `feriwala-finance-${period}.csv`;
    a.click();
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Finance & Revenue</h2>
          <p className="text-sm text-gray-500 mt-1">Platform-wide financial tracking</p>
        </div>
        <div className="flex gap-2">
          <select value={period} onChange={e => setPeriod(e.target.value)}
            className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-400">
            <option value="7d">Last 7 days</option>
            <option value="30d">Last 30 days</option>
            <option value="90d">Last 90 days</option>
            <option value="1y">Last year</option>
          </select>
          <button onClick={exportCSV} className="px-4 py-2 bg-gray-800 text-white rounded-lg text-sm font-medium hover:bg-gray-700">
            ↓ Export CSV
          </button>
        </div>
      </div>

      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {Array(8).fill(0).map((_, i) => <div key={i} className="bg-white rounded-xl h-24 animate-pulse border border-gray-100" />)}
        </div>
      ) : finance && (
        <>
          {/* KPI Cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'Gross Revenue', value: fmt(finance.grossRevenue), color: 'text-emerald-600', bg: 'bg-emerald-50' },
              { label: 'Net Revenue', value: fmt(finance.netRevenue), color: 'text-blue-600', bg: 'bg-blue-50' },
              { label: 'Delivery Revenue', value: fmt(finance.deliveryRevenue), color: 'text-purple-600', bg: 'bg-purple-50' },
              { label: 'Total Discounts', value: fmt(finance.totalDiscount), color: 'text-orange-600', bg: 'bg-orange-50' },
              { label: 'Delivered Orders', value: finance.deliveredOrders, color: 'text-green-600', bg: 'bg-green-50' },
              { label: 'Cancelled Orders', value: finance.cancelledOrders, color: 'text-red-600', bg: 'bg-red-50' },
              { label: 'Cancellation Rate', value: `${finance.cancellationRate}%`, color: 'text-rose-600', bg: 'bg-rose-50' },
              { label: 'Avg Order Value', value: `₹${finance.avgOrderValue}`, color: 'text-indigo-600', bg: 'bg-indigo-50' },
            ].map(card => (
              <div key={card.label} className={`${card.bg} rounded-xl p-4 border border-gray-100`}>
                <p className="text-xs text-gray-500 font-medium">{card.label}</p>
                <p className={`text-xl font-bold mt-1 ${card.color}`}>{card.value}</p>
              </div>
            ))}
          </div>

          {/* Revenue Chart */}
          <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
            <h3 className="text-base font-semibold text-gray-800 mb-4">Daily Revenue Trend</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={finance.daily}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                  <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `₹${(v / 1000).toFixed(0)}k`} />
                  <Tooltip formatter={v => fmt(v)} />
                  <Line type="monotone" dataKey="revenue" stroke="#F47721" strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Orders Chart */}
          <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
            <h3 className="text-base font-semibold text-gray-800 mb-4">Daily Orders vs Cancellations</h3>
            <div className="h-56">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={finance.daily}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip />
                  <Bar dataKey="orders" fill="#3B82F6" radius={[3, 3, 0, 0]} name="Orders" />
                  <Bar dataKey="cancelled" fill="#EF4444" radius={[3, 3, 0, 0]} name="Cancelled" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Shop-wise breakdown */}
          {shopFinance.length > 0 && (
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="p-5 border-b border-gray-100">
                <h3 className="text-base font-semibold text-gray-800">Shop-wise Revenue Breakdown</h3>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead className="bg-gray-50">
                    <tr>
                      {['Shop', 'Gross Revenue', 'Net Revenue', 'Orders', 'Cancelled', 'Avg Order', 'Cancel Rate'].map(h => (
                        <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {shopFinance.sort((a, b) => b.grossRevenue - a.grossRevenue).map(s => (
                      <tr key={s.shopId} className="hover:bg-gray-50">
                        <td className="px-4 py-3 font-medium text-gray-900">{s.shopName}</td>
                        <td className="px-4 py-3 text-emerald-600 font-semibold">{fmt(s.grossRevenue)}</td>
                        <td className="px-4 py-3 text-blue-600">{fmt(s.netRevenue)}</td>
                        <td className="px-4 py-3">{s.deliveredOrders}</td>
                        <td className="px-4 py-3 text-red-500">{s.cancelledOrders}</td>
                        <td className="px-4 py-3">₹{s.avgOrderValue}</td>
                        <td className="px-4 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${parseFloat(s.cancellationRate) > 20 ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
                            {s.cancellationRate}%
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
