export interface OrderRecipientInfo {
  isOrderForSomeone: boolean
  recipientName: string
  recipientPhone: string | null
  buyerName: string | null
  buyerPhone: string | null
  deliveryInstructions: string | null
  fullRecipientLabel: string
}

export function parseOrderRecipient(order: any): OrderRecipientInfo {
  if (!order) {
    return {
      isOrderForSomeone: false,
      recipientName: 'Customer',
      recipientPhone: null,
      buyerName: null,
      buyerPhone: null,
      deliveryInstructions: null,
      fullRecipientLabel: 'Customer',
    }
  }

  const customer = order.user || {}
  const address = order.address || {}

  const buyerName =
    (customer.name && typeof customer.name === 'string' && customer.name.trim()) ||
    (order.userName && typeof order.userName === 'string' && order.userName.trim()) ||
    null

  const buyerPhone =
    (customer.phone && typeof customer.phone === 'string' && customer.phone.trim()) ||
    null

  const defaultPhone =
    (address.phone && typeof address.phone === 'string' && address.phone.trim()) ||
    buyerPhone ||
    (order.shopPhone && typeof order.shopPhone === 'string' && order.shopPhone.trim()) ||
    null

  const notes = (order.notes || '').trim()

  // 1. Direct fields if any
  const directReceiverName = order.receiverName && typeof order.receiverName === 'string' ? order.receiverName.trim() : null
  const directReceiverPhone = order.receiverPhone && typeof order.receiverPhone === 'string' ? order.receiverPhone.trim() : null

  if (directReceiverName) {
    const phone = directReceiverPhone || defaultPhone
    return {
      isOrderForSomeone: true,
      recipientName: directReceiverName,
      recipientPhone: phone,
      buyerName,
      buyerPhone,
      deliveryInstructions: notes || null,
      fullRecipientLabel: phone ? `${directReceiverName} (${phone})` : directReceiverName,
    }
  }

  // 2. Parse from notes: "🎁 Order for: Rahul (9876543210) | instructions"
  if (notes && notes.includes('Order for:')) {
    const parts = notes.split('|')
    const firstPart = parts[0].trim()

    let recipientPart = firstPart.replace(/🎁/g, '').trim()
    const orderForIdx = recipientPart.toLowerCase().indexOf('order for:')
    if (orderForIdx !== -1) {
      recipientPart = recipientPart.substring(orderForIdx + 'order for:'.length).trim()
    }

    let parsedName = recipientPart
    let parsedPhone: string | null = null

    // Match "Name (Phone)"
    const match = recipientPart.match(/^(.*?)(?:\s*\(([\d\+\s\-]{7,15})\))?$/)
    if (match) {
      if (match[1]?.trim()) parsedName = match[1].trim()
      if (match[2]?.trim()) parsedPhone = match[2].trim()
    }

    const instructions = parts.slice(1).join(' | ').trim()

    if (parsedName) {
      const effectivePhone = parsedPhone || defaultPhone
      return {
        isOrderForSomeone: true,
        recipientName: parsedName,
        recipientPhone: effectivePhone,
        buyerName,
        buyerPhone,
        deliveryInstructions: instructions || null,
        fullRecipientLabel: recipientPart,
      }
    }
  }

  // Standard Order
  const fallbackName =
    (address.name && typeof address.name === 'string' && address.name.trim()) ||
    buyerName ||
    'Customer'

  return {
    isOrderForSomeone: false,
    recipientName: fallbackName,
    recipientPhone: defaultPhone,
    buyerName: null,
    buyerPhone,
    deliveryInstructions: notes || null,
    fullRecipientLabel: fallbackName,
  }
}
