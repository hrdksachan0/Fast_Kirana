'use client'

import React, { useState, useEffect } from 'react'
import { BakeryStoreConfig, BakeryTab, DEFAULT_BAKERY_CONFIG } from '@/lib/bakery-store-config'

export default function BakeryAdminPage() {
  const [config, setConfig] = useState<BakeryStoreConfig>(DEFAULT_BAKERY_CONFIG)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null)
  const [activeTabIdx, setActiveTabIdx] = useState(0)

  useEffect(() => {
    fetchConfig()
  }, [])

  async function fetchConfig() {
    setLoading(true)
    try {
      const res = await fetch('/api/admin/bakery-store')
      if (res.ok) {
        const data = await res.json()
        setConfig(data)
      }
    } catch (err) {
      console.error('Failed to load bakery config', err)
    } finally {
      setLoading(false)
    }
  }

  async function handleSave() {
    setSaving(true)
    setMessage(null)
    try {
      const res = await fetch('/api/admin/bakery-store', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config),
      })
      if (res.ok) {
        setMessage({ text: 'Bakery Store settings saved & live in Flutter app!', type: 'success' })
      } else {
        const err = await res.json()
        setMessage({ text: err.error || 'Failed to save settings', type: 'error' })
      }
    } catch (err) {
      setMessage({ text: 'Network error saving settings', type: 'error' })
    } finally {
      setSaving(false)
    }
  }

  function handleAddTab() {
    const newTab: BakeryTab = {
      id: `tab_${Date.now()}`,
      label: 'New\nCategory',
      title: 'New Category Items',
      subtitle: 'Freshly baked daily',
      emoji: '🥨',
      iconUrl: '',
      filterTags: ['fresh'],
      categorySlug: 'bakery',
      isActive: true,
      sortOrder: config.tabs.length + 1,
    }
    setConfig({ ...config, tabs: [...config.tabs, newTab] })
    setActiveTabIdx(config.tabs.length)
  }

  function handleRemoveTab(idx: number) {
    const updated = config.tabs.filter((_, i) => i !== idx)
    setConfig({ ...config, tabs: updated })
    if (activeTabIdx >= updated.length) {
      setActiveTabIdx(Math.max(0, updated.length - 1))
    }
  }

  function updateCurrentTab(field: keyof BakeryTab, value: any) {
    const updatedTabs = [...config.tabs]
    updatedTabs[activeTabIdx] = {
      ...updatedTabs[activeTabIdx],
      [field]: value,
    }
    setConfig({ ...config, tabs: updatedTabs })
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-900 text-white flex items-center justify-center">
        <div className="flex items-center gap-3">
          <div className="w-5 h-5 border-2 border-emerald-500 border-t-transparent rounded-full animate-spin"></div>
          <span className="font-semibold text-slate-300">Loading Bakery Store Config...</span>
        </div>
      </div>
    )
  }

  const currentTab = config.tabs[activeTabIdx]

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-6">
      {/* Top Bar */}
      <div className="max-w-6xl mx-auto flex items-center justify-between pb-6 border-b border-slate-800">
        <div>
          <div className="flex items-center gap-3">
            <span className="text-3xl">🥐</span>
            <div>
              <h1 className="text-2xl font-black text-white">Artisanal Bakery Store Manager</h1>
              <p className="text-xs text-slate-400 mt-0.5">
                Configure Blinkit-grade categories, lifestyle hero, and tags for FastMinute Flutter app (Cakes strictly excluded)
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setConfig(DEFAULT_BAKERY_CONFIG)}
            className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold rounded-xl transition"
          >
            Reset Default
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-black rounded-xl shadow-lg shadow-emerald-900/30 active:scale-95 transition disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save & Publish Live'}
          </button>
        </div>
      </div>

      {message && (
        <div
          className={`max-w-6xl mx-auto mt-4 p-3 rounded-xl text-xs font-bold ${
            message.type === 'success'
              ? 'bg-emerald-950/80 border border-emerald-500 text-emerald-300'
              : 'bg-rose-950/80 border border-rose-500 text-rose-300'
          }`}
        >
          {message.text}
        </div>
      )}

      {/* Editor Grid */}
      <div className="max-w-6xl mx-auto mt-6 grid grid-cols-1 lg:grid-cols-12 gap-8">
        
        {/* Left: Controls */}
        <div className="lg:col-span-7 space-y-6">
          
          {/* Section 1: Hero Banner Settings */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-sm">
            <h2 className="text-sm font-black text-white flex items-center gap-2 mb-4">
              <span>🖼️</span> Hero Lifestyle Banner
            </h2>

            <div className="space-y-4">
              <div>
                <label className="text-[11px] font-bold text-slate-400 uppercase">Banner Badge</label>
                <input
                  type="text"
                  value={config.bannerBadge}
                  onChange={(e) => setConfig({ ...config, bannerBadge: e.target.value })}
                  className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-bold text-white focus:border-emerald-500 focus:outline-none"
                  placeholder="⚡ FRESH BATCH 5:00 AM"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-[11px] font-bold text-slate-400 uppercase">Banner Title</label>
                  <input
                    type="text"
                    value={config.bannerTitle}
                    onChange={(e) => setConfig({ ...config, bannerTitle: e.target.value })}
                    className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-bold text-white focus:border-emerald-500 focus:outline-none"
                    placeholder="Baked fresh every morning"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-bold text-slate-400 uppercase">Banner Subtitle</label>
                  <input
                    type="text"
                    value={config.bannerSubtitle}
                    onChange={(e) => setConfig({ ...config, bannerSubtitle: e.target.value })}
                    className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-bold text-white focus:border-emerald-500 focus:outline-none"
                    placeholder="Warm crusts, soft pav & tea-time rusks"
                  />
                </div>
              </div>

              <div>
                <label className="text-[11px] font-bold text-slate-400 uppercase">Banner Image URL</label>
                <input
                  type="text"
                  value={config.bannerImageUrl}
                  onChange={(e) => setConfig({ ...config, bannerImageUrl: e.target.value })}
                  className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-medium text-white focus:border-emerald-500 focus:outline-none"
                  placeholder="https://..."
                />
              </div>
            </div>
          </div>

          {/* Section 2: Connected Arch Category Tabs */}
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-sm">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-black text-white flex items-center gap-2">
                <span>🏷️</span> Connected Arch Category Tabs ({config.tabs.length})
              </h2>
              <button
                onClick={handleAddTab}
                className="px-3 py-1 bg-emerald-600/20 text-emerald-400 hover:bg-emerald-600/30 text-xs font-bold rounded-lg transition"
              >
                + Add Tab
              </button>
            </div>

            {/* Tab Selector Pills */}
            <div className="flex gap-2 overflow-x-auto pb-3">
              {config.tabs.map((tab, idx) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTabIdx(idx)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 transition ${
                    activeTabIdx === idx
                      ? 'bg-emerald-600 text-white shadow-md'
                      : 'bg-slate-800 text-slate-400 hover:bg-slate-700'
                  }`}
                >
                  <span>{tab.emoji}</span>
                  <span>{tab.title.split(' ')[0]}</span>
                </button>
              ))}
            </div>

            {/* Active Tab Edit Panel */}
            {currentTab && (
              <div className="mt-4 pt-4 border-t border-slate-800 space-y-4">
                <div className="grid grid-cols-3 gap-3">
                  <div>
                    <label className="text-[11px] font-bold text-slate-400 uppercase">Emoji Icon</label>
                    <input
                      type="text"
                      value={currentTab.emoji}
                      onChange={(e) => updateCurrentTab('emoji', e.target.value)}
                      className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-sm font-bold text-center text-white focus:border-emerald-500 focus:outline-none"
                    />
                  </div>
                  <div className="col-span-2">
                    <label className="text-[11px] font-bold text-slate-400 uppercase">Arch Label (Line-broken)</label>
                    <input
                      type="text"
                      value={currentTab.label.replace('\n', ' ')}
                      onChange={(e) => updateCurrentTab('label', e.target.value)}
                      className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-bold text-white focus:border-emerald-500 focus:outline-none"
                      placeholder="Pav, Buns & Bases"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="text-[11px] font-bold text-slate-400 uppercase">Shelf Title</label>
                    <input
                      type="text"
                      value={currentTab.title}
                      onChange={(e) => updateCurrentTab('title', e.target.value)}
                      className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-bold text-white focus:border-emerald-500 focus:outline-none"
                      placeholder="Pav, Buns & Pizza Bases"
                    />
                  </div>
                  <div>
                    <label className="text-[11px] font-bold text-slate-400 uppercase">Shelf Subtitle</label>
                    <input
                      type="text"
                      value={currentTab.subtitle}
                      onChange={(e) => updateCurrentTab('subtitle', e.target.value)}
                      className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-medium text-white focus:border-emerald-500 focus:outline-none"
                      placeholder="Fresh batch from dark store"
                    />
                  </div>
                </div>

                <div>
                  <label className="text-[11px] font-bold text-slate-400 uppercase">
                    Filter Keywords (Comma separated)
                  </label>
                  <input
                    type="text"
                    value={currentTab.filterTags.join(', ')}
                    onChange={(e) =>
                      updateCurrentTab(
                        'filterTags',
                        e.target.value.split(',').map((s) => s.trim().toLowerCase())
                      )
                    }
                    className="w-full mt-1.5 px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs font-mono text-emerald-400 focus:border-emerald-500 focus:outline-none"
                    placeholder="pav, bun, burger bun, pizza base"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    Products in Supabase containing any of these keywords will automatically show in this tab.
                  </p>
                </div>

                <div className="flex items-center justify-between pt-2">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={currentTab.isActive}
                      onChange={(e) => updateCurrentTab('isActive', e.target.checked)}
                      className="w-4 h-4 rounded text-emerald-600 focus:ring-0"
                    />
                    <span className="text-xs font-bold text-slate-300">Active Tab in Mobile App</span>
                  </label>

                  {config.tabs.length > 1 && (
                    <button
                      onClick={() => handleRemoveTab(activeTabIdx)}
                      className="text-xs font-bold text-rose-400 hover:text-rose-300"
                    >
                      Delete Tab
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>

        </div>

        {/* Right: Live Mobile Preview */}
        <div className="lg:col-span-5 flex flex-col items-center">
          <div className="text-xs font-bold text-slate-400 mb-2 uppercase tracking-wider">
            Live Mobile App Preview (Glassmorphic)
          </div>
          
          <div className="w-[340px] h-[680px] bg-[#FAF8F3] text-slate-900 rounded-[40px] border-4 border-slate-800 shadow-2xl overflow-hidden flex flex-col select-none relative">
            {/* Ambient Mesh Orbs */}
            <div className="absolute -top-10 -left-10 w-40 h-40 bg-amber-200/50 rounded-full blur-2xl pointer-events-none"></div>
            <div className="absolute top-40 -right-10 w-44 h-44 bg-emerald-200/40 rounded-full blur-2xl pointer-events-none"></div>

            {/* Status bar */}
            <div className="pt-2.5 px-5 pb-1 flex justify-between items-center text-[10px] font-bold text-slate-800 z-10">
              <span>13:02</span>
              <div className="w-16 h-3 bg-black rounded-full"></div>
              <span>5G+ 🔋</span>
            </div>

            {/* Search */}
            <div className="px-3 pt-1 pb-2 z-10">
              <div className="bg-white/80 rounded-xl px-2.5 py-1.5 border border-white text-[11px] text-slate-400 font-medium shadow-xs">
                🔍 Search for bread, pav, rusk...
              </div>
            </div>

            {/* Hero Card */}
            <div className="px-3 pt-1 pb-2 z-10">
              <div className="bg-white/70 backdrop-blur-md rounded-xl p-2.5 border border-white/80 flex items-center justify-between shadow-xs">
                <div className="max-w-[170px]">
                  <span className="text-[8px] font-black text-emerald-800 bg-emerald-100 px-1.5 py-0.5 rounded">
                    {config.bannerBadge}
                  </span>
                  <div className="text-[13px] font-black text-[#134E5E] leading-tight mt-1">
                    {config.bannerTitle}
                  </div>
                  <div className="text-[9.5px] text-[#134E5E]/80 mt-0.5">
                    {config.bannerSubtitle}
                  </div>
                </div>
                <div className="w-16 h-14 rounded-lg overflow-hidden border border-white">
                  <img src={config.bannerImageUrl} className="w-full h-full object-cover" />
                </div>
              </div>
            </div>

            {/* Arch Tabs */}
            <div className="px-2.5 pt-2 flex gap-1.5 overflow-x-auto z-10 items-end">
              {config.tabs.filter((t) => t.isActive).map((t, i) => (
                <div
                  key={t.id}
                  className={`flex-shrink-0 w-16 p-1 text-center rounded-t-xl transition ${
                    i === activeTabIdx
                      ? 'bg-[#FAF8F3] border-t-2 border-l-2 border-r-2 border-slate-900 shadow-xs'
                      : 'bg-white/50 border border-white/60'
                  }`}
                >
                  <div className="text-base">{t.emoji}</div>
                  <div className="text-[8.5px] font-bold leading-tight mt-0.5 line-clamp-1">
                    {t.title.split(' ')[0]}
                  </div>
                </div>
              ))}
            </div>

            {/* Shelf line */}
            <div className="border-t-2 border-slate-900 px-3 pt-2 z-10 flex-1">
              <div className="text-[10px] font-black uppercase text-slate-800">
                {currentTab?.title || 'Bakery Items'}
              </div>

              {/* Sample Product Cards */}
              <div className="flex gap-2 mt-2">
                <div className="w-24 bg-white/90 rounded-xl p-1.5 border border-slate-200">
                  <div className="w-full aspect-square bg-slate-100 rounded-lg flex items-center justify-center text-xl">
                    🥖
                  </div>
                  <div className="mt-1 flex items-center justify-between">
                    <span className="text-[8.5px] font-bold text-slate-600">6 pcs</span>
                    <span className="text-[8.5px] font-black text-emerald-700 border border-emerald-700 px-1 rounded">
                      ADD
                    </span>
                  </div>
                  <div className="mt-1 bg-yellow-300 px-1 text-[9px] font-black inline-block rounded">
                    ₹25
                  </div>
                </div>
                <div className="w-24 bg-white/90 rounded-xl p-1.5 border border-slate-200">
                  <div className="w-full aspect-square bg-slate-100 rounded-lg flex items-center justify-center text-xl">
                    🍞
                  </div>
                  <div className="mt-1 flex items-center justify-between">
                    <span className="text-[8.5px] font-bold text-slate-600">400g</span>
                    <span className="text-[8.5px] font-black text-emerald-700 border border-emerald-700 px-1 rounded">
                      ADD
                    </span>
                  </div>
                  <div className="mt-1 bg-yellow-300 px-1 text-[9px] font-black inline-block rounded">
                    ₹45
                  </div>
                </div>
              </div>
            </div>

            {/* Liquid Emerald Cart Pill */}
            <div className="absolute bottom-4 left-4 right-4 bg-emerald-700 text-white rounded-full py-2 px-3 flex items-center justify-between shadow-xl z-20">
              <div className="flex items-center gap-2">
                <span className="text-xs">🍞</span>
                <span className="text-[11px] font-bold">View cart • 2 items</span>
              </div>
              <span className="text-[11px] font-black">₹70 &gt;</span>
            </div>
          </div>
        </div>

      </div>
    </div>
  )
}
