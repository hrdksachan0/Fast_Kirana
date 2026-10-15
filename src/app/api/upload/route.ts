import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { uploadToSupabaseStorage, generateStoragePath } from '@/lib/supabase-storage'

const MAX_TARGET_BYTES = 80 * 1024 // 80 KB target for lightning-fast 2G/3G mobile delivery

async function optimizeImageToWebP(inputBuffer: Buffer): Promise<{ buffer: Buffer; isWebP: boolean; sizeKB: number }> {
  try {
    const sharpModule = await import('sharp').then((m) => m.default || m).catch(() => null)
    if (!sharpModule) {
      return { buffer: inputBuffer, isWebP: false, sizeKB: Math.round(inputBuffer.length / 1024) }
    }

    // Pass 1: Resize to max 800px width/height, quality 78 (crystal-clear product details)
    let optimized = await sharpModule(inputBuffer)
      .rotate() // auto-orient based on camera EXIF tags
      .resize({
        width: 800,
        height: 800,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 78, effort: 4 })
      .toBuffer()

    // Pass 2: If still > 80 KB, adjust quality to 68
    if (optimized.length > MAX_TARGET_BYTES) {
      optimized = await sharpModule(inputBuffer)
        .rotate()
        .resize({
          width: 800,
          height: 800,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .webp({ quality: 68, effort: 5 })
        .toBuffer()
    }

    // Pass 3: If exceptionally complex image still > 80 KB, resize to 640px at quality 60
    if (optimized.length > MAX_TARGET_BYTES) {
      optimized = await sharpModule(inputBuffer)
        .rotate()
        .resize({
          width: 640,
          height: 640,
          fit: 'inside',
          withoutEnlargement: true,
        })
        .webp({ quality: 60, effort: 5 })
        .toBuffer()
    }

    const sizeKB = Math.round(optimized.length / 1024)
    return { buffer: optimized, isWebP: true, sizeKB }
  } catch (err) {
    console.warn('[WebP Optimization] Compression fallback to original:', err)
    return { buffer: inputBuffer, isWebP: false, sizeKB: Math.round(inputBuffer.length / 1024) }
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

    const isVideo = originalMime.startsWith('video/')
    let finalBuffer = inputBuffer
    let mime = originalMime
    let ext = originalExt
    let sizeKB = Math.round(inputBuffer.length / 1024)

    if (!isVideo) {
      // Auto-compress images to WebP strictly targeting under 80 KB
      const result = await optimizeImageToWebP(inputBuffer)
      finalBuffer = result.buffer
      mime = result.isWebP ? 'image/webp' : originalMime
      ext = result.isWebP ? 'webp' : originalExt
      sizeKB = result.sizeKB
    }

    // Upload to Supabase Storage
    try {
      const folder = isVideo ? 'videos' : 'products'
      const storagePath = generateStoragePath(folder, ext)
      const publicUrl = await uploadToSupabaseStorage(finalBuffer, storagePath, mime)
      return NextResponse.json({ 
        success: true, 
        url: publicUrl,
        sizeKB,
        format: ext
      })
    } catch (storageErr) {
      console.error('[Supabase Storage] Upload failed, falling back to data URL:', storageErr)
    }

    // Fallback: Return Data URL (works instantly everywhere)
    const base64Data = `data:${mime};base64,${finalBuffer.toString('base64')}`
    return NextResponse.json({ 
      success: true, 
      url: base64Data,
      sizeKB,
      format: ext
    })
  } catch (err: any) {
    console.error('Image Upload API Error:', err)
    return NextResponse.json({ error: err.message || 'Image upload failed' }, { status: 500 })
  }
}
