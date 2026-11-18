import { sendFast2Sms } from '@/lib/fast2sms'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { getLast10Digits } from '@/lib/phone'

export interface GiftRecipientAlertOptions {
  orderId: string
  readableId: string
  recipientPhone: string
  recipientName?: string
  senderName?: string
  giftNote?: string
  trackingUrl: string
}

/**
 * Sends a surprise gift notification to the recipient with a live tracking link.
 * Price is 100% hidden on the tracking page.
 * Uses WhatsApp Cloud API with automatic fallback to Fast2SMS.
 */
export async function sendGiftRecipientNotification(
  options: GiftRecipientAlertOptions
): Promise<{ success: boolean; channel: 'whatsapp' | 'sms' | 'none' }> {
  const { orderId, readableId, recipientPhone, recipientName, senderName, giftNote, trackingUrl } = options

  const cleanPhone = getLast10Digits(recipientPhone)
  if (!cleanPhone || cleanPhone.length !== 10) {
    console.warn(`[GiftAlert] Invalid recipient phone: ${recipientPhone}`)
    return { success: false, channel: 'none' }
  }

  const toName = recipientName ? recipientName.trim() : 'Someone Special'
  const fromName = senderName ? senderName.trim() : 'a loved one'
  const noteSnippet = giftNote ? `\n💌 Personal Note: "${giftNote.trim()}"` : ''

  // 1. WhatsApp formatted alert message
  const waMessage = `🎁 *Surprise Gift for ${toName}!* 🎁\n\n${fromName} has sent you a special gift via FastMinute! ✨${noteSnippet}\n\n📍 *Track your surprise delivery live:*\n${trackingUrl}\n\nOur delivery partner is bringing it right to your door with a free complimentary handwritten greeting card! 💖`

  // 2. Compact SMS formatted message
  const smsMessage = `Surprise Gift for ${toName}! ${fromName} sent you a gift via FastMinute. Track live: ${trackingUrl} . Enjoy your special day!`

  const dedupeKey = `gift_track_${orderId}_${cleanPhone}`

  try {
    // Attempt WhatsApp delivery first
    const waSent = await sendWhatsAppOrderAlert(cleanPhone, waMessage, dedupeKey)
    if (waSent) {
      console.log(`[GiftAlert] Successfully dispatched WhatsApp gift tracking link to ${cleanPhone}`)
      return { success: true, channel: 'whatsapp' }
    }
  } catch (waErr) {
    console.warn('[GiftAlert] WhatsApp gift send failed, attempting Fast2SMS fallback:', waErr)
  }

  try {
    // Fallback to Fast2SMS
    const smsSent = await sendFast2Sms({
      numbers: cleanPhone,
      message: smsMessage,
    })
    if (smsSent) {
      console.log(`[GiftAlert] Successfully dispatched SMS gift tracking link to ${cleanPhone}`)
      return { success: true, channel: 'sms' }
    }
  } catch (smsErr) {
    console.error('[GiftAlert] Fast2SMS fallback also failed:', smsErr)
  }

  return { success: false, channel: 'none' }
}
