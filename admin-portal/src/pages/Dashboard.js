import React, { useEffect, useState } from 'react';
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, PieChart, Pie, Cell, LineChart, Line } from 'recharts';
import api from '../services/api';
import { useAuth } from '../context/AuthContext';

const COLORS = ['#F47721', '#3B82F6', '#10B981', '#8B5CF6', '#EF4444', '#14B8A6'];
const fmt = (v) => `₹${Number(v || 0).toLocaleString('en-IN')}`;

function StatCard({ label, value, sub, color = 'bg-orange-500', icon }) {
  return (
    <div className="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
      <div className={`w-10 h-10 ${color} rounded-lg flex items-center justify-center text-white text-lg mb-3`}>{icon}</div>
      <p className="text-gray-500 text-xs font-medium uppercase tracking-wide">{label}</p>
      <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
      {sub && <p className="text-xs text-gray-400 mt-1">{sub}</p>}
    </div>
  );
}

export default function Dashboard() {
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [finance, setFinance] = useState(null);
  const [period, setPeriod] = useState('30d');

  useEffect(() => {
    if (user?.role === 'admin') {
      api.get('/admin/dashboard').then(r => setStats(r.data.data)).catch(() => {});
    }
  }, [user?.role]);

  useEffect(() => {
    if (user?.role === 'admin') {
      api.get(`/admin/finance?period=${period}`).then(r => setFinance(r.data.data)).catch(() => {});
    }
  }, [user?.role, period]);

  if (user?.role !== 'admin') return (
    <div className="text-center py-20 text-gray-500">
      <p className="text-4xl mb-4">🔒</p>
      <p>Admin access required</p>
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Platform Dashboard</h2>
          <p className="text-sm text-gray-500 mt-1">Real-time overview of Feriwala operations</p>
        </div>
        <select value={period} onChange={e => setPeriod(e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-400">
          <option value="7d">Last 7 days</option>
          <option value="30d">Last 30 days</option>
          <option value="90d">Last 90 days</option>
          <option value="1y">Last year</option>
        </select>
      </div>

      {!stats ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {Array(8).fill(0).map((_, i) => <div key={i} className="bg-white rounded-xl h-28 animate-pulse border border-gray-100" />)}
        </div>
      ) : (
        <>
          {/* KPI Cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <StatCard label="Total Revenue" value={fmt(stats.totalRevenue)} sub={stats.revenueGrowth ? `${stats.revenueGrowth > 0 ? '+' : ''}${stats.revenueGrowth}% vs last month` : null} color="bg-emerald-500" icon="₹" />
            <StatCard label="This Month" value={fmt(stats.thisMonthRevenue)} sub={`Last month: ${fmt(stats.lastMonthRevenue)}`} color="bg-blue-500" icon="📈" />
            <StatCard label="Total Orders" value={stats.totalOrders.toLocaleString()} sub={`Today: ${stats.todayOrders}`} color="bg-purple-500" icon="📦" />
            <StatCard label="Avg Order Value" value={fmt(stats.avgOrderValue)} sub={`Cancellation: ${stats.cancellationRate}%`} color="bg-orange-500" icon="🎯" />
            <StatCard label="Active Shops" value={`${stats.activeShops}/${stats.totalShops}`} color="bg-cyan-500" icon="🏪" />
            <StatCard label="Total Users" value={stats.totalUsers.toLocaleString()} sub={`Customers: ${stats.customers}`} color="bg-indigo-500" icon="👥" />
            <StatCard label="Shop Admins" value={stats.shopAdmins} color="bg-yellow-500" icon="👔" />
            <StatCard label="Delivery Agents" value={stats.deliveryAgents} color="bg-rose-500" icon="🛵" />
          </div>

          {/* Revenue Chart */}
          {finance && (
            <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
              <h3 className="text-base font-semibold text-gray-800 mb-4">Revenue & Orders ({period})</h3>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={finance.daily}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                    <YAxis yAxisId="left" tick={{ fontSize: 11 }} tickFormatter={v => `₹${(v/1000).toFixed(0)}k`} />
                    <YAxis yAxisId="right" orientation="right" tick={{ fontSize: 11 }} />
                    <Tooltip formatter={(v, n) => n === 'revenue' ? fmt(v) : v} />
                    <Line yAxisId="left" type="monotone" dataKey="revenue" stroke="#F47721" strokeWidth={2} dot={false} name="revenue" />
                    <Line yAxisId="right" type="monotone" dataKey="orders" stroke="#3B82F6" strokeWidth={2} dot={false} name="orders" />
                  </LineChart>
                </ResponsiveContainer>
              </div>
              <div className="flex gap-6 mt-3 text-sm">
                <span className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-orange-500 inline-block" /> Revenue</span>
                <span className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-blue-500 inline-block" /> Orders</span>
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
            {/* 7-day bar chart */}
            <div className="xl:col-span-2 bg-white rounded-xl shadow-sm p-6 border border-gray-100">
              <h3 className="text-base font-semibold text-gray-800 mb-4">Last 7 Days Orders</h3>
              <div className="h-56">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={stats.recentOrders}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                    <YAxis tick={{ fontSize: 11 }} />
                    <Tooltip />
                    <Bar dataKey="orders" fill="#F47721" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>

            {/* Order status pie */}
            <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
              <h3 className="text-base font-semibold text-gray-800 mb-4">Order Status</h3>
              <div className="h-56">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie data={stats.statusBreakdown} dataKey="count" nameKey="status" outerRadius={80} label={({ status, percent }) => `${(percent * 100).toFixed(0)}%`}>
                      {stats.statusBreakdown.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="space-y-1 mt-2">
                {stats.statusBreakdown.map((s, i) => (
                  <div key={s.status} className="flex items-center justify-between text-xs">
                    <span className="flex items-center gap-1">
                      <span className="w-2 h-2 rounded-full inline-block" style={{ background: COLORS[i % COLORS.length] }} />
                      {s.status.replace(/_/g, ' ')}
                    </span>
                    <span className="font-medium">{s.count}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Top Shops + Finance Summary */}
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
            <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
              <h3 className="text-base font-semibold text-gray-800 mb-4">Top Shops by Revenue</h3>
              <div className="space-y-3">
                {stats.topShops.map((shop, i) => (
                  <div key={shop.shopId} className="flex items-center gap-3">
                    <span className="w-6 h-6 rounded-full bg-orange-100 text-orange-600 text-xs font-bold flex items-center justify-center">{i + 1}</span>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-800 truncate">{shop.name}</p>
                      <p className="text-xs text-gray-500">{shop.orders} orders</p>
                    </div>
                    <span className="text-sm font-semibold text-gray-800">{fmt(shop.revenue)}</span>
                  </div>
                ))}
                {stats.topShops.length === 0 && <p className="text-gray-400 text-sm">No data yet</p>}
              </div>
            </div>

            {finance && (
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                <h3 className="text-base font-semibold text-gray-800 mb-4">Finance Summary ({period})</h3>
                <div className="space-y-3 text-sm">
                  {[
                    ['Gross Revenue', fmt(finance.grossRevenue)],
                    ['Delivery Revenue', fmt(finance.deliveryRevenue)],
                    ['Total Discounts Given', fmt(finance.totalDiscount)],
                    ['Net Revenue', fmt(finance.netRevenue)],
                    ['Avg Order Value', `₹${finance.avgOrderValue}`],
                    ['Delivered Orders', finance.deliveredOrders],
                    ['Cancelled Orders', `${finance.cancelledOrders} (${finance.cancellationRate}%)`],
                  ].map(([label, value]) => (
                    <div key={label} className="flex justify-between items-center py-1 border-b border-gray-50">
                      <span className="text-gray-600">{label}</span>
                      <span className="font-semibold text-gray-900">{value}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
