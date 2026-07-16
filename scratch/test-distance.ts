import { getDistanceKm, getDeliveryRules, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '../src/lib/distance'

console.log('--- TESTING DISTANCE & DELIVERY RULES ---')

// Test 1: Exact store coordinates (0 km)
const dist0 = getDistanceKm(DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG)
const rules0 = getDeliveryRules(dist0)
console.log(`Test 1 (0 km): Distance=${dist0.toFixed(2)}km, MinOrder=₹${rules0.minOrder}, DeliveryFee=₹${rules0.deliveryFee}, Serviceable=${rules0.isServiceable}`)

// Test 2: Point ~1.5 km away
// Approx 0.013 deg lat ~ 1.44 km
const dist1 = getDistanceKm(DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, DEFAULT_STORE_LAT + 0.013, DEFAULT_STORE_LNG)
const rules1 = getDeliveryRules(dist1)
console.log(`Test 2 (~1.5 km): Distance=${dist1.toFixed(2)}km, Zone=${rules1.zoneName}, MinOrder=₹${rules1.minOrder}, DeliveryFee=₹${rules1.deliveryFee}`)

// Test 3: Point ~2.5 km away
// Approx 0.022 deg lat ~ 2.44 km
const dist2 = getDistanceKm(DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, DEFAULT_STORE_LAT + 0.022, DEFAULT_STORE_LNG)
const rules2 = getDeliveryRules(dist2)
console.log(`Test 3 (~2.5 km): Distance=${dist2.toFixed(2)}km, Zone=${rules2.zoneName}, MinOrder=₹${rules2.minOrder}, DeliveryFee=₹${rules2.deliveryFee}`)

// Test 4: Point ~3.5 km away
// Approx 0.031 deg lat ~ 3.44 km
const dist3 = getDistanceKm(DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, DEFAULT_STORE_LAT + 0.031, DEFAULT_STORE_LNG)
const rules3 = getDeliveryRules(dist3)
console.log(`Test 4 (~3.5 km): Distance=${dist3.toFixed(2)}km, Zone=${rules3.zoneName}, MinOrder=₹${rules3.minOrder}, DeliveryFee=₹${rules3.deliveryFee}`)

// Test 5: Point ~5 km away (out of range)
const dist4 = getDistanceKm(DEFAULT_STORE_LAT, DEFAULT_STORE_LNG, DEFAULT_STORE_LAT + 0.045, DEFAULT_STORE_LNG)
const rules4 = getDeliveryRules(dist4)
console.log(`Test 5 (~5.0 km): Distance=${dist4.toFixed(2)}km, Zone=${rules4.zoneName}, Serviceable=${rules4.isServiceable}`)

console.log('--- TEST COMPLETED ---')
