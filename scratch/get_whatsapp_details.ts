import 'dotenv/config'

async function getDetails() {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID

  if (!token || !phoneId) {
    console.error('Error: WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID must be set in your .env file.')
    process.exit(1)
  }

  try {
    console.log('--- Step 1: Debugging Access Token ---')
    const debugRes = await fetch(`https://graph.facebook.com/v20.0/debug_token?input_token=${token}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })

    const debugData = await debugRes.json()
    console.log('Debug Token Response:', JSON.stringify(debugData, null, 2))

    let wabaIds: string[] = []

    // Try to extract WABA ID from granular scopes
    if (debugData.data?.granular_scopes) {
      const waScope = debugData.data.granular_scopes.find(
        (s: any) => s.scope === 'whatsapp_business_management'
      )
      if (waScope && waScope.target_ids) {
        wabaIds = waScope.target_ids
      }
    }

    // Step 2: Try assigned_whatsapp_business_accounts
    if (wabaIds.length === 0) {
      const userId = debugData.data?.user_id || '122110291407356971'
      console.log(`\n--- Step 2: Querying WABAs via /${userId}/assigned_whatsapp_business_accounts ---`)
      const wabaRes = await fetch(`https://graph.facebook.com/v20.0/${userId}/assigned_whatsapp_business_accounts`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })
      const wabaData = await wabaRes.json()
      console.log('WABAs Response:', JSON.stringify(wabaData, null, 2))

      if (wabaData.data) {
        for (const waba of wabaData.data) {
          wabaIds.push(waba.id)
        }
      }
    }

    if (wabaIds.length === 0) {
      console.error('\n❌ Error: Could not retrieve any WhatsApp Business Account IDs (WABA IDs).')
      console.error('Please make sure your token has business_management and whatsapp_business_management permissions.')
      process.exit(1)
    }

    // Deduplicate WABA IDs
    wabaIds = Array.from(new Set(wabaIds))
    console.log(`\nFound WABA IDs: ${wabaIds.join(', ')}`)

    // Step 3: Fetch templates for each WABA ID found
    for (const wabaId of wabaIds) {
      console.log(`\n--- Message Templates for WABA ID: ${wabaId} ---`)
      const templatesRes = await fetch(`https://graph.facebook.com/v20.0/${wabaId}/message_templates`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      })

      const templatesData = await templatesRes.json()
      if (!templatesRes.ok) {
        console.error(`Failed to fetch templates for WABA ${wabaId}:`, templatesData)
        continue
      }

      if (templatesData.data && templatesData.data.length > 0) {
        for (const t of templatesData.data) {
          console.log(`- Name: ${t.name}`)
          console.log(`  Language: ${t.language}`)
          console.log(`  Status: ${t.status}`)
          console.log(`  Category: ${t.category}`)
          console.log(`  Components:`, JSON.stringify(t.components, null, 2))
          console.log('-----------------------------')
        }
      } else {
        console.log('No templates found in this account.')
      }
    }

  } catch (err) {
    console.error('Error fetching details:', err)
  }
}

getDetails()
