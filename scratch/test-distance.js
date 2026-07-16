function getDistanceKm(lat1, lng1, lat2, lng2) {
  const R = 6371
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLng = ((lng2 - lng1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

function getDeliveryRules(distanceKm) {
  if (distanceKm <= 2) {
    return { distanceKm, minOrder: 200, deliveryFee: 25, isServiceable: true, zoneName: '0-2 km' }
  }
  if (distanceKm <= 3) {
    return { distanceKm, minOrder: 300, deliveryFee: 35, isServiceable: true, zoneName: '2-3 km' }
  }
  if (distanceKm <= 4) {
    return { distanceKm, minOrder: 400, deliveryFee: 40, isServiceable: true, zoneName: '3-4 km' }
  }
  return { distanceKm, minOrder: 0, deliveryFee: 0, isServiceable: false, zoneName: '4+ km (out of range)' }
}

const DEFAULT_STORE_LAT = 26.1534185
const DEFAULT_STORE_LNG = 80.1714024

console.log('--- LOCAL TEST RESULTS FOR DISTANCE & DELIVERY FEES ---')

const testCases = [
  { name: 'Same location (Store)', lat: DEFAULT_STORE_LAT, lng: DEFAULT_STORE_LNG },
  { name: '1.4 km away (Zone 1)', lat: DEFAULT_STORE_LAT + 0.013, lng: DEFAULT_STORE_LNG },
  { name: '2.4 km away (Zone 2)', lat: DEFAULT_STORE_LAT + 0.022, lng: DEFAULT_STORE_LNG },
  { name: '3.4 km away (Zone 3)', lat: DEFAULT_STORE_LAT + 0.031, lng: DEFAULT_STORE_LNG },
  { name: '5.0 km away (Out of range)', lat: DEFAULT_STORE_LAT + 0.045, lng: DEFAULT_STORE_LNG },
]

testCases.forEach((tc) => {
  const dist = getDistanceKm(DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, tc.lat, tc.lng)
  const rules = getDeliveryRules(dist)
  console.log(`📍 ${tc.name}:`)
  console.log(`   - Distance: ${dist.toFixed(2)} km`)
  console.log(`   - Zone: ${rules.zoneName}`)
  console.log(`   - Serviceable: ${rules.isServiceable ? 'YES ✅' : 'NO ❌'}`)
  console.log(`   - Minimum Order Required: ₹${rules.minOrder}`)
  console.log(`   - Delivery Charge: ₹${rules.deliveryFee}`)
  console.log('')
})
