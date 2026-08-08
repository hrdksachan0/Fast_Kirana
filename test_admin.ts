import 'dotenv/config'

async function main() {
  const res = await fetch('http://localhost:3000/api/auth/otp/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: '+917054470303' })
  })
  const json = await res.json()
  console.log('Status:', res.status)
  console.log('Response:', JSON.stringify(json))
}

main()
