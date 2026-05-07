import React, { useEffect, useState, useCallback } from 'react';
import api from '../services/api';
import toast from 'react-hot-toast';

const ROLES = ['', 'customer', 'shop_admin', 'delivery_agent', 'admin'];
const ROLE_COLORS = { admin: 'bg-red-100 text-red-700', shop_admin: 'bg-blue-100 text-blue-700', delivery_agent: 'bg-green-100 text-green-700', customer: 'bg-gray-100 text-gray-700' };

function Modal({ title, onClose, children }) {
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between p-6 border-b">
          <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
        </div>
        <div className="p-6">{children}</div>
      </div>
    </div>
  );
}

export default function Users() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [page, setPage] = useState(1);
  const [pagination, setPagination] = useState({});
  const [modal, setModal] = useState(null); // 'shop_admin' | 'delivery_agent'
  const [shops, setShops] = useState([]);
  const [form, setForm] = useState({ name: '', email: '', phone: '', shopId: '' });
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, limit: 20 };
      if (search) params.search = search;
      if (roleFilter) params.role = roleFilter;
      const res = await api.get('/admin/users', { params });
      setUsers(res.data.data);
      setPagination(res.data.pagination);
    } catch { toast.error('Failed to load users'); }
    finally { setLoading(false); }
  }, [page, search, roleFilter]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { api.get('/admin/shops').then(r => setShops(r.data.data || [])).catch(() => {}); }, []);

  const toggleStatus = async (user) => {
    try {
      await api.put(`/admin/users/${user._id}/status`, { isActive: !user.isActive });
      toast.success(`User ${user.isActive ? 'deactivated' : 'activated'}`);
      load();
    } catch { toast.error('Failed to update status'); }
  };

  const deleteUser = async (user) => {
    if (!window.confirm(`Delete ${user.name}? This cannot be undone.`)) return;
    try {
      await api.delete(`/admin/users/${user._id}`);
      toast.success('User deleted');
      load();
    } catch (err) { toast.error(err.response?.data?.message || 'Failed to delete'); }
  };

  const createUser = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const endpoint = modal === 'shop_admin' ? '/admin/users/shop-admin' : '/admin/users/delivery-agent';
      await api.post(endpoint, form);
      toast.success(`${modal === 'shop_admin' ? 'Shop admin' : 'Delivery agent'} created! Welcome email sent.`);
      setModal(null);
      setForm({ name: '', email: '', phone: '', shopId: '' });
      load();
    } catch (err) { toast.error(err.response?.data?.message || 'Failed to create user'); }
    finally { setSaving(false); }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">User Management</h2>
          <p className="text-sm text-gray-500 mt-1">Manage all platform users</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => setModal('shop_admin')}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">
            + Shop Admin
          </button>
          <button onClick={() => setModal('delivery_agent')}
            className="px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700">
            + Delivery Agent
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <input value={search} onChange={e => { setSearch(e.target.value); setPage(1); }} placeholder="Search name, email, phone..."
          className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-400" />
        <select value={roleFilter} onChange={e => { setRoleFilter(e.target.value); setPage(1); }}
          className="px-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-400">
          {ROLES.map(r => <option key={r} value={r}>{r || 'All Roles'}</option>)}
        </select>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-100">
              <tr>
                {['Name', 'Email', 'Phone', 'Role', 'Status', 'Joined', 'Actions'].map(h => (
                  <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {loading ? (
                Array(5).fill(0).map((_, i) => (
                  <tr key={i}><td colSpan={7} className="px-4 py-3"><div className="h-4 bg-gray-100 rounded animate-pulse" /></td></tr>
                ))
              ) : users.length === 0 ? (
                <tr><td colSpan={7} className="px-4 py-8 text-center text-gray-400">No users found</td></tr>
              ) : users.map(user => (
                <tr key={user._id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium text-gray-900">{user.name}</td>
                  <td className="px-4 py-3 text-gray-600">{user.email}</td>
                  <td className="px-4 py-3 text-gray-600">{user.phone}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${ROLE_COLORS[user.role] || 'bg-gray-100 text-gray-700'}`}>
                      {user.role?.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${user.isActive ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                      {user.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-gray-500">{new Date(user.createdAt).toLocaleDateString('en-IN')}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button onClick={() => toggleStatus(user)}
                        className={`text-xs px-2 py-1 rounded ${user.isActive ? 'bg-red-50 text-red-600 hover:bg-red-100' : 'bg-green-50 text-green-600 hover:bg-green-100'}`}>
                        {user.isActive ? 'Deactivate' : 'Activate'}
                      </button>
                      {user.role !== 'admin' && (
                        <button onClick={() => deleteUser(user)} className="text-xs px-2 py-1 rounded bg-gray-50 text-gray-600 hover:bg-gray-100">
                          Delete
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {pagination.pages > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-gray-100">
            <p className="text-sm text-gray-500">Total: {pagination.total}</p>
            <div className="flex gap-2">
              <button disabled={page === 1} onClick={() => setPage(p => p - 1)}
                className="px-3 py-1 text-sm border rounded disabled:opacity-40 hover:bg-gray-50">Prev</button>
              <span className="px-3 py-1 text-sm">{page} / {pagination.pages}</span>
              <button disabled={page === pagination.pages} onClick={() => setPage(p => p + 1)}
                className="px-3 py-1 text-sm border rounded disabled:opacity-40 hover:bg-gray-50">Next</button>
            </div>
          </div>
        )}
      </div>

      {/* Create Modal */}
      {modal && (
        <Modal title={modal === 'shop_admin' ? 'Create Shop Admin' : 'Create Delivery Agent'} onClose={() => setModal(null)}>
          <form onSubmit={createUser} className="space-y-4">
            {[['name', 'Full Name', 'text'], ['email', 'Email', 'email'], ['phone', 'Phone', 'tel']].map(([field, label, type]) => (
              <div key={field}>
                <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
                <input type={type} value={form[field]} onChange={e => setForm(f => ({ ...f, [field]: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-400" required />
              </div>
            ))}
            {modal === 'shop_admin' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Assign to Shop</label>
                <select value={form.shopId} onChange={e => setForm(f => ({ ...f, shopId: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-400" required>
                  <option value="">Select shop...</option>
                  {shops.map(s => <option key={s.id} value={s.id}>{s.name} ({s.code})</option>)}
                </select>
              </div>
            )}
            {modal === 'delivery_agent' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Assign to Shop (optional)</label>
                <select value={form.shopId} onChange={e => setForm(f => ({ ...f, shopId: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-400">
                  <option value="">No specific shop</option>
                  {shops.map(s => <option key={s.id} value={s.id}>{s.name} ({s.code})</option>)}
                </select>
              </div>
            )}
            <p className="text-xs text-gray-500 bg-blue-50 p-3 rounded-lg">
              A temporary password will be auto-generated and sent to the user's email.
            </p>
            <div className="flex gap-3 pt-2">
              <button type="button" onClick={() => setModal(null)} className="flex-1 py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50">Cancel</button>
              <button type="submit" disabled={saving} className="flex-1 py-2 bg-orange-500 text-white rounded-lg text-sm font-medium hover:bg-orange-600 disabled:opacity-50">
                {saving ? 'Creating...' : 'Create & Send Email'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
