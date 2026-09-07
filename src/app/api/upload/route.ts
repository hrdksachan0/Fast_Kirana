import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { uploadToSupabaseStorage, generateStoragePath } from '@/lib/supabase-storage'

async function optimizeImageToWebP(inputBuffer: Buffer): Promise<{ buffer: Buffer; isWebP: boolean }> {
  try {
    const sharpModule = await import('sharp').then((m) => m.default || m).catch(() => null)
    if (!sharpModule) {
      return { buffer: inputBuffer, isWebP: false }
    }
    const optimized = await sharpModule(inputBuffer)
      .resize({
        width: 1200,
        withoutEnlargement: true,
        fit: 'inside',
      })
      .webp({ quality: 82, effort: 4 })
      .toBuffer()
    return { buffer: optimized, isWebP: true }
  } catch (err) {
    console.warn('[WebP Optimization] Compression fallback to original:', err)
    return { buffer: inputBuffer, isWebP: false }
  }
}

export async function POST(req: Request) {
  try {
    const session = await auth().catch(() => null)
    // Fallback: check headers if session cookie not passed (e.g. mobile or reverse proxy)
    const headerUserId = req.headers.get('x-user-id')
    const headerRole = req.headers.get('x-user-role')
    const isStaffOrAdmin = headerRole === 'ADMIN' || headerRole === 'RESTAURANT_STAFF' || headerRole === 'DELIVERY'

    if (!session?.user && !(headerUserId && isStaffOrAdmin)) {
      return NextResponse.json({ error: 'Unauthorized: Staff or admin login required' }, { status: 401 })
    }

    const contentType = req.headers.get('content-type') || ''
    let inputBuffer: Buffer | null = null
    let originalMime = 'image/jpeg'
    let originalExt = 'jpg'

    if (contentType.includes('multipart/form-data')) {
      const formData = await req.formData()
      const file = formData.get('file') as File | null
      if (!file) {
        return NextResponse.json({ error: 'No file provided' }, { status: 400 })
      }
      if (file.type) {
        originalMime = file.type
        if (file.name && file.name.includes('.')) {
          originalExt = file.name.split('.').pop()?.toLowerCase() || 'jpg'
        }
      }
      const arrayBuffer = await file.arrayBuffer()
      inputBuffer = Buffer.from(arrayBuffer)
    } else {
      const body = await req.json().catch(() => ({}))
      const rawData = body.file || body.image || ''
      if (rawData) {
        if (rawData.startsWith('data:')) {
          const match = rawData.match(/^data:([^;]+);base64,/)
          if (match) originalMime = match[1]
        }
        // Strip data URL prefix if present
        const base64Clean = rawData.includes(',') ? rawData.split(',')[1] : rawData
        inputBuffer = Buffer.from(base64Clean, 'base64')
      }
    }

    if (!inputBuffer || inputBuffer.length === 0) {
      return NextResponse.json({ error: 'No image data provided' }, { status: 400 })
    }

    // Auto-compress to WebP if sharp is available
    const { buffer: optimizedBuffer, isWebP } = await optimizeImageToWebP(inputBuffer)
    const mime = isWebP ? 'image/webp' : originalMime
    const ext = isWebP ? 'webp' : originalExt

    // Upload to Supabase Storage
    try {
      const storagePath = generateStoragePath('products', ext)
      const publicUrl = await uploadToSupabaseStorage(optimizedBuffer, storagePath, mime)
      return NextResponse.json({ success: true, url: publicUrl })
    } catch (storageErr) {
      console.error('[Supabase Storage] Upload failed, falling back to data URL:', storageErr)
    }

    // Fallback: Return Data URL (works instantly everywhere)
    const base64Data = `data:${mime};base64,${optimizedBuffer.toString('base64')}`
    return NextResponse.json({ success: true, url: base64Data })
  } catch (err: any) {
    console.error('Image Upload API Error:', err)
    return NextResponse.json({ error: err.message || 'Image upload failed' }, { status: 500 })
  }
}
