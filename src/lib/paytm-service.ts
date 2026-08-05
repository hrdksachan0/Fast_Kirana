/**
 * Paytm Gateway Integration Helper
 */

export interface PaytmInitOptions {
  orderId: string
  txnToken: string
  amount: number
  callbackUrl?: string
}

export function openPaytmCheckout(options: PaytmInitOptions): Promise<{ success: boolean; data?: any; error?: string }> {
  return new Promise((resolve) => {
    if (typeof window === 'undefined' || !(window as any).Paytm) {
      resolve({ success: false, error: 'Paytm JS SDK not loaded.' })
      return
    }

    const paytmConfig = {
      root: '',
      flow: 'DEFAULT',
      data: {
        orderId: options.orderId,
        token: options.txnToken,
        tokenType: 'TXN_TOKEN',
        amount: options.amount,
      },
      handler: {
        notifyMerchant: (eventName: string, data: any) => {
          console.log('Paytm Event:', eventName, data)
        },
        transactionStatus: (data: any) => {
          if (data && data.STATUS === 'TXN_SUCCESS') {
            resolve({ success: true, data })
          } else {
            resolve({ success: false, error: data?.RESPMSG || 'Transaction failed or cancelled.' })
          }
        },
      },
    }

    try {
      (window as any).Paytm.CheckoutJS.init(paytmConfig)
        .then(() => {
          (window as any).Paytm.CheckoutJS.invoke()
        })
        .catch((err: any) => {
          resolve({ success: false, error: err?.message || 'Failed to open Paytm Checkout.' })
        })
    } catch (e: any) {
      resolve({ success: false, error: e?.message || 'Paytm error.' })
    }
  })
}
