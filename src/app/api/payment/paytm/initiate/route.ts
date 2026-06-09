import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/auth';
import { prisma } from '@/lib/prisma';
import { PaytmChecksum } from '@/lib/paytm-checksum';

export async function POST(request: NextRequest) {
  const session = await auth();
  const userId = session?.user?.id;
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const { orderId } = await request.json();
    if (!orderId) {
      return NextResponse.json({ error: 'Missing orderId' }, { status: 400 });
    }

    // Fetch order from database to verify amount and ownership
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: { user: true }
    });

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 });
    }

    if (order.userId !== userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    if (order.paymentStatus === 'PAID') {
      return NextResponse.json({ error: 'Order is already paid' }, { status: 400 });
    }

    const mid = process.env.PAYTM_MID;
    const key = process.env.PAYTM_MERCHANT_KEY;
    const website = process.env.PAYTM_WEBSITE || 'WEBSTAGING';
    const env = process.env.PAYTM_ENV || 'stage';

    if (!mid || !key) {
      return NextResponse.json({ error: 'Paytm credentials not configured on server' }, { status: 500 });
    }

    // Generate a unique order ID for Paytm to avoid "Duplicate Order ID" error
    // Format: orderId_timestamp
    const paytmOrderId = `${orderId}_${Date.now()}`;
    const amountStr = order.total.toFixed(2);

    const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
    const callbackUrl = `${baseUrl}/api/payment/paytm/callback`;

    const paytmParams = {
      body: {
        requestType: "Payment",
        mid: mid,
        websiteName: website,
        orderId: paytmOrderId,
        callbackUrl: callbackUrl,
        txnAmount: {
          value: amountStr,
          currency: "INR"
        },
        userInfo: {
          custId: userId
        }
      },
      head: {
        signature: ""
      }
    };

    // Generate checksum on the body object
    const checksum = await PaytmChecksum.generateSignature(JSON.stringify(paytmParams.body), key);
    paytmParams.head.signature = checksum;

    // Call Paytm initiateTransaction API
    const host = env === 'prod' ? 'securegw.paytm.in' : 'securegw-stage.paytm.in';
    const paytmUrl = `https://${host}/theia/api/v1/initiateTransaction?mid=${mid}&orderId=${paytmOrderId}`;

    const response = await fetch(paytmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(paytmParams)
    });

    const result = await response.json();

    if (result.body && result.body.resultInfo && result.body.resultInfo.resultStatus === 'S') {
      return NextResponse.json({
        txnToken: result.body.txnToken,
        orderId: paytmOrderId,
        amount: amountStr,
        mid: mid,
        env: env
      });
    } else {
      console.error('Paytm Initiate Transaction Failed:', result);
      return NextResponse.json({
        error: result.body?.resultInfo?.resultMsg || 'Failed to initiate transaction with Paytm'
      }, { status: 400 });
    }

  } catch (error: any) {
    console.error('Error initiating Paytm transaction:', error);
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 });
  }
}
