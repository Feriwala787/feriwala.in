import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';
import api from '../services/api';

export default function Login() {
  const [mode, setMode] = useState('login'); // login | forgot | reset
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await login(email, password);
      toast.success('Welcome back!');
      navigate('/');
    } catch (err) {
      toast.error(err.response?.data?.message || err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const handleForgot = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.post('/auth/forgot-password', { email });
      toast.success('OTP sent to your email');
      setMode('reset');
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to send OTP');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.post('/auth/reset-password', { email, otp, newPassword });
      toast.success('Password reset! Please login.');
      setMode('login');
      setOtp('');
      setNewPassword('');
    } catch (err) {
      toast.error(err.response?.data?.message || 'Reset failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-900 px-4">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md">
        <div className="text-center mb-8">
          <div className="text-4xl mb-2">🛒</div>
          <h1 className="text-2xl font-bold text-gray-900">Feriwala Admin</h1>
          <p className="text-gray-500 text-sm mt-1">
            {mode === 'login' ? 'Platform Management Portal' : mode === 'forgot' ? 'Reset your password' : 'Enter OTP from email'}
          </p>
        </div>

        {mode === 'login' && (
          <form onSubmit={handleLogin} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-400" required />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-400" required />
            </div>
            <button type="submit" disabled={loading}
              className="w-full py-3 bg-orange-500 text-white rounded-lg font-semibold hover:bg-orange-600 disabled:opacity-50 transition-colors">
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
            <button type="button" onClick={() => setMode('forgot')}
              className="w-full text-sm text-orange-500 hover:underline text-center">
              Forgot password?
            </button>
          </form>
        )}

        {mode === 'forgot' && (
          <form onSubmit={handleForgot} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Your Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-400" required />
            </div>
            <button type="submit" disabled={loading}
              className="w-full py-3 bg-orange-500 text-white rounded-lg font-semibold hover:bg-orange-600 disabled:opacity-50">
              {loading ? 'Sending...' : 'Send OTP'}
            </button>
            <button type="button" onClick={() => setMode('login')} className="w-full text-sm text-gray-500 hover:underline text-center">
              Back to login
            </button>
          </form>
        )}

        {mode === 'reset' && (
          <form onSubmit={handleReset} className="space-y-5">
            <p className="text-sm text-gray-600 bg-orange-50 p-3 rounded-lg">OTP sent to <strong>{email}</strong></p>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">6-digit OTP</label>
              <input type="text" value={otp} onChange={e => setOtp(e.target.value)} maxLength={6}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-400 text-center text-2xl tracking-widest" required />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">New Password</label>
              <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} minLength={6}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-400" required />
            </div>
            <button type="submit" disabled={loading}
              className="w-full py-3 bg-orange-500 text-white rounded-lg font-semibold hover:bg-orange-600 disabled:opacity-50">
              {loading ? 'Resetting...' : 'Reset Password'}
            </button>
            <button type="button" onClick={() => setMode('forgot')} className="w-full text-sm text-gray-500 hover:underline text-center">
              Resend OTP
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
