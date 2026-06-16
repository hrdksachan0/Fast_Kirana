import 'dotenv/config'

async function runApiTest() {
  const payload = {
    addressId: 'STORE_PICKUP',
    paymentMethod: 'COD',
    items: [
      {
        product: {
          id: 'cmqc8nzb4001c04jxrovu4cnp', // Butter Paneer Dosa
          slug: 'butter-paneer-dosa',
          name: 'Butter Paneer Dosa',
          price: 94,
          mrp: 105,
          stock: 99996,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 2
      },
      {
        product: {
          id: 'cmqc8n6gu000e04jxotc6obtg', // Veg Sandwitch
          slug: 'veg-sandwitch',
          name: 'Veg Sandwitch',
          price: 59,
          mrp: 69,
          stock: 99998,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 1
      },
      {
        product: {
          id: 'cmqc8o63l001k04jxgo2j5d9v', // Chilli Potato
          slug: 'chilli-potato',
          name: 'Chilli Potato',
          price: 94,
          mrp: 99,
          stock: 99998,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 1
      },
      {
        product: {
          id: 'cmqc8o3k2001h04jxa7xs28my', // Chili Paneer - Gravy
          slug: 'chili-paneer-gravy',
          name: 'Chili Paneer - Gravy',
          price: 134,
          mrp: 149,
          stock: 99997,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 1
      }
    ],
    deliveryMethod: 'PICKUP',
    isB2B: false,
    scheduledSlot: 'INSTANT'
  }

  const response = await fetch('http://localhost:3001/api/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-user-id': 'cmqc83g3300046widktkvx6m7',
      'x-user-email': 'user@fastkirana.com',
      'x-user-name': 'Rahul Sharma',
      'x-user-role': 'USER'
    },
    body: JSON.stringify(payload)
  })

  console.log('Response status:', response.status)
  const text = await response.text()
  console.log('Response body:', text)
}

runApiTest().catch(console.error)
