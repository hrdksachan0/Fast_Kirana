import { NextRequest } from 'next/server'
import { GET as getSettings } from '@/app/api/settings/route'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  return getSettings(request)
}
