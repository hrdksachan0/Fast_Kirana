'use client'

import React from 'react'
import { X } from 'lucide-react'

export interface WhatsAppTargetUser {
  name: string
  phone: string
}

export interface WhatsAppAlertModalProps {
  isOpen: boolean
  targetUser: WhatsAppTargetUser | null
  selectedTemplateIdx: number
  customMessage: string
  onClose: () => void
  onSelectTemplate: (idx: number) => void
  onCustomMessageChange: (msg: string) => void
  onSendMessage: () => void
}

export function WhatsAppAlertModal({
  isOpen,
  targetUser,
  selectedTemplateIdx,
  customMessage,
  onClose,
  onSelectTemplate,
  onCustomMessageChange,
  onSendMessage,
}: WhatsAppAlertModalProps) {
  if (!isOpen || !targetUser) return null

  const templates = [
    '🛒 Cart Waiting (Standard)',
    '🎁 Special Offer (Discount code SAVE10)',
    '👋 Gentle Reminder (Before stock runs out)',
  ]

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
      <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-md p-6 animate-scale-up space-y-4">
        <div className="flex justify-between items-center border-b border-border/60 pb-3">
          <div>
            <h4 className="font-extrabold text-text-primary text-base flex items-center gap-1.5">
              <span>🟢</span> Send WhatsApp Alert
            </h4>
            <p className="text-[10px] text-text-secondary mt-0.5 font-bold">
              To: <span className="font-extrabold text-text-primary">{targetUser.name}</span> ({targetUser.phone})
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-text-secondary hover:text-text-primary p-1 rounded-lg hover:bg-muted cursor-pointer"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="space-y-3">
          <label className="text-[10px] font-bold text-text-secondary block">
            Select a Message Template
          </label>
          <div className="space-y-2">
            {templates.map((name, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => onSelectTemplate(idx)}
                className={`w-full text-left px-3 py-2.5 text-xs rounded-xl border transition-all font-bold cursor-pointer ${
                  selectedTemplateIdx === idx
                    ? 'bg-emerald-500/10 border-emerald-500 text-emerald-600 dark:text-emerald-400'
                    : 'bg-muted/10 border-border hover:bg-muted/30 text-text-primary'
                }`}
              >
                {name}
              </button>
            ))}
          </div>

          <div className="space-y-1">
            <label className="text-[10px] font-bold text-text-secondary block">
              Message Preview / Edit
            </label>
            <textarea
              value={customMessage}
              onChange={(e) => onCustomMessageChange(e.target.value)}
              rows={4}
              className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-emerald-500 font-bold leading-relaxed resize-none"
            />
          </div>
        </div>

        <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onSendMessage}
            className="flex items-center gap-1.5 px-5 py-2 bg-emerald-500 hover:bg-emerald-600 text-white text-xs font-bold rounded-xl transition-all shadow-sm cursor-pointer"
          >
            <span>🟢</span> Open WhatsApp
          </button>
        </div>
      </div>
    </div>
  )
}
