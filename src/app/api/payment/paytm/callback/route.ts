import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { PaytmChecksum } from '@/lib/paytm-checksum';
import { sseEmitter } from '@/lib/sse-emitter';

export async function POST(request: NextRequest) {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

  try {
    const formData = await request.formData();
    const paytmParams: Record<string, string> = {};
    formData.forEach((value, key) => {
      paytmParams[key] = value.toString();
    });

    console.log('Paytm Callback params received:', paytmParams);

    const checksum = paytmParams.CHECKSUMHASH;
    if (!checksum) {
      console.error('Paytm Callback: Missing CHECKSUMHASH');
      return NextResponse.redirect(`${baseUrl}/checkout?payment=failed&reason=missing_checksum`, 303);
    }

    // Clean paytmParams by removing CHECKSUMHASH
    const paramsToVerify = { ...paytmParams };
    delete paramsToVerify.CHECKSUMHASH;

    const key = process.env.PAYTM_MERCHANT_KEY;
    if (!key) {
      console.error('Paytm Callback: PAYTM_MERCHANT_KEY not configured');
      return NextResponse.redirect(`${baseUrl}/checkout?payment=failed&reason=server_error`, 303);
    }

    const isValid = PaytmChecksum.verifySignature(paramsToVerify, key, checksum);
    if (!isValid) {
      console.error('Paytm Callback: Checksum verification failed');
      return NextResponse.redirect(`${baseUrl}/checkout?payment=failed&reason=invalid_signature`, 303);
    }

    const paytmOrderId = paytmParams.ORDERID;
    if (!paytmOrderId) {
      console.error('Paytm Callback: Missing ORDERID');
      return NextResponse.redirect(`${baseUrl}/checkout?payment=failed&reason=missing_order_id`, 303);
    }

    // Extract the original database order ID (split by the underscore)
    const orderId = paytmOrderId.split('_')[0];
    const status = paytmParams.STATUS;

    if (status === 'TXN_SUCCESS') {
      console.log(`Paytm Transaction Success for Order ID: ${orderId}`);

      // Update order status in database
      const updatedOrder = await prisma.order.update({
        where: { id: orderId },
        data: {
          paymentStatus: 'PAID'
        }
      });

      // Emit real-time SSE event for the updated order
      try {
        sseEmitter.emit('order', {
          type: 'status-change',
          orderId: orderId,
          status: updatedOrder.status,
          order: updatedOrder
        });
      } catch (sseErr) {
        console.error('Failed to emit SSE for paid order:', sseErr);
      }

      return NextResponse.redirect(`${baseUrl}/order/${orderId}?payment=success`, 303);
    } else {
      console.warn(`Paytm Transaction Failed/Cancelled for Order ID: ${orderId}. Status: ${status}`);

      // Update order paymentStatus to FAILED in database
      await prisma.order.update({
        where: { id: orderId },
        data: {
          paymentStatus: 'FAILED'
        }
      });

      const responseMessage = encodeURIComponent(paytmParams.RESPMSG || 'Payment failed');
      return NextResponse.redirect(`${baseUrl}/checkout?payment=failed&orderId=${orderId}&msg=${responseMessage}`, 303);
    }

  } catch (error: any) {
    console.error('Error handling Paytm callback:', error);
    return NextResponse.redirect(`${baseUrl}/checkout?payment=failed&reason=exception`, 303);
  }
}
