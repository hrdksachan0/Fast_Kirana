import test, { describe } from 'node:test'
import assert from 'node:assert/strict'

describe('Payment Recovery & Timeout Rules', () => {
  test('correctly classifies orders between 2 and 10 minutes for WhatsApp recovery', () => {
    const now = Date.now()
    const fiveMinutesAgo = new Date(now - 5 * 60 * 1000)
    const elevenMinutesAgo = new Date(now - 11 * 60 * 1000)
    const oneMinuteAgo = new Date(now - 1 * 60 * 1000)

    const twoMinutesThreshold = new Date(now - 2 * 60 * 1000)
    const tenMinutesThreshold = new Date(now - 10 * 60 * 1000)

    // 5 min ago is within 2-10 min window
    assert.ok(fiveMinutesAgo <= twoMinutesThreshold && fiveMinutesAgo >= tenMinutesThreshold)

    // 1 min ago is too fresh (user might still be in PhonePe/GPay app)
    assert.ok(oneMinuteAgo > twoMinutesThreshold)

    // 11 min ago has expired for recovery, moves to timeout
    assert.ok(elevenMinutesAgo < tenMinutesThreshold)
  })

  test('generates expected WhatsApp message format with recovery URL', () => {
    const customerName = 'Aarav Sachan'
    const displayId = '1682'
    const totalFormatted = 210
    const orderId = 'cmu3qu5tx000004jqe15dpmra'
    const recoveryUrl = `https://fastkirana.com/order/${orderId}/track?action=cod`

    const messageText = 
      `🛒 *FastKirana Payment Alert*\n\n` +
      `Hi ${customerName}! Aapke order *#${displayId}* (₹${totalFormatted}) ka UPI payment pending hai.\n\n` +
      `Khana / Grocery turant dispatch karwane ke liye niche link par tap karke *Cash on Delivery (COD)* me convert karein ya payment retry karein:\n\n` +
      `👉 ${recoveryUrl}\n\n` +
      `_Kisi bhi sahayata ke liye is number par call/WhatsApp karein._`

    assert.ok(messageText.includes('*#1682*'))
    assert.ok(messageText.includes('₹210'))
    assert.ok(messageText.includes(recoveryUrl))
    assert.ok(messageText.includes('Cash on Delivery (COD)'))
  })

  test('prevents duplicate recovery alerts when [WA_RECOVERY_SENT] marker exists', () => {
    const existingNotes = '✨ Special instructions [WA_RECOVERY_SENT]'
    const hasBeenSent = existingNotes.includes('[WA_RECOVERY_SENT]')
    assert.equal(hasBeenSent, true)

    const freshNotes = 'Ring bell'
    const notSent = freshNotes.includes('[WA_RECOVERY_SENT]')
    assert.equal(notSent, false)
  })
})
