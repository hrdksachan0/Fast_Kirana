function parseVariants(variantsStr: string, mainCostPrice: number = 0) {
  try {
    const parts = variantsStr.split('|')
    const parsed: any[] = []
    
    for (const part of parts) {
      const trimmedPart = part.trim()
      if (!trimmedPart) continue

      // Try parsing key-value parenthesis format first: Name (price=15, mrp=20, stock=45, cost=10)
      if (trimmedPart.includes('(') && trimmedPart.endsWith(')')) {
        const openParenIdx = trimmedPart.indexOf('(')
        const name = trimmedPart.substring(0, openParenIdx).trim()
        const paramsStr = trimmedPart.substring(openParenIdx + 1, trimmedPart.length - 1)
        
        const params = paramsStr.split(/[,;]/)
        let price = 0
        let mrp = 0
        let stock = 0
        let costPrice = mainCostPrice

        for (const param of params) {
          const [key, val] = param.split('=').map(s => s.trim().toLowerCase())
          if (!key || !val) continue
          const numVal = parseFloat(val) || 0
          
          if (['price', 'selling', 'selling_price'].includes(key)) {
            price = numVal
          } else if (['mrp', 'mrp_price'].includes(key)) {
            mrp = numVal
          } else if (['stock', 'qty', 'quantity'].includes(key)) {
            stock = parseInt(val) || 0
          } else if (['cost', 'cost_price', 'costprice'].includes(key)) {
            costPrice = numVal
          }
        }

        if (name) {
          parsed.push({
            name,
            price,
            mrp: mrp || price,
            stock,
            costPrice
          })
          continue
        }
      }

      // Fallback to colon-separated format: Name:Price:MRP:Stock:CostPrice
      const subparts = trimmedPart.split(':')
      const vName = subparts[0]?.trim()
      const vPrice = parseFloat(subparts[1]) || 0
      const vMrp = subparts[2] ? parseFloat(subparts[2]) : vPrice
      const vStock = subparts[3] ? parseInt(subparts[3]) : 0
      let vCostPrice = subparts[4] ? parseFloat(subparts[4]) : undefined

      if (vCostPrice === undefined || isNaN(vCostPrice)) {
        vCostPrice = mainCostPrice
      }

      if (vName) {
        parsed.push({
          name: vName,
          price: vPrice,
          mrp: vMrp,
          stock: vStock,
          costPrice: vCostPrice
        })
      }
    }
    return parsed
  } catch (e) {
    return null
  }
}

console.log('Test 1 (Key-Value format):', parseVariants('50 gms (price=15, mrp=20, stock=45, cost=10) | 100 gms (price=25, mrp=30, stock=50)', 8))
console.log('Test 2 (Colon format with cost):', parseVariants('Silk Plain:89:89:3:84', 75))
console.log('Test 3 (Colon format fallback to main cost):', parseVariants('Ganache:98:100:2', 75))
console.log('Test 4 (Colon format with trailing colon):', parseVariants('Ganache:98:100:2:', 75))
