import React, { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import api from '../services/api';
import toast from 'react-hot-toast';
import { useAuth } from '../context/AuthContext';

export default function Categories() {
  const { user } = useAuth();
  const [categories, setCategories] = useState([]);
  const [editing, setEditing] = useState(null);
  const { register, handleSubmit, reset } = useForm();
  const isAdmin = user?.role === 'admin';

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    try {
      const res = await api.get('/products/categories/all');
      setCategories(res.data.data);
    } catch (err) {
      toast.error('Failed to load categories');
    }
  };

  const onSubmit = async (data) => {
    try {
      if (editing) {
        await api.put(`/admin/categories/${editing}`, data);
        toast.success('Category updated');
      } else {
        const slug = data.name.toLowerCase().replace(/[^a-z0-9]+/g, '-');
        await api.post('/admin/categories', { ...data, slug });
        toast.success('Category created');
      }
      reset();
      setEditing(null);
      fetchCategories();
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to save category');
    }
  };

  const loadApparelPreset = async () => {
    try {
      await api.post('/admin/categories/seed-apparel');
      toast.success('Category presets synced');
      fetchCategories();
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to load apparel preset');
    }
  };

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-800 mb-6">Categories</h2>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {isAdmin && (
          <div className="lg:col-span-1">
            <div className="bg-white rounded-xl shadow-sm p-6">
              <h3 className="font-semibold text-gray-800 mb-4">
                {editing ? 'Edit Category' : 'Add Category'}
              </h3>
              <button
                type="button"
                onClick={loadApparelPreset}
                className="mb-4 w-full px-4 py-2 bg-indigo-50 text-indigo-700 rounded-lg hover:bg-indigo-100"
              >
                Load category presets (apparel + other major groups)
              </button>
              <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Name *</label>
                  <input {...register('name', { required: true })} className="w-full px-3 py-2 border rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                  <textarea {...register('description')} rows="2" className="w-full px-3 py-2 border rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Parent Category</label>
                  <select {...register('parentId')} className="w-full px-3 py-2 border rounded-lg">
                    <option value="">None (Top Level)</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>{cat.name}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Sort Order</label>
                  <input {...register('sortOrder')} type="number" defaultValue="0" className="w-full px-3 py-2 border rounded-lg" />
                </div>
                <div className="flex gap-2">
                  <button type="submit" className="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700">
                    {editing ? 'Update' : 'Create'}
                  </button>
                  {editing && (
                    <button type="button" onClick={() => { setEditing(null); reset(); }} className="px-4 py-2 bg-gray-200 rounded-lg">
                      Cancel
                    </button>
                  )}
                </div>
              </form>
            </div>
          </div>
        )}

        <div className={isAdmin ? 'lg:col-span-2' : 'lg:col-span-3'}>
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h3 className="font-semibold text-gray-800 mb-2">Available Categories</h3>
            <p className="text-sm text-gray-500 mb-4">Expanded parent and subcategory groups are available for product listing.</p>
            <div className="space-y-3">
              {categories.map((cat) => (
                <div key={cat.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg gap-4">
                  <div>
                    <span className="font-medium text-gray-800">{cat.name}</span>
                    {cat.description && <p className="text-sm text-gray-500 mt-1">{cat.description}</p>}
                    {cat.subcategories?.length > 0 && (
                      <div className="mt-2 space-y-1">
                        {cat.subcategories.map((sub) => (
                          <span key={sub.id} className="inline-block text-sm bg-gray-200 rounded px-2 py-0.5 mr-2 mb-2">
                            {sub.name}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                  {isAdmin && (
                    <button
                      onClick={() => { setEditing(cat.id); reset(cat); }}
                      className="text-sm text-primary-600 hover:underline"
                    >
                      Edit
                    </button>
                  )}
                </div>
              ))}
              {categories.length === 0 && <p className="text-gray-500">No categories yet</p>}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
