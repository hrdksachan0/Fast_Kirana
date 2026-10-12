'use client'

import { useState, type ReactNode } from 'react'
import { ArrowDown, ArrowUp, Copy, Plus, Trash2 } from 'lucide-react'
import type { CampaignBlock, CampaignConfig } from '@/lib/campaign-config'
import {
  blockPresentations,
  campaignBlockTypes,
  campaignMotionPresets,
  createCampaignBlock,
} from '@/lib/campaign-blocks'

const input =
  'w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/30'
const button =
  'inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-border px-3 py-2 text-xs font-semibold disabled:opacity-40 disabled:cursor-not-allowed'

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="text-text-secondary flex min-w-0 flex-col gap-1.5 text-xs font-semibold">
      <span>{label}</span>
      {children}
    </label>
  )
}

export function CampaignBlockEditor({
  data,
  onChange,
  renderImageField,
}: {
  data: CampaignConfig
  onChange: (blocks: CampaignBlock[]) => void
  renderImageField: (
    label: string,
    value: string | null,
    onChange: (image: string | null) => void
  ) => ReactNode
}) {
  const [type, setType] = useState<CampaignBlock['type']>('text')
  const blocks = data.blocks
  const patch = (id: string, update: Partial<CampaignBlock>) =>
    onChange(blocks.map((block) => (block.id === id ? { ...block, ...update } : block)))
  const move = (index: number, direction: number) => {
    const next = [...blocks]
    ;[next[index], next[index + direction]] = [next[index + direction], next[index]]
    onChange(next)
  }
  const newId = () => `block-${crypto.randomUUID()}`
  return (
    <div data-testid="campaign-block-editor" className="space-y-4">
      <p className="text-text-secondary text-sm leading-relaxed">
        Build the page in the order customers will see it. Add a block, choose its content and
        motion, then use Move up or Move down to arrange it.
      </p>
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-48 flex-1">
          <Field label="New block type">
            <select
              aria-label="New block type"
              className={input}
              value={type}
              onChange={(event) => setType(event.target.value as CampaignBlock['type'])}
            >
              {campaignBlockTypes.map((type) => (
                <option key={type.id} value={type.id}>
                  {type.name}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <button
          type="button"
          className={button}
          disabled={blocks.length >= 16}
          onClick={() => onChange([...blocks, createCampaignBlock(type, data, newId())])}
        >
          <Plus size={16} />
          Add block
        </button>
      </div>
      <p className="text-text-secondary text-xs">
        {campaignBlockTypes.find((entry) => entry.id === type)?.description} {blocks.length}/16
        blocks.
      </p>
      <ol className="divide-border divide-y">
        {blocks.map((block, index) => {
          const name = campaignBlockTypes.find((type) => type.id === block.type)!.name
          const label = `Block ${index + 1}`
          const source =
            block.type === 'banner'
              ? data.headers.map((item) => ({ id: item.id, label: item.title }))
              : block.type === 'categories'
                ? data.categories.map((item) => ({ id: item.id, label: item.label }))
                : block.type === 'spotlight'
                  ? data.products.map((item) => ({ id: item.id, label: item.name }))
                  : []
          const missing = block.itemIds.filter((id) => !source.some((item) => item.id === id))
          return (
            <li key={block.id} data-editor-block={block.id} className="space-y-3 py-5 first:pt-0">
              <div className="flex flex-wrap items-center gap-2">
                <h4 className="text-text-primary mr-auto text-sm font-bold">
                  {label}: {name}
                </h4>
                <button
                  type="button"
                  className={button}
                  aria-label={`Move ${label} up`}
                  disabled={index === 0}
                  onClick={() => move(index, -1)}
                >
                  <ArrowUp size={15} />
                </button>
                <button
                  type="button"
                  className={button}
                  aria-label={`Move ${label} down`}
                  disabled={index === blocks.length - 1}
                  onClick={() => move(index, 1)}
                >
                  <ArrowDown size={15} />
                </button>
                <button
                  type="button"
                  className={button}
                  aria-label={`Duplicate ${label}`}
                  disabled={blocks.length >= 16}
                  onClick={() => {
                    const next = [...blocks]
                    next.splice(index + 1, 0, { ...structuredClone(block), id: newId() })
                    onChange(next)
                  }}
                >
                  <Copy size={15} />
                </button>
                <button
                  type="button"
                  className={button}
                  aria-label={`Remove ${label}`}
                  disabled={blocks.length <= 1}
                  onClick={() => onChange(blocks.filter((item) => item.id !== block.id))}
                >
                  <Trash2 size={15} />
                </button>
              </div>
              <label className="text-text-primary flex items-center gap-2 text-xs">
                <input
                  type="checkbox"
                  checked={block.enabled}
                  disabled={block.enabled && blocks.filter((item) => item.enabled).length <= 1}
                  onChange={(event) => patch(block.id, { enabled: event.target.checked })}
                />
                Show {label.toLowerCase()}
              </label>
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label={`${label} heading`}>
                  <input
                    aria-label={`${label} heading`}
                    className={input}
                    value={block.title}
                    maxLength={200}
                    placeholder={
                      block.type === 'text' ? 'Your message heading' : 'Use the content’s heading'
                    }
                    onChange={(event) => patch(block.id, { title: event.target.value })}
                  />
                </Field>
                <Field label={`${label} presentation`}>
                  <select
                    aria-label={`${label} presentation`}
                    className={input}
                    value={block.presentation}
                    onChange={(event) =>
                      patch(block.id, {
                        presentation: event.target.value as CampaignBlock['presentation'],
                      })
                    }
                  >
                    {blockPresentations[block.type].map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.name}
                      </option>
                    ))}
                  </select>
                </Field>
              </div>
              <Field label={`${label} message`}>
                <textarea
                  aria-label={`${label} message`}
                  className={input}
                  rows={2}
                  maxLength={500}
                  value={block.body}
                  onChange={(event) => patch(block.id, { body: event.target.value })}
                />
              </Field>
              {source.length > 0 && (
                <fieldset className="space-y-2">
                  <legend className="text-text-secondary text-xs font-semibold">
                    {label} content
                  </legend>
                  <p className="text-text-secondary text-xs">
                    No selection uses all items. Selected items follow the order you choose them.
                    Edit their content in the sections below.
                  </p>
                  <div className="flex flex-wrap gap-x-4 gap-y-2">
                    {[
                      ...source,
                      ...missing.map((id) => ({ id, label: `Removed item: ${id}` })),
                    ].map((item) => (
                      <label
                        key={item.id}
                        className="text-text-primary flex items-center gap-2 text-xs"
                      >
                        <input
                          type="checkbox"
                          aria-label={`${label}: ${item.label}`}
                          checked={block.itemIds.includes(item.id)}
                          onChange={(event) =>
                            patch(block.id, {
                              itemIds: event.target.checked
                                ? [...block.itemIds, item.id]
                                : block.itemIds.filter((id) => id !== item.id),
                            })
                          }
                        />
                        {item.label}
                      </label>
                    ))}
                  </div>
                </fieldset>
              )}
              {block.type === 'collection' && (
                <Field label={`${label} collection`}>
                  <select
                    aria-label={`${label} collection`}
                    className={input}
                    value={block.tabId ?? ''}
                    onChange={(event) => patch(block.id, { tabId: event.target.value })}
                  >
                    <option value="" disabled>
                      Choose a collection
                    </option>
                    {data.tabs.map((tab) => (
                      <option key={tab.id} value={tab.id}>
                        {tab.label}
                      </option>
                    ))}
                  </select>
                </Field>
              )}
              {block.type === 'image' &&
                renderImageField(`${label} image`, block.image, (image) =>
                  patch(block.id, { image })
                )}
              {['image', 'text'].includes(block.type) && (
                <Field label={`${label} search destination`}>
                  <select
                    aria-label={`${label} search destination`}
                    className={input}
                    value={block.destinationId ?? ''}
                    onChange={(event) =>
                      patch(block.id, { destinationId: event.target.value || null })
                    }
                  >
                    <option value="">No link</option>
                    {data.destinations.map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.query || 'All catalogue products'}
                      </option>
                    ))}
                  </select>
                </Field>
              )}
              <div className="grid gap-3 sm:grid-cols-2">
                <Field label={`${label} animation`}>
                  <select
                    aria-label={`${label} animation`}
                    className={input}
                    value={block.motion.preset}
                    onChange={(event) =>
                      patch(block.id, {
                        motion: {
                          ...block.motion,
                          preset: event.target.value as CampaignBlock['motion']['preset'],
                        },
                      })
                    }
                  >
                    {campaignMotionPresets
                      .filter(
                        (item) =>
                          block.type !== 'text' || ['none', 'fade', 'slide'].includes(item.id)
                      )
                      .map((item) => (
                        <option key={item.id} value={item.id}>
                          {item.name}
                        </option>
                      ))}
                  </select>
                </Field>
                <Field label={`${label} animation speed`}>
                  <select
                    aria-label={`${label} animation speed`}
                    className={input}
                    value={block.motion.speed}
                    onChange={(event) =>
                      patch(block.id, {
                        motion: {
                          ...block.motion,
                          speed: event.target.value as CampaignBlock['motion']['speed'],
                        },
                      })
                    }
                  >
                    <option value="slow">Slow</option>
                    <option value="normal">Normal</option>
                    <option value="fast">Fast</option>
                  </select>
                </Field>
              </div>
            </li>
          )
        })}
      </ol>
      <p className="text-text-secondary text-xs leading-relaxed">
        Float, zoom and sparkle animate artwork while text stays steady. Pause preview or turn
        autoplay off for stationary content. Reduced-motion settings disable effects automatically.
      </p>
    </div>
  )
}
