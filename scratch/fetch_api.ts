async function main() {
  const response = await fetch('https://fast-kirana-gray.vercel.app/api/products?category=cafe')
  const data = await response.json()
  const products = Array.isArray(data) ? data : (data.products || [])
  console.log("FIRST 5 PRODUCTS FROM API:")
  products.slice(0, 5).forEach((p: any) => {
    console.log(JSON.stringify(p, null, 2))
  })
}
main()
