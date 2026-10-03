import Papa from 'papaparse'

export interface ParsedCsvProduct {
  id?: string
  name: string
  category: string
  unit: string
  mrp: string
  price: string
  stock: string
  tags: string
  description: string
  imageUrl: string
  costPrice: string
  minStock: string
  location: string
  variants?: string
}

export interface CsvValidationError {
  row: number
  field: string
  message: string
}

export interface CsvParseResult {
  products: ParsedCsvProduct[]
  errors: CsvValidationError[]
  totalRows: number
}

/**
 * Strips potential formula injection characters (=, +, -, @)
 * from strings when exporting or displaying spreadsheet data.
 */
export function sanitizeCsvField(val: string): string {
  if (!val) return ''
  const trimmed = val.trim()
  if (/^[=+\-@\t\r]/.test(trimmed)) {
    return `'${trimmed}`
  }
  return trimmed
}

/**
 * Parses variant strings in either:
 * - Parenthesis syntax: "1kg (price=150, mrp=180, stock=20, cost=120)"
 * - Colon-separated syntax: "1kg:150:180:20:120"
 */
export function parseVariantsString(variantsStr: string, defaultCostPrice = 0): Array<{
  name: string
  price: number
  mrp: number
  stock: number
  costPrice: number
}> | null {
  if (!variantsStr || !variantsStr.trim()) return null
  try {
    const parts = variantsStr.split('|')
    const parsed: Array<{
      name: string
      price: number
      mrp: number
      stock: number
      costPrice: number
    }> = []

    for (const part of parts) {
      const trimmedPart = part.trim()
      if (!trimmedPart) continue

      if (trimmedPart.includes('(') && trimmedPart.endsWith(')')) {
        const openParenIdx = trimmedPart.indexOf('(')
        const name = trimmedPart.substring(0, openParenIdx).trim()
        const paramsStr = trimmedPart.substring(openParenIdx + 1, trimmedPart.length - 1)
        const params = paramsStr.split(/[,;]/)
        let price = 0
        let mrp = 0
        let stock = 0
        let costPrice = defaultCostPrice

        for (const param of params) {
          const [key, val] = param.split('=').map((s) => s.trim().toLowerCase())
          if (!key || !val) continue
          const numVal = parseFloat(val) || 0
          if (['price', 'selling', 'selling_price'].includes(key)) price = numVal
          else if (['mrp', 'mrp_price'].includes(key)) mrp = numVal
          else if (['stock', 'qty', 'quantity'].includes(key)) stock = parseInt(val, 10) || 0
          else if (['cost', 'cost_price', 'costprice'].includes(key)) costPrice = numVal
        }

        if (name) {
          parsed.push({ name, price, mrp: mrp || price, stock, costPrice })
          continue
        }
      }

      const subparts = trimmedPart.split(':')
      const vName = subparts[0]?.trim()
      const vPrice = parseFloat(subparts[1]) || 0
      const vMrp = subparts[2] ? parseFloat(subparts[2]) : vPrice
      const vStock = subparts[3] ? parseInt(subparts[3], 10) : 0
      const vCostPrice = subparts[4] ? parseFloat(subparts[4]) : defaultCostPrice

      if (vName) {
        parsed.push({
          name: vName,
          price: vPrice,
          mrp: vMrp,
          stock: vStock,
          costPrice: isNaN(vCostPrice) ? defaultCostPrice : vCostPrice,
        })
      }
    }
    return parsed.length > 0 ? parsed : null
  } catch {
    return null
  }
}

/**
 * Robust CSV parser powered by PapaParse.
 * Validates header rows, empty rows, numeric fields, and returns structured data + errors.
 */
export function parseProductCsv(
  csvText: string,
  options?: {
    validCategoryNames?: Set<string>
    requireCategoryMatch?: boolean
  }
): CsvParseResult {
  const cleanText = csvText.replace(/^\uFEFF/, '') // Strip UTF-8 BOM if present

  const parsed = Papa.parse<string[]>(cleanText, {
    skipEmptyLines: 'greedy',
    transform: (value) => value.trim(),
  })

  const rows = parsed.data
  if (!rows || rows.length < 2) {
    return {
      products: [],
      errors: [{ row: 1, field: 'header', message: 'CSV file is empty or missing data rows' }],
      totalRows: 0,
    }
  }

  const headerRow = rows[0].map((h) => h.toLowerCase().replace(/[\s_-]+/g, ''))
  const colIndex = {
    id: headerRow.findIndex((h) => h === 'id' || h === 'productid'),
    name: headerRow.findIndex((h) => h === 'name' || h === 'productname' || h === 'title'),
    category: headerRow.findIndex((h) => h === 'category' || h === 'categoryname'),
    unit: headerRow.findIndex((h) => h === 'unit' || h === 'packsize' || h === 'weight'),
    mrp: headerRow.findIndex((h) => h === 'mrp' || h === 'mrpprice'),
    price: headerRow.findIndex((h) => h === 'price' || h === 'sellingprice' || h === 'rate'),
    stock: headerRow.findIndex((h) => h === 'stock' || h === 'quantity' || h === 'qty'),
    tags: headerRow.findIndex((h) => h === 'tags' || h === 'tag' || h === 'keywords'),
    description: headerRow.findIndex((h) => h === 'description' || h === 'desc'),
    imageUrl: headerRow.findIndex((h) => h === 'imageurl' || h === 'image' || h === 'photo'),
    costPrice: headerRow.findIndex((h) => h === 'costprice' || h === 'cost' || h === 'purchaseprice'),
    minStock: headerRow.findIndex((h) => h === 'minstock' || h === 'reorderlevel' || h === 'threshold'),
    location: headerRow.findIndex((h) => h === 'location' || h === 'aisle' || h === 'bin'),
    variants: headerRow.findIndex((h) => h === 'variants' || h === 'variant'),
  }

  const errors: CsvValidationError[] = []
  const products: ParsedCsvProduct[] = []

  if (colIndex.name === -1) {
    errors.push({ row: 1, field: 'Name', message: 'Missing required "Name" column header' })
    return { products, errors, totalRows: rows.length - 1 }
  }

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i]
    const rowNum = i + 1

    const name = colIndex.name !== -1 ? row[colIndex.name] || '' : ''
    const category = colIndex.category !== -1 ? row[colIndex.category] || '' : ''
    const unit = colIndex.unit !== -1 ? row[colIndex.unit] || '1 pc' : '1 pc'
    const mrp = colIndex.mrp !== -1 ? row[colIndex.mrp] || '' : ''
    const price = colIndex.price !== -1 ? row[colIndex.price] || '' : ''
    const stock = colIndex.stock !== -1 ? row[colIndex.stock] || '0' : '0'
    const tags = colIndex.tags !== -1 ? row[colIndex.tags] || '' : ''
    const description = colIndex.description !== -1 ? row[colIndex.description] || '' : ''
    const imageUrl = colIndex.imageUrl !== -1 ? row[colIndex.imageUrl] || '' : ''
    const costPrice = colIndex.costPrice !== -1 ? row[colIndex.costPrice] || '0' : '0'
    const minStock = colIndex.minStock !== -1 ? row[colIndex.minStock] || '5' : '5'
    const location = colIndex.location !== -1 ? row[colIndex.location] || '' : ''
    const variants = colIndex.variants !== -1 ? row[colIndex.variants] || '' : ''
    const id = colIndex.id !== -1 ? row[colIndex.id] || undefined : undefined

    if (!name.trim()) {
      errors.push({ row: rowNum, field: 'name', message: 'Product name is required' })
      continue
    }

    if (price && isNaN(parseFloat(price))) {
      errors.push({ row: rowNum, field: 'price', message: `Invalid price "${price}"` })
    }

    if (mrp && isNaN(parseFloat(mrp))) {
      errors.push({ row: rowNum, field: 'mrp', message: `Invalid MRP "${mrp}"` })
    }

    if (stock && isNaN(parseInt(stock, 10))) {
      errors.push({ row: rowNum, field: 'stock', message: `Invalid stock quantity "${stock}"` })
    }

    if (
      options?.requireCategoryMatch &&
      options.validCategoryNames &&
      category &&
      !options.validCategoryNames.has(category.toLowerCase().trim())
    ) {
      errors.push({ row: rowNum, field: 'category', message: `Unknown category "${category}"` })
    }

    products.push({
      id,
      name: sanitizeCsvField(name),
      category: sanitizeCsvField(category),
      unit: sanitizeCsvField(unit),
      mrp: mrp ? String(parseFloat(mrp) || 0) : '',
      price: price ? String(parseFloat(price) || 0) : '',
      stock: String(parseInt(stock, 10) || 0),
      tags: sanitizeCsvField(tags),
      description: sanitizeCsvField(description),
      imageUrl: imageUrl.trim(),
      costPrice: costPrice ? String(parseFloat(costPrice) || 0) : '0',
      minStock: minStock ? String(parseInt(minStock, 10) || 0) : '5',
      location: sanitizeCsvField(location),
      variants,
    })
  }

  return {
    products,
    errors,
    totalRows: rows.length - 1,
  }
}

/**
 * Exports products array to formatted CSV using PapaParse unparse.
 */
export function exportProductsToCsv(products: Array<Record<string, any>>): string {
  const data = products.map((p) => ({
    ID: p.id || '',
    Name: sanitizeCsvField(p.name || ''),
    Category: sanitizeCsvField(p.category?.name || p.category || ''),
    Unit: sanitizeCsvField(p.unit || '1 pc'),
    MRP: p.mrp ?? '',
    Price: p.price ?? '',
    Stock: p.stock ?? 0,
    Tags: Array.isArray(p.tags) ? p.tags.join(', ') : p.tags || '',
    Description: sanitizeCsvField(p.description || ''),
    'Image URL': p.imageUrl || '',
    'Cost Price': p.costPrice ?? 0,
    'Min Stock': p.minStock ?? 5,
    Location: sanitizeCsvField(p.location || ''),
    Variants: p.variants ? (typeof p.variants === 'string' ? p.variants : JSON.stringify(p.variants)) : '',
  }))

  return Papa.unparse(data, {
    quotes: true,
  })
}
