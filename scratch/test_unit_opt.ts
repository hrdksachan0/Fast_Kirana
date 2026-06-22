import dotenv from 'dotenv'
dotenv.config()

async function runTests() {
  const adminHeaders = {
    'Content-Type': 'application/json',
    'x-user-id': 'mock-admin-id',
    'x-user-email': 'admin@fastkirana.com',
    'x-user-name': 'Admin User',
    'x-user-role': 'ADMIN',
    'x-user-phone': '+919999900000',
  }

  const baseUrl = 'http://localhost:3000'

  console.log('--- STARTING OPTIONAL UNIT TESTS (DEFAULT TO EMPTY STRING) ---')

  // Test 1: Create a product with missing/empty unit specification
  console.log('\n[Test 1] Creating a product with missing unit...')
  const createRes = await fetch(`${baseUrl}/api/products`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      name: `Test Unit Product ${Date.now()}`,
      categoryId: 'cmqgzqfz20008vkidoycqg5u2', // Beverages category
      mrp: 100,
      price: 90,
      stock: 50,
      isAvailable: true,
      // unit is omitted intentionally
    })
  })

  if (!createRes.ok) {
    const errorText = await createRes.text()
    console.error('Failed to create product:', errorText)
    process.exit(1)
  }

  const createdProduct = await createRes.json()
  console.log('Product created successfully!')
  console.log('ID:', createdProduct.id)
  console.log('Name:', createdProduct.name)
  console.log('Unit (Expected: ""):', JSON.stringify(createdProduct.unit))

  if (createdProduct.unit !== '') {
    console.error('FAIL: Product unit was not defaulted to empty string')
    process.exit(1)
  }
  console.log('SUCCESS: Product unit defaulted correctly.')

  // Test 2: Update the product's unit to empty string
  console.log('\n[Test 2] Updating product with empty unit...')
  const updateRes = await fetch(`${baseUrl}/api/products/${createdProduct.id}`, {
    method: 'PATCH',
    headers: adminHeaders,
    body: JSON.stringify({
      unit: '', // empty unit
    })
  })

  if (!updateRes.ok) {
    const errorText = await updateRes.text()
    console.error('Failed to update product:', errorText)
    process.exit(1)
  }

  const updatedProduct = await updateRes.json()
  console.log('Product updated successfully!')
  console.log('Unit (Expected: ""):', JSON.stringify(updatedProduct.unit))

  if (updatedProduct.unit !== '') {
    console.error('FAIL: Product unit was not defaulted to empty string after update')
    process.exit(1)
  }
  console.log('SUCCESS: Updated product unit defaulted correctly.')

  // Test 3: Bulk Import products with missing unit
  console.log('\n[Test 3] Testing Bulk Import with missing unit...')
  const bulkRes = await fetch(`${baseUrl}/api/admin/products/bulk-import`, {
    method: 'POST',
    headers: adminHeaders,
    body: JSON.stringify({
      products: [
        {
          name: `Bulk Import Prod A ${Date.now()}`,
          category: 'Beverages',
          mrp: '50',
          price: '45',
          stock: '20',
          // unit is missing
        },
        {
          name: `Bulk Import Prod B ${Date.now()}`,
          category: 'Beverages',
          mrp: '60',
          price: '55',
          stock: '15',
          unit: '  ', // whitespace unit
        }
      ]
    })
  })

  if (!bulkRes.ok) {
    const errorText = await bulkRes.text()
    console.error('Failed bulk import:', errorText)
    process.exit(1)
  }

  const bulkData = await bulkRes.json()
  console.log('Bulk import completed.')
  console.log('Results:', JSON.stringify(bulkData, null, 2))

  if (bulkData.skipped > 0 || bulkData.errors.length > 0) {
    console.error('FAIL: Bulk import had errors or skipped items.')
    process.exit(1)
  }

  for (const prod of bulkData.products) {
    if (prod.unit !== '') {
      console.error(`FAIL: Bulk imported product ${prod.name} unit was not defaulted to empty string:`, JSON.stringify(prod.unit))
      process.exit(1)
    }
  }

  console.log('SUCCESS: Bulk import completed with no errors.')

  console.log('\n--- ALL TESTS PASSED SUCCESSFULLY! ---')
}

runTests().catch(err => {
  console.error('Test execution failed:', err)
  process.exit(1)
})
