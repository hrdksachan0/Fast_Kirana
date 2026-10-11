import { copyFile, mkdir, readFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const source = path.join(root, 'public', 'navratri')
const target = path.join(root, 'fastkirana_flutter', 'assets', 'navratri')
const indexFile = 'templates/index.json'
const templates = JSON.parse(await readFile(path.join(source, indexFile), 'utf8'))
const types = new Set(['Festival', 'Everyday', 'Value', 'Seasonal'])
const files = new Set([indexFile])
const ids = new Set()
const manifests = new Set()

if (!Array.isArray(templates) || !templates.length) {
  throw new Error('Campaign template index must be a non-empty array')
}

async function includeImage(image, context) {
  if (
    typeof image !== 'string' ||
    !/^[a-zA-Z0-9][a-zA-Z0-9._-]*\.svg$/.test(image) ||
    image.includes('..')
  ) {
    throw new Error(`${context}: expected a local SVG file name, received ${image}`)
  }
  await readFile(path.join(source, image))
  files.add(image)
}

for (const template of templates) {
  if (
    !template ||
    typeof template.id !== 'string' ||
    !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(template.id) ||
    ids.has(template.id) ||
    typeof template.name !== 'string' ||
    !template.name.trim() ||
    typeof template.description !== 'string' ||
    !template.description.trim() ||
    !types.has(template.type)
  ) {
    throw new Error('Campaign template index contains invalid or duplicate metadata')
  }
  const expectedManifest =
    template.id === 'navratri' ? 'navratri.json' : `templates/${template.id}.json`
  if (template.manifest !== expectedManifest || manifests.has(template.manifest)) {
    throw new Error(`${template.id}: manifest must be ${expectedManifest}`)
  }
  ids.add(template.id)
  manifests.add(template.manifest)
  await includeImage(template.thumbnail, `${template.id} thumbnail`)
  const manifest = JSON.parse(await readFile(path.join(source, template.manifest), 'utf8'))
  const collections = ['headers', 'products', 'categories', 'tabs']
  for (const collection of collections) {
    if (!Array.isArray(manifest[collection])) {
      throw new Error(`${template.id}: missing ${collection} collection`)
    }
    for (const entry of manifest[collection]) {
      if (entry.image !== null) await includeImage(entry.image, `${template.id} ${collection}`)
    }
  }
  if (manifest.decorationImage !== null && manifest.decorationImage !== undefined) {
    await includeImage(manifest.decorationImage, `${template.id} decoration`)
  }
  files.add(template.manifest)
}

for (const file of files) {
  const destination = path.join(target, file)
  await mkdir(path.dirname(destination), { recursive: true })
  await copyFile(path.join(source, file), destination)
}
console.log(
  `Synced ${files.size} campaign files (${templates.length} templates) from public/navratri to Flutter assets.`
)
