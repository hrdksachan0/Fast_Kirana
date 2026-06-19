async function main() {
  const response = await fetch('https://fast-kirana-gray.vercel.app/api/products?category=beverages')
  const data = await response.json()
  console.log("RESPONSE FROM LIVE API:")
  console.log(JSON.stringify(data, null, 2))
}
main()

