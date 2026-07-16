async function main() {
  const url = 'https://www.fastkirana.in/api/products?limit=500'
  try {
    const res = await fetch(url)
    const data = await res.json()
    console.log('API Status:', res.status)
    console.log('Total Products returned from API:', data.products?.length)
    console.log('API Pagination Total:', data.pagination?.total)
    
    // Check some samples
    const categories = new Set(data.products?.map((p: any) => p.category?.slug))
    console.log('Categories returned:', Array.from(categories))
  } catch (err) {
    console.error('Error fetching API:', err)
  }
}

main()
