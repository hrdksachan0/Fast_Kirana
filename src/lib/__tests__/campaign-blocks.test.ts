import test from 'node:test'
import assert from 'node:assert/strict'
import { createCampaignFromTemplate } from '../campaign-templates'
import { parseCampaignConfig } from '../campaign-config'
import {
  campaignBlockItems,
  campaignBlockTypes,
  campaignMotionInterval,
  campaignMotionPresets,
  createCampaignBlock,
  defaultCampaignBlocks,
} from '../campaign-blocks'

test('old campaigns retain template composition and opt into blocks without mutating the source', () => {
  const data = createCampaignFromTemplate('diwali')
  assert.equal(data.composition, 'template')
  assert.deepEqual(data.blocks, [])
  const blocks = defaultCampaignBlocks(data)
  const result = parseCampaignConfig({ ...data, composition: 'blocks', blocks })
  assert.deepEqual(
    result.blocks.map((block) => block.type),
    ['banner', 'spotlight', 'categories', 'collection']
  )
  assert.deepEqual(data.blocks, [])
})

for (const { id: type } of campaignBlockTypes)
  test(`${type} supports isolated content, motion, visibility and round trips`, () => {
    const data = createCampaignFromTemplate('daily-essentials')
    const block = createCampaignBlock(type, data, `test-${type}`)
    block.motion = { preset: type === 'text' ? 'slide' : 'float', speed: 'slow' }
    const result = parseCampaignConfig({ ...data, composition: 'blocks', blocks: [block] })
    assert.deepEqual(JSON.parse(JSON.stringify(result.blocks)), [block])
  })

test('selected block items follow selection order and unavailable slots never substitute another product', () => {
  const items = [{ id: 'a' }, { id: 'b' }, { id: 'c' }]
  assert.deepEqual(campaignBlockItems(items, ['c', 'missing', 'a']), [items[2], items[0]])
  assert.equal(campaignBlockItems(items, []), items)
})

test('motion speeds respect existing autoplay interval bounds', () => {
  for (const preset of campaignMotionPresets) {
    assert.equal(campaignMotionInterval(4000, { preset: preset.id, speed: 'slow' }), 6000)
    assert.equal(campaignMotionInterval(2500, { preset: preset.id, speed: 'fast' }), 1625)
    assert.equal(campaignMotionInterval(1500, { preset: preset.id, speed: 'fast' }), 1500)
    assert.equal(campaignMotionInterval(60000, { preset: preset.id, speed: 'slow' }), 60000)
  }
})

test('malformed block references, images, presentations, motion and blank compositions cannot publish', () => {
  const base = createCampaignFromTemplate('diwali')
  const valid = { ...base, composition: 'blocks', blocks: defaultCampaignBlocks(base) }
  const edits = [
    (value: typeof valid) => {
      value.blocks = []
    },
    (value: typeof valid) => {
      value.blocks.forEach((block) => {
        block.enabled = false
      })
    },
    (value: typeof valid) => {
      value.blocks[1].id = value.blocks[0].id
    },
    (value: typeof valid) => {
      value.blocks[0].itemIds = ['missing']
    },
    (value: typeof valid) => {
      value.blocks[0].itemIds = [base.headers[0].id, base.headers[0].id]
    },
    (value: typeof valid) => {
      value.blocks[2].presentation = 'offer'
    },
    (value: typeof valid) => {
      value.blocks[3].tabId = 'missing'
    },
    (value: typeof valid) => {
      value.blocks[0].destinationId = 'missing'
    },
    (value: typeof valid) => {
      value.blocks[0].image = 'javascript:alert(1)'
    },
    (value: typeof valid) => {
      value.blocks = Array.from({ length: 17 }, (_, index) => ({
        ...value.blocks[0],
        id: `block-${index}`,
      }))
    },
  ]
  for (const edit of edits) {
    const value = structuredClone(valid)
    edit(value)
    assert.throws(() => parseCampaignConfig(value))
  }
  assert.throws(() =>
    parseCampaignConfig({
      ...base,
      blocks: [{ ...valid.blocks[0], motion: { preset: 'unknown' } }],
    })
  )
  assert.throws(() =>
    parseCampaignConfig({ ...base, blocks: [{ ...valid.blocks[0], script: 'alert(1)' }] })
  )
})

test('switching back to a template retains custom block content for later editing', () => {
  const data = createCampaignFromTemplate('holi')
  const blocks = defaultCampaignBlocks(data)
  blocks.reverse()
  const saved = parseCampaignConfig({ ...data, composition: 'template', blocks })
  assert.deepEqual(saved.blocks, blocks)
})

test('live compositions require real products only for displayed promotional slots', () => {
  const data = createCampaignFromTemplate('diwali')
  const image = createCampaignBlock('image', data, 'live-image')
  assert.doesNotThrow(() =>
    parseCampaignConfig({ ...data, demo: false, composition: 'blocks', blocks: [image] })
  )
  const spotlight = createCampaignBlock('spotlight', data, 'live-spotlight')
  spotlight.itemIds = [data.products[1].id]
  assert.throws(() =>
    parseCampaignConfig({ ...data, demo: false, composition: 'blocks', blocks: [spotlight] })
  )
  data.products[1].productId = 'catalogue-sku'
  assert.doesNotThrow(() =>
    parseCampaignConfig({ ...data, demo: false, composition: 'blocks', blocks: [spotlight] })
  )
  assert.throws(() => parseCampaignConfig({ ...data, demo: false, composition: 'template' }))
})
