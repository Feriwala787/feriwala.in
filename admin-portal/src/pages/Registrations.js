import React, { useEffect, useState, useCallback } from 'react';
import api from '../services/api';
import toast from 'react-hot-toast';

const TAB_ROLES = [
  { key: 'shop_admin', label: 'Shop Registrations' },
  { key: 'delivery_agent', label: 'Delivery Agents' },
];

const STATUS_COLORS = {
  pending: 'bg-yellow-100 text-yellow-700',
  approved: 'bg-green-100 text-green-700',
  rejected: 'bg-red-100 text-red-700',
};

function RejectModal({ user, onClose, onConfirm }) {
  const [reason, setReason] = useState('');
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
        <h3 className="text-lg font-semibold mb-4">Reject Registration</h3>
        <p className="text-sm text-gray-600 mb-3">Rejecting <strong>{user.name}</strong> ({user.email})</p>
        <textarea
          value={reason}
          onChange={e => setReason(e.target.value)}
          placeholder="Reason for rejection (required)..."
          rows={3}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-400 resize-none"
        />
        <div className="flex gap-3 mt-4">
          <button onClick={onClose} className="flex-1 py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50">Cancel</button>
          <button
            disabled={!reason.trim()}
            onClick={() => onConfirm(reason)}
            className="flex-1 py-2 bg-red-500 text-white rounded-lg text-sm font-medium hover:bg-red-600 disabled:opacity-50"
          >
            Reject
          </button>
        </div>
      </div>
    </div>
  );
}

function DetailsModal({ user, onClose }) {
  const rd = user.registrationData || {};
  const isShop = user.role === 'shop_admin';
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg p-6 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold">{isShop ? 'Shop Registration Details' : 'Delivery Agent Details'}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
        </div>
        <div className="space-y-3 text-sm">
          <Section title="Personal Info">
            <Row label="Name" value={user.name} />
            <Row label="Email" value={user.email} />
            <Row label="Phone" value={user.phone} />
            <Row label="Registered" value={new Date(user.createdAt).toLocaleString('en-IN')} />
          </Section>
          {isShop ? (
            <Section title="Shop Info">
              <Row label="Shop Name" value={rd.shopName} />
              <Row label="Business Type" value={rd.businessType} />
              <Row label="Address" value={rd.shopAddress} />
              <Row label="City" value={rd.city} />
              <Row label="State" value={rd.state} />
              <Row label="Pincode" value={rd.pincode} />
              <Row label="GST" value={rd.gstNumber || '—'} />
              <Row label="Hours" value={`${rd.openingTime || '09:00'} – ${rd.closingTime || '21:00'}`} />
            </Section>
          ) : (
            <Section title="Vehicle & Documents">
              <Row label="Vehicle Type" value={rd.vehicleType} />
              <Row label="Vehicle No." value={rd.vehicleNumber || '—'} />
              <Row label="License No." value={rd.licenseNumber} />
              <Row label="Aadhar No." value={rd.aadharNumber} />
              <Row label="Emergency Contact" value={rd.emergencyContact} />
            </Section>
          )}
          {user.rejectionReason && (
            <div className="bg-red-50 p-3 rounded-lg">
              <p className="text-xs font-semibold text-red-600 mb-1">Rejection Reason</p>
              <p className="text-red-700">{user.rejectionReason}</p>
            </div>
          )}
        </div>
        <button onClick={onClose} className="mt-5 w-full py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50">Close</button>
      </div>
    </div>
  );
}

function Section({ title, children }) {
  return (
    <div>
      <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">{title}</p>
      <div className="bg-gray-50 rounded-lg p-3 space-y-2">{children}</div>
    </div>
  );
}

function Row({ label, value }) {
  return (
    <div className="flex justify-between">
      <span className="text-gray-500">{label}</span>
      <span className="font-medium text-gray-800 text-right max-w-[60%]">{value}</span>
    </div>
  );
}

export default function Registrations() {
  const [tab, setTab] = useState('shop_admin');
  const [statusFilter, setStatusFilter] = useState('pending');
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [rejectTarget, setRejectTarget] = useState(null);
  const [detailTarget, setDetailTarget] = useState(null);
  const [acting, setActing] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get('/admin/registrations', { params: { status: statusFilter, role: tab } });
      setUsers(res.data.data || []);
    } catch { toast.error('Failed to load registrations'); }
    finally { setLoading(false); }
  }, [tab, statusFilter]);

  useEffect(() => { load(); }, [load]);

  const approve = async (user) => {
    setActing(user._id);
    try {
      await api.put(`/admin/registrations/${user._id}/approve`);
      toast.success(`${user.name} approved!`);
      load();
    } catch (err) { toast.error(err.response?.data?.message || 'Failed to approve'); }
    finally { setActing(null); }
  };

  const reject = async (user, reason) => {
    setActing(user._id);
    try {
      await api.put(`/admin/registrations/${user._id}/reject`, { reason });
      toast.success(`${user.name} rejected`);
      setRejectTarget(null);
      load();
    } catch (err) { toast.error(err.response?.data?.message || 'Failed to reject'); }
    finally { setActing(null); }
  };

  const pendingCount = users.filter(u => u.approvalStatus === 'pending').length;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">Registrations</h2>
        <p className="text-sm text-gray-500 mt-1">Review and approve shop & delivery agent registrations</p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 border-b border-gray-200">
        {TAB_ROLES.map(t => (
          <button key={t.key} onClick={() => { setTab(t.key); setStatusFilter('pending'); }}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${tab === t.key ? 'border-orange-500 text-orange-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Status filter */}
      <div className="flex gap-2">
        {['pending', 'approved', 'rejected'].map(s => (
          <button key={s} onClick={() => setStatusFilter(s)}
            className={`px-3 py-1.5 rounded-full text-xs font-medium capitalize transition-colors ${statusFilter === s ? 'bg-orange-500 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
            {s}
          </button>
        ))}
      </div>

      {/* List */}
      <div className="space-y-3">
        {loading ? (
          Array(3).fill(0).map((_, i) => <div key={i} className="h-20 bg-gray-100 rounded-xl animate-pulse" />)
        ) : users.length === 0 ? (
          <div className="text-center py-12 text-gray-400">No {statusFilter} registrations</div>
        ) : users.map(user => (
          <div key={user._id} className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="font-semibold text-gray-900">{user.name}</span>
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_COLORS[user.approvalStatus]}`}>
                    {user.approvalStatus}
                  </span>
                </div>
                <p className="text-sm text-gray-500 mt-0.5">{user.email} · {user.phone}</p>
                {user.role === 'shop_admin' && user.registrationData && (
                  <p className="text-sm text-gray-700 mt-1">🏪 <strong>{user.registrationData.shopName}</strong> · {user.registrationData.city}, {user.registrationData.state}</p>
                )}
                {user.role === 'delivery_agent' && user.registrationData && (
                  <p className="text-sm text-gray-700 mt-1">🏍️ {user.registrationData.vehicleType} · License: {user.registrationData.licenseNumber}</p>
                )}
                <p className="text-xs text-gray-400 mt-1">{new Date(user.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</p>
              </div>
              <div className="flex flex-col gap-2 shrink-0">
                <button onClick={() => setDetailTarget(user)} className="text-xs px-3 py-1.5 rounded-lg bg-gray-50 text-gray-600 hover:bg-gray-100 border border-gray-200">
                  View Details
                </button>
                {user.approvalStatus === 'pending' && (
                  <>
                    <button
                      disabled={acting === user._id}
                      onClick={() => approve(user)}
                      className="text-xs px-3 py-1.5 rounded-lg bg-green-500 text-white hover:bg-green-600 disabled:opacity-50 font-medium"
                    >
                      {acting === user._id ? '...' : '✓ Approve'}
                    </button>
                    <button
                      disabled={acting === user._id}
                      onClick={() => setRejectTarget(user)}
                      className="text-xs px-3 py-1.5 rounded-lg bg-red-50 text-red-600 hover:bg-red-100 border border-red-200"
                    >
                      ✕ Reject
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {rejectTarget && <RejectModal user={rejectTarget} onClose={() => setRejectTarget(null)} onConfirm={(reason) => reject(rejectTarget, reason)} />}
      {detailTarget && <DetailsModal user={detailTarget} onClose={() => setDetailTarget(null)} />}
    </div>
  );
}
