async function testLiveApi() {
  const url = 'https://www.fastkirana.in/api/auth/otp/send'
  console.log(`Sending POST request to ${url}...`)
  
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email: '9170942500' })
    })
    
    console.log('Response Status:', res.status)
    const data = await res.json()
    console.log('Response Body:', data)
  } catch (err) {
    console.error('Error during fetch:', err)
  }
}

testLiveApi()
