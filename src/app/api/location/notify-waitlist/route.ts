import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { phone, latitude, longitude, hubName, areaName } = body

    if (!phone || String(phone).trim().length < 10) {
      return NextResponse.json(
        { error: 'Please enter a valid 10-digit mobile number' },
        { status: 400 }
      )
    }

    const cleanedPhone = String(phone).trim().replace(/\D/g, '').slice(-10)
    const lat = latitude ? parseFloat(String(latitude)) : null
    const lng = longitude ? parseFloat(String(longitude)) : null
    const finalHub = hubName ? String(hubName).trim() : 'Upcoming Zone'
    const finalArea = areaName ? String(areaName).trim() : null

    // Ensure hub_waitlist table exists dynamically
    try {
      await prisma.$executeRawUnsafe(`
        CREATE TABLE IF NOT EXISTS hub_waitlist (
          id TEXT PRIMARY KEY,
          phone TEXT NOT NULL,
          latitude DOUBLE PRECISION,
          longitude DOUBLE PRECISION,
          hub_name TEXT,
          area_name TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
      `)

      const recordId = `wait_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`
      await prisma.$executeRawUnsafe(
        `INSERT INTO hub_waitlist (id, phone, latitude, longitude, hub_name, area_name, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW())
         ON CONFLICT (id) DO NOTHING;`,
        recordId,
        cleanedPhone,
        lat,
        lng,
        finalHub,
        finalArea
      )
    } catch (dbErr) {
      console.warn('Direct SQL waitlist table fallback error, recording to logs:', dbErr)
    }

    return NextResponse.json({
      success: true,
      message: `Thanks! We will notify ${cleanedPhone} on WhatsApp the moment FastKirana goes live in ${finalHub}!`
    })
  } catch (error: any) {
    console.error('Error in notify-waitlist API:', error)
    return NextResponse.json(
      { error: error.message || 'Failed to register notification request' },
      { status: 500 }
    )
  }
}
